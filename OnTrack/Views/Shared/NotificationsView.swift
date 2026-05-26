import SwiftUI
import Supabase

struct RSVPNotification: Decodable, Identifiable {
    let id: UUID
    let sessionId: UUID
    let userId: String
    let status: String
    let updatedAt: String
    let session: RSVPSessionSummary?
    let rsvpUser: RSVPUserProfile?

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case userId = "user_id"
        case status
        case updatedAt = "updated_at"
        case session
        case rsvpUser = "rsvp_user"
    }
}

struct RSVPSessionSummary: Decodable {
    let title: String
}

struct RSVPUserProfile: Decodable {
    let displayName: String?
    enum CodingKeys: String, CodingKey { case displayName = "display_name" }
}

struct AcceptedFriendNotification: Decodable, Identifiable {
    let id: String
    let requesterId: String
    let receiverId: String
    let status: String
    let updatedAt: String
    let receiver: AcceptedFriendProfile?

    enum CodingKeys: String, CodingKey {
        case id
        case requesterId = "requester_id"
        case receiverId = "receiver_id"
        case status
        case updatedAt = "updated_at"
        case receiver
    }
}

struct AcceptedFriendProfile: Decodable {
    let displayName: String?
    enum CodingKeys: String, CodingKey { case displayName = "display_name" }
}

struct GroupMessageNotification: Decodable, Identifiable {
    let id: UUID
    let groupId: UUID
    let userId: String
    let content: String
    let createdAt: String
    let sender: MessageSenderProfile?
    let group: MessageGroupSummary?

    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case userId = "user_id"
        case content
        case createdAt = "created_at"
        case sender
        case group
    }
}

struct MessageSenderProfile: Decodable {
    let displayName: String?
    enum CodingKeys: String, CodingKey { case displayName = "display_name" }
}

struct MessageGroupSummary: Decodable {
    let name: String
}

