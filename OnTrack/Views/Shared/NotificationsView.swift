import SwiftUI
import Supabase

struct NotificationsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var friendsVM = FriendsViewModel()
    @State private var habitInvites: [HabitMember] = []
    @State private var groupInvites: [GroupInvite] = []
    @State private var groupVM = GroupViewModel()
    @State private var isLoading = false

    var hasAnyNotifications: Bool {
        !friendsVM.pendingReceived.isEmpty || !habitInvites.isEmpty || !groupInvites.isEmpty
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
                                    Text("Friend Requests")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white.opacity(0.7))
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
                                                        .background(Color(red: 0.08, green: 0.35, blue: 0.45))
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
                                        .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .padding(.horizontal)
                                    }
                                }
                            }

                            // HABIT INVITES
                            if !habitInvites.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Habit Invites")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white.opacity(0.7))
                                        .padding(.horizontal)

                                    ForEach(habitInvites) { invite in
                                        HStack(spacing: 14) {
                                            Image(systemName: "figure.run.circle.fill")
                                                .font(.system(size: 36))
                                                .foregroundStyle(.white.opacity(0.6))

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Habit Invite")
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                    .foregroundStyle(.white)
                                                Text("You've been invited to join a group habit")
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
                                                        .background(Color(red: 0.08, green: 0.35, blue: 0.45))
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
                                        .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .padding(.horizontal)
                                    }
                                }
                            }
                            // GROUP INVITES
                            if !groupInvites.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Group Invites")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white.opacity(0.7))
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
                                                        .background(Color(red: 0.08, green: 0.35, blue: 0.45))
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
                                        .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
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
            let invites: [HabitMember] = try await supabase
                .from("habit_members")
                .select()
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
