import Foundation
import Supabase

enum FeedItemType {
    case session, streak, habitLog, personalBest
}

struct FeedItem: Identifiable {
    let id: String
    let type: FeedItemType
    let ownerID: String
    let ownerName: String
    let sessionID: String?
    let sessionTitle: String?
    let sessionTime: Date?
    let isPublicSession: Bool
    let streakCount: Int?
    var isLiked: Bool
    // New fields for habitLog and personalBest items
    let habitName: String?
    let pbEventName: String?
    let pbValue: Double?
    let pbValueUnit: String?
    let itemDate: Date?  // for chronological sort
}

@Observable
class FeedViewModel {
    var feedItems: [FeedItem] = []
    var isLoading: Bool = false
    var likedItemIDs: Set<String> = []

    func fetchFeed(friendIDs: [String], currentUserID: String) async {
        guard !friendIDs.isEmpty else {
            feedItems = []
            return
        }
        isLoading = true
        defer { isLoading = false }

        var sessionItems: [FeedItem] = []
        var streakItems: [FeedItem] = []

        // --- Sessions ---
        do {
            struct FeedSessionRow: Decodable {
                let id: UUID
                let createdBy: String
                let title: String
                let proposedAt: Date?
                let visibility: String?
                enum CodingKeys: String, CodingKey {
                    case id
                    case createdBy = "created_by"
                    case title
                    case proposedAt = "proposed_at"
                    case visibility
                }
            }
            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: Date())
            let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart)!
            var fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime]
            let rows: [FeedSessionRow] = try await supabase
                .from("sessions")
                .select("id, created_by, title, proposed_at, visibility")
                .in("created_by", values: friendIDs)
                .gte("proposed_at", value: fmt.string(from: todayStart))
                .lt("proposed_at", value: fmt.string(from: todayEnd))
                .execute()
                .value
            sessionItems = rows.map { row in
                FeedItem(
                    id: row.id.uuidString,
                    type: .session,
                    ownerID: row.createdBy,
                    ownerName: "",
                    sessionID: row.id.uuidString,
                    sessionTitle: row.title,
                    sessionTime: row.proposedAt,
                    isPublicSession: row.visibility == "friends",
                    streakCount: nil,
                    isLiked: false,
                    habitName: nil, pbEventName: nil, pbValue: nil, pbValueUnit: nil,
                    itemDate: row.proposedAt
                )
            }
        } catch {
            print("[FeedViewModel] sessions fetch error: \(error)")
        }

        // --- Streaks ---
        do {
            struct FeedStreakRow: Decodable {
                let userId: String
                let sessionStreak: Int
                enum CodingKeys: String, CodingKey {
                    case userId = "user_id"
                    case sessionStreak = "session_streak"
                }
            }
            let rows: [FeedStreakRow] = try await supabase
                .from("group_members")
                .select("user_id, session_streak")
                .in("user_id", values: friendIDs)
                .gt("session_streak", value: 0)
                .execute()
                .value
            streakItems = rows.map { row in
                FeedItem(
                    id: "streak-\(row.userId)",
                    type: .streak,
                    ownerID: row.userId,
                    ownerName: "",
                    sessionID: nil,
                    sessionTitle: nil,
                    sessionTime: nil,
                    isPublicSession: false,
                    streakCount: row.sessionStreak,
                    isLiked: false,
                    habitName: nil, pbEventName: nil, pbValue: nil, pbValueUnit: nil,
                    itemDate: Date()
                )
            }
        } catch {
            print("[FeedViewModel] streaks fetch error: \(error)")
        }

        // --- Display names ---
        let allOwnerIDs = Array(Set(sessionItems.map { $0.ownerID } + streakItems.map { $0.ownerID }))
        var nameMap: [String: String] = [:]
        if !allOwnerIDs.isEmpty {
            do {
                struct ProfileName: Decodable {
                    let id: String
                    let displayName: String?
                    enum CodingKeys: String, CodingKey {
                        case id
                        case displayName = "display_name"
                    }
                }
                let profiles: [ProfileName] = try await supabase
                    .from("profiles")
                    .select("id, display_name")
                    .in("id", values: allOwnerIDs)
                    .execute()
                    .value
                for p in profiles {
                    nameMap[p.id] = p.displayName ?? "Someone"
                }
            } catch {
                print("[FeedViewModel] profiles fetch error: \(error)")
            }
        }

        // --- Liked items ---
        do {
            struct FeedLike: Decodable {
                let targetId: String
                enum CodingKeys: String, CodingKey {
                    case targetId = "target_id"
                }
            }
            let likes: [FeedLike] = try await supabase
                .from("feed_likes")
                .select("target_id")
                .eq("liker_id", value: currentUserID)
                .execute()
                .value
            likedItemIDs = Set(likes.map { $0.targetId })
        } catch {
            print("[FeedViewModel] feed_likes fetch error: \(error)")
        }

        // --- Habit log feed items (last 3 days) ---
        var habitLogItems: [FeedItem] = []
        do {
            struct HabitLogFeedRow: Decodable {
                let id: UUID
                let userId: String
                let loggedDate: String
                let habit: HabitJoin?
                struct HabitJoin: Decodable {
                    let name: String
                    let isPrivate: Bool
                    let visibleToFriends: Bool?
                    enum CodingKeys: String, CodingKey {
                        case name
                        case isPrivate = "is_private"
                        case visibleToFriends = "visible_to_friends"
                    }
                }
                enum CodingKeys: String, CodingKey {
                    case id
                    case userId = "user_id"
                    case loggedDate = "logged_date"
                    case habit
                }
            }
            let dateFmt = DateFormatter()
            dateFmt.dateFormat = "yyyy-MM-dd"
            let threeDaysAgo = dateFmt.string(from: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date())
            let rows: [HabitLogFeedRow] = try await supabase
                .from("habit_logs")
                .select("id, user_id, logged_date, habit:habits(name, is_private, visible_to_friends)")
                .in("user_id", values: friendIDs)
                .gte("logged_date", value: threeDaysAgo)
                .execute()
                .value
            let dayParser = DateFormatter()
            dayParser.dateFormat = "yyyy-MM-dd"
            habitLogItems = rows.compactMap { row -> FeedItem? in
                guard let h = row.habit, !h.isPrivate, h.visibleToFriends ?? true else { return nil }
                let date = dayParser.date(from: row.loggedDate)
                return FeedItem(
                    id: "habitlog-\(row.id.uuidString)",
                    type: .habitLog,
                    ownerID: row.userId,
                    ownerName: "",
                    sessionID: nil, sessionTitle: nil, sessionTime: nil,
                    isPublicSession: false, streakCount: nil, isLiked: false,
                    habitName: h.name, pbEventName: nil, pbValue: nil, pbValueUnit: nil,
                    itemDate: date
                )
            }
        } catch {
            print("[FeedViewModel] habit_logs fetch error: \(error)")
        }

        // --- PB feed items (last 7 days) ---
        var pbItems: [FeedItem] = []
        do {
            struct PBFeedRow: Decodable {
                let id: UUID
                let userId: String
                let eventName: String
                let value: Double
                let valueUnit: String
                let createdAt: String
                enum CodingKeys: String, CodingKey {
                    case id
                    case userId = "user_id"
                    case eventName = "event_name"
                    case value
                    case valueUnit = "value_unit"
                    case createdAt = "created_at"
                }
            }
            let isoFmt = ISO8601DateFormatter()
            isoFmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let sevenDaysAgo = isoFmt.string(from: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date())
            let rows: [PBFeedRow] = try await supabase
                .from("personal_bests")
                .select("id, user_id, event_name, value, value_unit, created_at")
                .in("user_id", values: friendIDs)
                .gte("created_at", value: sevenDaysAgo)
                .eq("is_public", value: true)
                .execute()
                .value
            pbItems = rows.map { row in
                let date = isoFmt.date(from: row.createdAt) ?? Date()
                return FeedItem(
                    id: "pb-\(row.id.uuidString)",
                    type: .personalBest,
                    ownerID: row.userId,
                    ownerName: "",
                    sessionID: nil, sessionTitle: nil, sessionTime: nil,
                    isPublicSession: false, streakCount: nil, isLiked: false,
                    habitName: nil, pbEventName: row.eventName,
                    pbValue: row.value, pbValueUnit: row.valueUnit,
                    itemDate: date
                )
            }
        } catch {
            print("[FeedViewModel] personal_bests feed fetch error: \(error)")
        }

        // Extend name map with new owners
        let extraOwnerIDs = Array(Set(habitLogItems.map { $0.ownerID } + pbItems.map { $0.ownerID })
            .subtracting(Set(allOwnerIDs)))
        if !extraOwnerIDs.isEmpty {
            do {
                struct ProfileName: Decodable {
                    let id: String
                    let displayName: String?
                    enum CodingKeys: String, CodingKey { case id; case displayName = "display_name" }
                }
                let extras: [ProfileName] = try await supabase
                    .from("profiles")
                    .select("id, display_name")
                    .in("id", values: extraOwnerIDs)
                    .execute()
                    .value
                for p in extras { nameMap[p.id] = p.displayName ?? "Someone" }
            } catch {}
        }

        // --- Enrich and sort ---
        func enrich(_ item: FeedItem) -> FeedItem {
            FeedItem(
                id: item.id,
                type: item.type,
                ownerID: item.ownerID,
                ownerName: nameMap[item.ownerID] ?? "Someone",
                sessionID: item.sessionID,
                sessionTitle: item.sessionTitle,
                sessionTime: item.sessionTime,
                isPublicSession: item.isPublicSession,
                streakCount: item.streakCount,
                isLiked: likedItemIDs.contains(item.id),
                habitName: item.habitName,
                pbEventName: item.pbEventName,
                pbValue: item.pbValue,
                pbValueUnit: item.pbValueUnit,
                itemDate: item.itemDate
            )
        }
        let allItems = (sessionItems + streakItems + habitLogItems + pbItems).map(enrich)
        feedItems = allItems.sorted {
            ($0.itemDate ?? .distantPast) > ($1.itemDate ?? .distantPast)
        }
    }

    func toggleLike(item: FeedItem, currentUserID: String, currentUserDisplayName: String) async {
        let targetType = item.type == .session ? "session" : "streak"
        if likedItemIDs.contains(item.id) {
            do {
                try await supabase
                    .from("feed_likes")
                    .delete()
                    .eq("liker_id", value: currentUserID)
                    .eq("target_type", value: targetType)
                    .eq("target_id", value: item.id)
                    .execute()
                likedItemIDs.remove(item.id)
                feedItems = feedItems.map { fi in
                    guard fi.id == item.id else { return fi }
                    return FeedItem(id: fi.id, type: fi.type, ownerID: fi.ownerID, ownerName: fi.ownerName,
                                    sessionID: fi.sessionID, sessionTitle: fi.sessionTitle, sessionTime: fi.sessionTime,
                                    isPublicSession: fi.isPublicSession, streakCount: fi.streakCount, isLiked: false,
                                    habitName: fi.habitName, pbEventName: fi.pbEventName,
                                    pbValue: fi.pbValue, pbValueUnit: fi.pbValueUnit, itemDate: fi.itemDate)
                }
            } catch {
                print("[FeedViewModel] unlike error: \(error)")
            }
        } else {
            struct NewLike: Encodable {
                let likerId: String
                let targetType: String
                let targetId: String
                let targetOwnerId: String
                enum CodingKeys: String, CodingKey {
                    case likerId = "liker_id"
                    case targetType = "target_type"
                    case targetId = "target_id"
                    case targetOwnerId = "target_owner_id"
                }
            }
            do {
                try await supabase
                    .from("feed_likes")
                    .insert(NewLike(likerId: currentUserID, targetType: targetType,
                                   targetId: item.id, targetOwnerId: item.ownerID))
                    .execute()
                likedItemIDs.insert(item.id)
                feedItems = feedItems.map { fi in
                    guard fi.id == item.id else { return fi }
                    return FeedItem(id: fi.id, type: fi.type, ownerID: fi.ownerID, ownerName: fi.ownerName,
                                    sessionID: fi.sessionID, sessionTitle: fi.sessionTitle, sessionTime: fi.sessionTime,
                                    isPublicSession: fi.isPublicSession, streakCount: fi.streakCount, isLiked: true,
                                    habitName: fi.habitName, pbEventName: fi.pbEventName,
                                    pbValue: fi.pbValue, pbValueUnit: fi.pbValueUnit, itemDate: fi.itemDate)
                }
            } catch {
                print("[FeedViewModel] like error: \(error)")
            }
            do {
                struct PushProfile: Decodable {
                    let pushToken: String?
                    enum CodingKeys: String, CodingKey { case pushToken = "push_token" }
                }
                let profiles: [PushProfile] = try await supabase
                    .from("profiles")
                    .select("push_token")
                    .eq("id", value: item.ownerID)
                    .limit(1)
                    .execute()
                    .value
                if let token = profiles.first?.pushToken {
                    print("STUB: send like notification to token \(token) — \(currentUserDisplayName) liked your activity")
                }
            } catch {
                print("[FeedViewModel] push token fetch error: \(error)")
            }
        }
    }

    func joinSession(item: FeedItem, currentUserID: String, currentUserDisplayName: String) async {
        guard item.isPublicSession, let sessionID = item.sessionID else { return }
        struct AttendanceUpsert: Encodable {
            let sessionId: String
            let userId: String
            let attended: Bool
            enum CodingKeys: String, CodingKey {
                case sessionId = "session_id"
                case userId = "user_id"
                case attended
            }
        }
        do {
            try await supabase
                .from("attendance")
                .upsert(AttendanceUpsert(sessionId: sessionID, userId: currentUserID, attended: true),
                        onConflict: "session_id,user_id")
                .execute()
        } catch {
            print("[FeedViewModel] join session error: \(error)")
        }
        do {
            struct PushProfile: Decodable {
                let pushToken: String?
                enum CodingKeys: String, CodingKey { case pushToken = "push_token" }
            }
            let profiles: [PushProfile] = try await supabase
                .from("profiles")
                .select("push_token")
                .eq("id", value: item.ownerID)
                .limit(1)
                .execute()
                .value
            if let token = profiles.first?.pushToken {
                print("STUB: send join notification to token \(token) — \(currentUserDisplayName) is joining your session")
            }
        } catch {
            print("[FeedViewModel] push token fetch error: \(error)")
        }
    }
}