struct NotificationsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var friendsVM = FriendsViewModel()
    @State private var habitInvites: [HabitInviteDetail] = []
    @State private var groupInvites: [GroupInvite] = []
    @State private var groupVM = GroupViewModel()
    @State private var isLoading = false
    @State private var rsvpNotifications: [RSVPNotification] = []
    @State private var acceptedFriends: [AcceptedFriendNotification] = []
    @State private var groupMessages: [GroupMessageNotification] = []

    var hasAnyNotifications: Bool {
        !friendsVM.pendingReceived.isEmpty || !habitInvites.isEmpty || !groupInvites.isEmpty
        || !rsvpNotifications.isEmpty || !acceptedFriends.isEmpty || !groupMessages.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Image(themeManager.currentBackgroundImage)
                    .resizable()
                    .scaledToFill()
                    .grayscale(1.0)
                    .ignoresSafeArea()

                Color.black.opacity(0.72)
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else if !hasAnyNotifications {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "bell.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("No notifications")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Friend requests, habit invites, and group invites will appear here.")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .padding(40)
                } else {
                    ScrollView {
                        VStack(spacing: 24) {

                            // FRIEND REQUESTS
                            if !friendsVM.pendingReceived.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("FRIEND REQUESTS")
                                        .font(.system(size: 11, weight: .heavy))
                                        .tracking(1.4)
                                        .foregroundStyle(themeManager.currentTheme.primary.opacity(0.7))
                                        .padding(.horizontal)

                                    ForEach(friendsVM.pendingReceived) { friendship in
                                        HStack(spacing: 14) {
                                            Image(systemName: "person.circle.fill")
                                                .font(.system(size: 36))
                                                .foregroundStyle(.white.opacity(0.6))

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(friendship.requester?.displayName ?? "Someone")
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                    .foregroundStyle(.white)
                                                Text("Wants to be your friend")
                                                    .font(.caption)
                                                    .foregroundStyle(.white.opacity(0.6))
                                            }

                                            Spacer()

                                            HStack(spacing: 8) {
                                                Button {
                                                    Task {
                                                        let currentId = appState.currentUser?.id.uuidString ?? ""
                                                        let otherId = friendship.requesterId
                                                        await friendsVM.acceptFriendRequest(friendshipId: friendship.id, currentUserId: currentId, otherUserId: otherId)
                                                        await refreshData()
                                                    }
                                                } label: {
                                                    Text("Accept")
                                                        .font(.caption)
                                                        .fontWeight(.semibold)
                                                        .foregroundStyle(.white)
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 6)
                                                        .background(themeManager.currentTheme.primary.opacity(0.85))
                                                        .clipShape(Capsule())
                                                }

                                                Button {
                                                    Task {
                                                        await friendsVM.declineFriendRequest(friendshipId: friendship.id)
                                                        await refreshData()
                                                    }
                                                } label: {
                                                    Text("Decline")
                                                        .font(.caption)
                                                        .fontWeight(.semibold)
                                                        .foregroundStyle(.white.opacity(0.7))
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 6)
                                                        .background(Color.white.opacity(0.1))
                                                        .clipShape(Capsule())
                                                }
                                            }
                                        }
                                        .padding()
                                        .background(Color(red: 0.05, green: 0.08, blue: 0.10))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .strokeBorder(themeManager.currentTheme.primary.opacity(0.25), lineWidth: 7)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .strokeBorder(themeManager.currentTheme.primary.opacity(0.75), lineWidth: 1.5)
                                        )
                                        .padding(.horizontal)
                                    }
                                }
                            }

                            // HABIT INVITES
                            if !habitInvites.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("HABIT INVITES")
                                        .font(.system(size: 11, weight: .heavy))
                                        .tracking(1.4)
                                        .foregroundStyle(themeManager.currentTheme.primary.opacity(0.7))
                                        .padding(.horizontal)

                                    ForEach(habitInvites) { invite in
                                        HStack(spacing: 14) {
                                            Image(systemName: "figure.run.circle.fill")
                                                .font(.system(size: 36))
                                                .foregroundStyle(.white.opacity(0.6))

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(invite.habit?.name ?? "Habit Invite")
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                    .foregroundStyle(.white)
                                                Text(invite.inviter?.displayName.map { "\($0) invited you" } ?? "You've been invited to join a habit")
                                                    .font(.caption)
                                                    .foregroundStyle(.white.opacity(0.6))
                                            }

                                            Spacer()

                                            HStack(spacing: 8) {
                                                Button {
                                                    Task {
                                                        await friendsVM.respondToHabitInvite(habitMemberId: invite.id, accept: true)
                                                        await refreshData()
                                                    }
                                                } label: {
                                                    Text("Join")
                                                        .font(.caption)
                                                        .fontWeight(.semibold)
                                                        .foregroundStyle(.white)
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 6)
                                                        .background(themeManager.currentTheme.primary.opacity(0.85))
                                                        .clipShape(Capsule())
                                                }

                                                Button {
                                                    Task {
                                                        await friendsVM.respondToHabitInvite(habitMemberId: invite.id, accept: false)
                                                        await refreshData()
                                                    }
                                                } label: {
                                                    Text("Decline")
                                                        .font(.caption)
                                                        .fontWeight(.semibold)
                                                        .foregroundStyle(.white.opacity(0.7))
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 6)
                                                        .background(Color.white.opacity(0.1))
                                                        .clipShape(Capsule())
                                                }
                                            }
                                        }
                                        .padding()
                                        .background(Color(red: 0.05, green: 0.08, blue: 0.10))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .strokeBorder(themeManager.currentTheme.primary.opacity(0.25), lineWidth: 7)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .strokeBorder(themeManager.currentTheme.primary.opacity(0.75), lineWidth: 1.5)
                                        )
                                        .padding(.horizontal)
                                    }
                                }
                            }
                            // GROUP INVITES
                            if !groupInvites.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("GROUP INVITES")
                                        .font(.system(size: 11, weight: .heavy))
                                        .tracking(1.4)
                                        .foregroundStyle(themeManager.currentTheme.primary.opacity(0.7))
                                        .padding(.horizontal)

                                    ForEach(groupInvites) { invite in
                                        HStack(spacing: 14) {
                                            Image(systemName: "person.3.fill")
                                                .font(.system(size: 28))
                                                .foregroundStyle(.white.opacity(0.6))

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(invite.groupName)
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                    .foregroundStyle(.white)
                                                Text("You've been invited to join a group")
                                                    .font(.caption)
                                                    .foregroundStyle(.white.opacity(0.6))
                                            }

                                            Spacer()

                                            HStack(spacing: 8) {
                                                Button {
                                                    Task {
                                                        await groupVM.respondToGroupInvite(inviteId: invite.id, accept: true)
                                                        await refreshData()
                                                    }
                                                } label: {
                                                    Text("Join")
                                                        .font(.caption)
                                                        .fontWeight(.semibold)
                                                        .foregroundStyle(.white)
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 6)
                                                        .background(themeManager.currentTheme.primary.opacity(0.85))
                                                        .clipShape(Capsule())
                                                }

                                                Button {
                                                    Task {
                                                        await groupVM.respondToGroupInvite(inviteId: invite.id, accept: false)
                                                        await refreshData()
                                                    }
                                                } label: {
                                                    Text("Decline")
                                                        .font(.caption)
                                                        .fontWeight(.semibold)
                                                        .foregroundStyle(.white.opacity(0.7))
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 6)
                                                        .background(Color.white.opacity(0.1))
                                                        .clipShape(Capsule())
                                                }
                                            }
                                        }
                                        .padding()
                                        .background(Color(red: 0.05, green: 0.08, blue: 0.10))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .strokeBorder(themeManager.currentTheme.primary.opacity(0.25), lineWidth: 7)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .strokeBorder(themeManager.currentTheme.primary.opacity(0.75), lineWidth: 1.5)
                                        )
                                        .padding(.horizontal)
                                    }
                                }
                            }

                            // RSVP NOTIFICATIONS
                            if !rsvpNotifications.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("SESSION RSVPs")
                                        .font(.system(size: 11, weight: .heavy))
                                        .tracking(1.4)
                                        .foregroundStyle(themeManager.currentTheme.primary.opacity(0.7))
                                        .padding(.horizontal)

                                    ForEach(rsvpNotifications) { notif in
                                        HStack(spacing: 14) {
                                            Image(systemName: "calendar.badge.checkmark")
                                                .font(.system(size: 30))
                                                .foregroundStyle(.white.opacity(0.6))

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(notif.rsvpUser?.displayName ?? "Someone")
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                    .foregroundStyle(.white)
                                                let sessionTitle = notif.session?.title ?? "a session"
                                                let action = notif.status == "going" ? "is going to" : notif.status == "not_going" ? "can't make" : "responded to"
                                                Text("\(action) \(sessionTitle)")
                                                    .font(.caption)
                                                    .foregroundStyle(.white.opacity(0.6))
                                            }
                                            Spacer()
                                        }
                                        .padding()
                                        .background(Color(red: 0.05, green: 0.08, blue: 0.10))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .strokeBorder(themeManager.currentTheme.primary.opacity(0.25), lineWidth: 7)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .strokeBorder(themeManager.currentTheme.primary.opacity(0.75), lineWidth: 1.5)
                                        )
                                        .padding(.horizontal)
                                    }
                                }
                            }

                            // ACCEPTED FRIENDS
                            if !acceptedFriends.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("NEW CONNECTIONS")
                                        .font(.system(size: 11, weight: .heavy))
                                        .tracking(1.4)
                                        .foregroundStyle(themeManager.currentTheme.primary.opacity(0.7))
                                        .padding(.horizontal)

                                    ForEach(acceptedFriends) { notif in
                                        HStack(spacing: 14) {
                                            Image(systemName: "person.badge.checkmark.fill")
                                                .font(.system(size: 30))
                                                .foregroundStyle(.white.opacity(0.6))

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(notif.receiver?.displayName ?? "Someone")
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                    .foregroundStyle(.white)
                                                Text("accepted your friend request")
                                                    .font(.caption)
                                                    .foregroundStyle(.white.opacity(0.6))
                                            }
                                            Spacer()
                                        }
                                        .padding()
                                        .background(Color(red: 0.05, green: 0.08, blue: 0.10))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .strokeBorder(themeManager.currentTheme.primary.opacity(0.25), lineWidth: 7)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .strokeBorder(themeManager.currentTheme.primary.opacity(0.75), lineWidth: 1.5)
                                        )
                                        .padding(.horizontal)
                                    }
                                }
                            }

                            // GROUP MESSAGES
                            if !groupMessages.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("GROUP CHAT")
                                        .font(.system(size: 11, weight: .heavy))
                                        .tracking(1.4)
                                        .foregroundStyle(themeManager.currentTheme.primary.opacity(0.7))
                                        .padding(.horizontal)

                                    ForEach(groupMessages) { msg in
                                        HStack(spacing: 14) {
                                            Image(systemName: "bubble.left.fill")
                                                .font(.system(size: 30))
                                                .foregroundStyle(.white.opacity(0.6))

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(msg.sender?.displayName ?? "Someone")
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                    .foregroundStyle(.white)
                                                let groupName = msg.group?.name ?? "a group"
                                                Text("sent a message in \(groupName)")
                                                    .font(.caption)
                                                    .foregroundStyle(.white.opacity(0.6))
                                                Text(msg.content)
                                                    .font(.caption2)
                                                    .foregroundStyle(.white.opacity(0.4))
                                                    .lineLimit(1)
                                            }
                                            Spacer()
                                        }
                                        .padding()
                                        .background(Color(red: 0.05, green: 0.08, blue: 0.10))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .strokeBorder(themeManager.currentTheme.primary.opacity(0.25), lineWidth: 7)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .strokeBorder(themeManager.currentTheme.primary.opacity(0.75), lineWidth: 1.5)
                                        )
                                        .padding(.horizontal)
                                    }
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Notifications")
            .task {
                await refreshData()
            }
        }
    }

    func refreshData() async {
        guard let userId = appState.currentUser?.id else {
            print("❌ NotificationsView: currentUser is nil")
            isLoading = false
            return
        }
        isLoading = true
        await friendsVM.fetchFriends(userId: userId.uuidString)
        do {
            let invites: [HabitInviteDetail] = try await supabase
                .from("habit_members")
                .select("""
                    id, habit_id, user_id, invited_by, status,
                    habit:habits!habit_members_habit_id_fkey(name),
                    inviter:profiles!habit_members_invited_by_fkey(display_name)
                """)
                .eq("user_id", value: userId)
                .eq("status", value: "pending")
                .execute()
                .value
            habitInvites = invites
        } catch {
            habitInvites = []
        }
        do {
            let invites: [GroupInvite] = try await supabase
                .from("group_invites")
                .select("*, groups(name)")
                .eq("invitee_id", value: userId)
                .eq("status", value: "pending")
                .execute()
                .value
            groupInvites = invites
        } catch {
            groupInvites = []
        }

        // Fetch RSVP notifications (RSVPs by others on sessions I host, last 7 days)
        do {
            let cutoff = ISO8601DateFormatter().string(from: Calendar.current.date(byAdding: .day, value: -7, to: Date())!)

            // Scope to host-owned sessions: fetch my session IDs first, then filter RSVPs to those
            struct HostSessionRow: Decodable { let id: UUID }
            let hostSessions: [HostSessionRow] = try await supabase
                .from("sessions")
                .select("id")
                .eq("created_by", value: userId.uuidString.lowercased())
                .execute()
                .value
            let hostSessionIds = hostSessions.map { $0.id.uuidString }

            if hostSessionIds.isEmpty {
                rsvpNotifications = []
            } else {
                let rsvps: [RSVPNotification] = try await supabase
                    .from("rsvps")
                    .select("""
                        id, session_id, user_id, status, updated_at,
                        session:sessions!rsvps_session_id_fkey(title),
                        rsvp_user:profiles!rsvps_user_id_fkey(display_name)
                    """)
                    .in("session_id", values: hostSessionIds)
                    .neq("user_id", value: userId.uuidString.lowercased())
                    .gte("updated_at", value: cutoff)
                    .execute()
                    .value
                rsvpNotifications = rsvps
            }
        } catch {
            rsvpNotifications = []
        }

        // Fetch accepted friend requests (I sent, they accepted, last 7 days)
        do {
            let cutoff = ISO8601DateFormatter().string(from: Calendar.current.date(byAdding: .day, value: -7, to: Date())!)
            let accepted: [AcceptedFriendNotification] = try await supabase
                .from("friendships")
                .select("""
                    id, requester_id, receiver_id, status, updated_at,
                    receiver:profiles!friendships_receiver_id_fkey(display_name)
                """)
                .eq("requester_id", value: userId.uuidString.lowercased())
                .eq("status", value: "accepted")
                .gte("updated_at", value: cutoff)
                .execute()
                .value
            acceptedFriends = accepted
        } catch {
            acceptedFriends = []
        }

        // Fetch recent group chat messages (last 24hrs, not sent by me, in groups I'm a member of)
        do {
            let cutoff = ISO8601DateFormatter().string(from: Calendar.current.date(byAdding: .hour, value: -24, to: Date())!)
            let messages: [GroupMessageNotification] = try await supabase
                .from("group_messages")
                .select("""
                    id, group_id, user_id, content, created_at,
                    sender:profiles!group_messages_user_id_fkey(display_name),
                    group:groups!group_messages_group_id_fkey(name)
                """)
                .neq("user_id", value: userId.uuidString.lowercased())
                .gte("created_at", value: cutoff)
                .order("created_at", ascending: false)
                .limit(10)
                .execute()
                .value
            groupMessages = messages
        } catch {
            groupMessages = []
        }

        isLoading = false
    }
}

func fetchPendingNotificationCount(userId: UUID) async -> Int {
    async let friendCount: Int = {
        struct PendingRow: Decodable { let id: String }
        let rows = try? await supabase
            .from("friendships")
            .select("id")
            .eq("receiver_id", value: userId.uuidString.lowercased())
            .eq("status", value: "pending")
            .execute()
            .value as [PendingRow]
        return rows?.count ?? 0
    }()
    async let groupCount: Int = {
        struct PendingRow: Decodable { let id: UUID }
        let rows = try? await supabase
            .from("group_invites")
            .select("id")
            .eq("invitee_id", value: userId)
            .eq("status", value: "pending")
            .execute()
            .value as [PendingRow]
        return rows?.count ?? 0
    }()
    return await friendCount + groupCount
}
