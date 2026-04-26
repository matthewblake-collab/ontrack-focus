import Foundation
import Observation
import Supabase

@Observable
final class ActivitySummaryViewModel {
    var items: [ActivitySummaryItem] = []

    func fetchSince(lastOpen: Date, userId: UUID) async {
        var isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        let lastOpenStr = isoFormatter.string(from: lastOpen)
        let userIdStr = userId.uuidString

        do {
            // Step 1: get group_ids for current user
            struct GroupMemberRow: Decodable {
                let groupId: UUID
                enum CodingKeys: String, CodingKey {
                    case groupId = "group_id"
                }
            }
            let memberRows: [GroupMemberRow] = try await supabase
                .from("group_members")
                .select("group_id")
                .eq("user_id", value: userIdStr)
                .execute()
                .value
            let groupIds = memberRows.map { $0.groupId.uuidString }
            guard !groupIds.isEmpty else { return }

            // Step 2: get session_ids for upcoming sessions in those groups
            struct SessionRow: Decodable {
                let id: UUID
                let title: String
            }
            let sessionRows: [SessionRow] = try await supabase
                .from("sessions")
                .select("id, title")
                .in("group_id", values: groupIds)
                .eq("status", value: "upcoming")
                .execute()
                .value
            var sessionIds = sessionRows.map { $0.id.uuidString }
            var sessionTitleMap = Dictionary(uniqueKeysWithValues: sessionRows.map { ($0.id.uuidString, $0.title) })
            guard !sessionIds.isEmpty else { return }

            var newItems: [ActivitySummaryItem] = []

            // Step 2b: also include sessions user RSVP'd "going" (may be outside their groups)
            do {
                struct GoingRSVPRow: Decodable {
                    let sessionId: UUID
                    enum CodingKeys: String, CodingKey {
                        case sessionId = "session_id"
                    }
                }
                let goingRows: [GoingRSVPRow] = try await supabase
                    .from("rsvps")
                    .select("session_id")
                    .eq("user_id", value: userIdStr)
                    .eq("status", value: "going")
                    .execute()
                    .value
                let goingSessionIds = goingRows.map { $0.sessionId.uuidString }
                // Merge any RSVP'd session IDs not already in the group-based set
                for id in goingSessionIds where !sessionIds.contains(id) {
                    sessionIds.append(id)
                }
                // Also fetch titles for any new session IDs
                let newIds = goingSessionIds.filter { sessionTitleMap[$0] == nil }
                if !newIds.isEmpty {
                    let extraSessions: [SessionRow] = (try? await supabase
                        .from("sessions")
                        .select("id, title")
                        .in("id", values: newIds)
                        .execute()
                        .value) ?? []
                    for s in extraSessions {
                        sessionTitleMap[s.id.uuidString] = s.title
                    }
                }
            } catch {
                print("[ActivitySummaryViewModel] going-rsvp fetch error: \(error)")
            }

            // Step 3: availability_windows added since lastOpen by other users
            do {
                struct AvailRow: Decodable {
                    let id: UUID
                    let sessionId: UUID
                    let userId: String
                    let createdAt: Date
                    enum CodingKeys: String, CodingKey {
                        case id
                        case sessionId = "session_id"
                        case userId = "user_id"
                        case createdAt = "created_at"
                    }
                }
                let availRows: [AvailRow] = try await supabase
                    .from("availability_windows")
                    .select("id, session_id, user_id, created_at")
                    .in("session_id", values: sessionIds)
                    .neq("user_id", value: userIdStr)
                    .gte("created_at", value: lastOpenStr)
                    .execute()
                    .value

                let actorIds = Array(Set(availRows.map { $0.userId }))
                let nameMap = await fetchNames(for: actorIds)

                for row in availRows {
                    let sessionTitle = sessionTitleMap[row.sessionId.uuidString] ?? "a session"
                    let actorName = nameMap[row.userId] ?? "Someone"
                    newItems.append(ActivitySummaryItem(
                        id: "avail-\(row.id.uuidString)",
                        actorName: actorName,
                        action: "added availability to",
                        targetTitle: sessionTitle,
                        happenedAt: row.createdAt
                    ))
                }
            } catch {
                print("[ActivitySummaryViewModel] availability fetch error: \(error)")
            }

            // Step 4: RSVPs updated since lastOpen by other users
            do {
                struct RSVPRow: Decodable {
                    let id: UUID
                    let sessionId: UUID
                    let userId: UUID
                    let status: String
                    let updatedAt: Date
                    enum CodingKeys: String, CodingKey {
                        case id
                        case sessionId = "session_id"
                        case userId = "user_id"
                        case status
                        case updatedAt = "updated_at"
                    }
                }
                let rsvpRows: [RSVPRow] = try await supabase
                    .from("rsvps")
                    .select("id, session_id, user_id, status, updated_at")
                    .in("session_id", values: sessionIds)
                    .neq("user_id", value: userIdStr)
                    .gte("updated_at", value: lastOpenStr)
                    .execute()
                    .value

                let actorIds = Array(Set(rsvpRows.map { $0.userId.uuidString }))
                let nameMap = await fetchNames(for: actorIds)

                for row in rsvpRows {
                    guard row.status == "going" else { continue }
                    let sessionTitle = sessionTitleMap[row.sessionId.uuidString] ?? "a session"
                    let actorName = nameMap[row.userId.uuidString] ?? "Someone"
                    newItems.append(ActivitySummaryItem(
                        id: "rsvp-\(row.id.uuidString)",
                        actorName: actorName,
                        action: "is going to",
                        targetTitle: sessionTitle,
                        happenedAt: row.updatedAt
                    ))
                }
            } catch {
                print("[ActivitySummaryViewModel] rsvp fetch error: \(error)")
            }

            // Step 5: sort by most recent first
            items = newItems.sorted { $0.happenedAt > $1.happenedAt }

        } catch {
            print("[ActivitySummaryViewModel] fetch error: \(error)")
        }
    }

    private func fetchNames(for ids: [String]) async -> [String: String] {
        guard !ids.isEmpty else { return [:] }
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
                .in("id", values: ids)
                .execute()
                .value
            return Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0.displayName ?? "Someone") })
        } catch {
            return [:]
        }
    }
}
