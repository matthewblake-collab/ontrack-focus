import SwiftUI
import Supabase

struct GroupDetailView: View {
    let group: AppGroup
    @Environment(\.dismiss) private var dismiss
    @State private var members: [GroupMember] = []
    @State private var profiles: [Profile] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showImagePicker = false
    @State private var coverImageData: Data? = nil
    @State private var coverImageURL: String? = nil
    @State private var isUploadingImage = false
    @State private var insightsVM = GroupInsightsViewModel()
    @State private var showShareSheet = false
    @State private var showInviteMembers = false
    @State private var showMembers = false
    @State private var showLeaveAlert = false
    @State private var showAssignAdminSheet = false
    @State private var showDeleteError = false
    @State private var deleteErrorMessage = ""
    @State private var upcomingSessions: [AppSession] = []
    @State private var showCreateSession = false
    @State private var sessionViewModel = SessionViewModel()
    @State private var friendsViewModel = FriendsViewModel()
    @State private var groupVM = GroupViewModel()
    @State private var sentRequests: Set<UUID> = []
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager

    var isAdmin: Bool {
        members.first { $0.userId == appState.currentUser?.id }?.role == "owner"
    }

    var otherMembers: [GroupMember] {
        members.filter { $0.userId != appState.currentUser?.id }
    }

    func isFriend(_ userId: UUID) -> Bool {
        let idStr = userId.uuidString.lowercased()
        return friendsViewModel.friends.contains {
            $0.requesterId.lowercased() == idStr || $0.receiverId.lowercased() == idStr
        }
    }

    func hasPendingRequest(_ userId: UUID) -> Bool {
        let idStr = userId.uuidString.lowercased()
        return sentRequests.contains(userId) ||
            friendsViewModel.pendingSent.contains { $0.receiverId.lowercased() == idStr } ||
            friendsViewModel.pendingReceived.contains { $0.requesterId.lowercased() == idStr }
    }

    var body: some View {
        ZStack(alignment: .top) {

            // FULL SCREEN BACKGROUND
            GeometryReader { geo in
                ZStack {
                    if let urlString = coverImageURL ?? group.coverImageURL,
                       let url = URL(string: urlString) {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            themeManager.currentTheme.gradient
                        }
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                    } else if let data = coverImageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    } else {
                        themeManager.currentTheme.gradient
                    }
                    Color.black.opacity(0.45)
                }
            }
            .ignoresSafeArea()

            // CONTENT
            ScrollView {
                VStack(spacing: 0) {

                    // GROUP HEADER
                    VStack(spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(group.name)
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                if let description = group.description, !description.isEmpty {
                                    Text(description)
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.8))
                                }
                            }
                            Spacer()
                            if isAdmin {
                                Menu {
                                    Button {
                                        showImagePicker = true
                                    } label: {
                                        Label("Change Photo", systemImage: "camera.fill")
                                    }
                                    if coverImageURL != nil || group.coverImageURL != nil {
                                        Button(role: .destructive) {
                                            Task { await removeCoverImage() }
                                        } label: {
                                            Label("Remove Photo", systemImage: "trash")
                                        }
                                    }
                                } label: {
                                    Label(isUploadingImage ? "Uploading..." : "Edit Cover",
                                          systemImage: isUploadingImage ? "arrow.clockwise" : "camera.fill")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(.ultraThinMaterial)
                                        .clipShape(RoundedRectangle(cornerRadius: 20))
                                        .foregroundStyle(.white)
                                }
                                .disabled(isUploadingImage)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                        .padding(.bottom, 20)

                        // INVITE MEMBERS BUTTON
                        Button { showInviteMembers = true } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("Invite Members")
                                    .font(.system(size: 16, weight: .semibold))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }

                    // FROSTED GLASS CONTENT
                    VStack(spacing: 12) {

                        // 1. SESSIONS (top)
                        sessionsSection

                        // 2. GROUP STATS (inline cards)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Group Stats")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.horizontal)
                            GroupInsightsGridView(vm: insightsVM)
                        }

                        // 3. STATS + LEADERBOARD buttons
                        NavigationLink(destination: GroupPBLeaderboardView(
                            group: group,
                            memberProfiles: profiles
                        )) {
                            HStack {
                                Image(systemName: "trophy.fill")
                                    .foregroundColor(.yellow)
                                Text("PB Leaderboard")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            .padding()
                            .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                        }
                        .buttonStyle(.plain)

                        NavigationLink(destination: GroupStatsView(group: group)) {
                            HStack {
                                Label("View Stats", systemImage: "chart.bar.fill")
                                    .foregroundStyle(.white)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            .padding()
                            .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                        }
                        .buttonStyle(.plain)

                        NavigationLink(destination: GroupLeaderboardView(group: group)) {
                            HStack {
                                Label("Leaderboard", systemImage: "trophy.fill")
                                    .foregroundStyle(.white)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            .padding()
                            .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                        }
                        .buttonStyle(.plain)

                            if isAdmin {
                                NavigationLink(destination: CoachDashboardView(
                                    group: group,
                                    memberProfiles: members.map { m in
                                        (id: m.userId, name: profiles.first { $0.id == m.userId }?.displayName ?? "Member")
                                    }
                                )) {
                                    HStack {
                                        Label("Coach Dashboard", systemImage: "person.badge.shield.checkmark.fill")
                                            .foregroundStyle(.white)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.white.opacity(0.5))
                                    }
                                    .padding()
                                    .background(Color.purple.opacity(0.3))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .padding(.horizontal)
                                }
                                .buttonStyle(.plain)
                            }

                        // 4. MEMBERS (collapsed by default)
                        membersSection

                        // 5. LEAVE GROUP
                        Button {
                            if isAdmin {
                                if members.count <= 1 {
                                    // Sole member — skip the alert, just delete
                                    Task { await deleteGroup() }
                                } else {
                                    showLeaveAlert = true
                                }
                            } else {
                                Task { await leaveGroup() }
                            }
                        } label: {
                            HStack {
                                Label("Leave Group", systemImage: "rectangle.portrait.and.arrow.right")
                                    .foregroundStyle(.red)
                                Spacer()
                            }
                            .padding()
                            .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                        }

                        if let error = errorMessage {
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.caption)
                                .padding()
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    if isAdmin {
                        Button {
                            showCreateSession = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.white)
                        }
                    }
                    NavigationLink(destination: GroupChatView(group: group)) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .task {
            coverImageURL = group.coverImageURL
            async let membersTask: () = fetchMembersAndProfiles()
            async let insightsTask: () = insightsVM.fetchInsights(groupId: group.id)
            async let sessionsTask: () = fetchUpcomingSessions()
            _ = await (membersTask, insightsTask, sessionsTask)
            if let userId = appState.currentUser?.id {
                await friendsViewModel.fetchFriends(userId: userId.uuidString)
                if let myMember = members.first(where: { $0.userId == userId }) {
                    await groupVM.fetchSessionFreezes(userId: userId, groupMemberId: myMember.id)
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePickerView { data in
                coverImageData = data
                Task { await uploadCoverImage(data: data) }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: ["Join my group \(group.name) on OnTrack! Use invite code: \(group.inviteCode)"])
        }
        .sheet(isPresented: $showInviteMembers) {
            InviteMembersSheet(
                group: group,
                members: members,
                friendsViewModel: friendsViewModel,
                currentUserId: appState.currentUser?.id,
                groupVM: groupVM
            )
        }
        .sheet(isPresented: $showAssignAdminSheet) {
            assignAdminSheet
        }
        .sheet(isPresented: $showCreateSession) {
            CreateSessionView(viewModel: sessionViewModel, group: group)
        }
        .alert("You're the group admin", isPresented: $showLeaveAlert) {
            Button("Assign New Admin") { showAssignAdminSheet = true }
            Button("Delete Group", role: .destructive) { Task { await deleteGroup() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Before leaving, choose what happens to the group.")
        }
        .alert("Delete Failed", isPresented: $showDeleteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteErrorMessage)
        }
    }

    // MARK: - Sessions Section

    @ViewBuilder
    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Upcoming Sessions")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                NavigationLink(destination: SessionListView(group: group)) {
                    Text("See All")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            if upcomingSessions.isEmpty {
                Text("No upcoming sessions")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
            } else {
                ForEach(upcomingSessions) { session in
                    SessionLifecycleLoader(session: session, userId: appState.currentUser!.id, group: group)
                        .padding(.horizontal)
                        .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - Members Section

    @ViewBuilder
    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showMembers.toggle()
                }
            } label: {
                HStack {
                    Text("Members (\(members.count))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: showMembers ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding()
                .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }

            if showMembers {
                if isLoading {
                    ProgressView().tint(.white).padding()
                } else {
                    ForEach(members) { member in
                        let isCurrentUserRow = member.userId == appState.currentUser?.id
                        VStack(spacing: 0) {
                            MemberRowView(
                                member: member,
                                profileName: profileName(for: member.userId),
                                isCurrentUser: isCurrentUserRow,
                                isAdmin: isAdmin,
                                isFriend: isFriend(member.userId),
                                isPending: hasPendingRequest(member.userId),
                                sessionStreak: member.sessionStreak,
                                hasFreezeThisWeek: isCurrentUserRow && !groupVM.isSessionFreezeAvailable(groupMemberId: member.id),
                                onAddFriend: {
                                    Task {
                                        guard let currentId = appState.currentUser?.id else { return }
                                        await friendsViewModel.sendFriendRequest(
                                            fromUserId: currentId.uuidString,
                                            toUserId: member.userId.uuidString
                                        )
                                        sentRequests.insert(member.userId)
                                    }
                                },
                                onPromote: { Task { await updateRole(member: member, newRole: "owner") } },
                                onDemote: { Task { await updateRole(member: member, newRole: "member") } },
                                onRemove: { Task { await removeMember(member: member) } }
                            )
                            if isCurrentUserRow {
                                HStack {
                                    Text(groupVM.isSessionFreezeAvailable(groupMemberId: member.id) ? "❄️ Freeze available" : "❄️ Freeze used this week")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.45))
                                    Spacer()
                                    if groupVM.isSessionFreezeAvailable(groupMemberId: member.id) {
                                        Button {
                                            Task {
                                                guard let userId = appState.currentUser?.id else { return }
                                                await groupVM.applySessionFreeze(groupMemberId: member.id, userId: userId)
                                            }
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: "snowflake")
                                                    .font(.caption2)
                                                Text("Freeze Streak")
                                                    .font(.caption2)
                                                    .fontWeight(.medium)
                                            }
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                                            .clipShape(Capsule())
                                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.top, 4)
                                .padding(.bottom, 6)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Assign Admin Sheet

    @ViewBuilder
    private var assignAdminSheet: some View {
        NavigationStack {
            List {
                Section("Choose a new admin") {
                    ForEach(otherMembers) { member in
                        Button {
                            showAssignAdminSheet = false
                            Task { await assignAdminAndLeave(member: member) }
                        } label: {
                            HStack {
                                Text(profileName(for: member.userId))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(member.role.capitalized)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Assign New Admin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showAssignAdminSheet = false }
                }
            }
        }
    }

    // MARK: - Helpers

    func profileName(for userId: UUID) -> String {
        profiles.first { $0.id == userId }?.displayName ?? "Unknown"
    }

    // MARK: - Fetch

    func fetchMembersAndProfiles() async {
        isLoading = true
        do {
            let fetchedMembers: [GroupMember] = try await supabase
                .from("group_members")
                .select()
                .eq("group_id", value: group.id.uuidString)
                .execute()
                .value
            self.members = fetchedMembers

            let userIds = fetchedMembers.map { $0.userId.uuidString }
            let fetchedProfiles: [Profile] = try await supabase
                .from("profiles")
                .select()
                .in("id", values: userIds)
                .execute()
                .value
            self.profiles = fetchedProfiles
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func fetchUpcomingSessions() async {
        do {
            let formatter = ISO8601DateFormatter()
            let now = formatter.string(from: Date())
            let fetched: [AppSession] = try await supabase
                .from("sessions")
                .select()
                .eq("group_id", value: group.id.uuidString)
                .neq("status", value: "cancelled")
                .gte("proposed_at", value: now)
                .order("proposed_at", ascending: true)
                .limit(5)
                .execute()
                .value
            self.upcomingSessions = fetched
        } catch {
            // Non-critical; silently ignore
        }
    }

    // MARK: - Image

    func uploadCoverImage(data: Data) async {
        isUploadingImage = true
        do {
            guard let userId = appState.currentUser?.id else { return }
            let fileName = "\(userId.uuidString)/\(group.id.uuidString).jpg"
            try await supabase.storage
                .from("group-images")
                .upload(fileName, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
            let url = try supabase.storage
                .from("group-images")
                .getPublicURL(path: fileName)
            try await supabase
                .from("groups")
                .update(["cover_image_url": url.absoluteString])
                .eq("id", value: group.id.uuidString)
                .execute()
            coverImageURL = url.absoluteString
        } catch {
            errorMessage = error.localizedDescription
        }
        isUploadingImage = false
    }

    func removeCoverImage() async {
        isUploadingImage = true
        do {
            try await supabase
                .from("groups")
                .update(["cover_image_url": AnyJSON.null])
                .eq("id", value: group.id.uuidString)
                .execute()
            coverImageURL = nil
            coverImageData = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isUploadingImage = false
    }

    // MARK: - Member Actions

    func updateRole(member: GroupMember, newRole: String) async {
        errorMessage = nil
        do {
            try await supabase
                .from("group_members")
                .update(["role": newRole])
                .eq("id", value: member.id.uuidString)
                .execute()
            await fetchMembersAndProfiles()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeMember(member: GroupMember) async {
        errorMessage = nil
        do {
            try await supabase
                .from("group_members")
                .delete()
                .eq("id", value: member.id.uuidString)
                .execute()
            await fetchMembersAndProfiles()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Leave / Delete

    func leaveGroup() async {
        errorMessage = nil
        guard let userId = appState.currentUser?.id else { return }

        // If this user is the only member, just delete the group entirely
        if members.count <= 1 {
            await deleteGroup()
            return
        }

        do {
            try await supabase
                .from("group_members")
                .delete()
                .eq("group_id", value: group.id.uuidString)
                .eq("user_id", value: userId.uuidString)
                .execute()

            let formatter = ISO8601DateFormatter()
            let now = formatter.string(from: Date())

            struct SessionIDRow: Decodable { let id: UUID }
            let futureSessions: [SessionIDRow] = try await supabase
                .from("sessions")
                .select("id")
                .eq("group_id", value: group.id.uuidString)
                .gte("proposed_at", value: now)
                .execute()
                .value

            let futureSessionIds = futureSessions.map { $0.id.uuidString }
            if !futureSessionIds.isEmpty {
                try await supabase
                    .from("rsvps")
                    .delete()
                    .eq("user_id", value: userId.uuidString)
                    .in("session_id", values: futureSessionIds)
                    .execute()
            }

            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func assignAdminAndLeave(member: GroupMember) async {
        errorMessage = nil
        do {
            try await supabase
                .from("group_members")
                .update(["role": "owner"])
                .eq("id", value: member.id.uuidString)
                .execute()
            await leaveGroup()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteGroup() async {
        errorMessage = nil
        guard let userId = appState.currentUser?.id else {
            print("[deleteGroup] ERROR: no current user")
            return
        }

        print("[deleteGroup] Starting — groupId=\(group.id.uuidString) userId=\(userId.uuidString)")

        do {
            // Cancel any local session reminders for sessions that will cascade-delete with the group.
            struct SessionIDRow: Decodable { let id: UUID }
            let sessionRows: [SessionIDRow] = (try? await supabase
                .from("sessions")
                .select("id")
                .eq("group_id", value: group.id.uuidString)
                .execute()
                .value) ?? []
            for row in sessionRows {
                NotificationManager.shared.cancelSessionReminder(sessionId: row.id)
            }

            print("[deleteGroup] Calling supabase.from(groups).delete() ...")
            try await supabase
                .from("groups")
                .delete()
                .eq("id", value: group.id.uuidString)
                .eq("created_by", value: userId.uuidString)
                .execute()

            print("[deleteGroup] Delete call completed — dismissing")
            dismiss()
        } catch {
            print("[deleteGroup] ERROR: \(error)")
            deleteErrorMessage = error.localizedDescription
            showDeleteError = true
        }
    }
}

// MARK: - Member Row View

struct MemberRowView: View {
    let member: GroupMember
    let profileName: String
    let isCurrentUser: Bool
    let isAdmin: Bool
    let isFriend: Bool
    let isPending: Bool
    let sessionStreak: Int
    var hasFreezeThisWeek: Bool = false
    let onAddFriend: () -> Void
    let onPromote: () -> Void
    let onDemote: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(profileName)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                    if isCurrentUser {
                        Text("(you)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    if sessionStreak > 0 {
                        HStack(spacing: 2) {
                            Text(hasFreezeThisWeek ? "❄️" : "🔥")
                                .font(.caption)
                            Text("\(sessionStreak)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(hasFreezeThisWeek ? .cyan : .orange)
                        }
                    }
                }
                Text(member.role.capitalized)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            if !isCurrentUser {
                friendStatusView
            }
            if isAdmin && !isCurrentUser {
                adminMenu
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.vertical, 2)
    }

    @ViewBuilder
    var friendStatusView: some View {
        if isFriend {
            Image(systemName: "person.fill.checkmark")
                .foregroundStyle(.green.opacity(0.8))
                .font(.caption)
        } else if isPending {
            Text("Pending")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
        } else {
            Button(action: onAddFriend) {
                Label("Add", systemImage: "person.badge.plus")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                    .clipShape(Capsule())
            }
        }
    }

    var adminMenu: some View {
        Menu {
            if member.role == "member" {
                Button(action: onPromote) {
                    Label("Promote to Owner", systemImage: "arrow.up.circle")
                }
            } else {
                Button(action: onDemote) {
                    Label("Demote to Member", systemImage: "arrow.down.circle")
                }
            }
            Button(role: .destructive, action: onRemove) {
                Label("Remove from Group", systemImage: "person.fill.xmark")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

// MARK: - Group Insights Grid

struct GroupInsightsGridView: View {
    let vm: GroupInsightsViewModel

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        if vm.isLoading {
            HStack {
                Spacer()
                ProgressView().tint(.white)
                Spacer()
            }
            .padding()
        } else {
            LazyVGrid(columns: columns, spacing: 8) {
                GroupInsightCard(
                    value: "\(vm.totalSessions)",
                    label: "Sessions\nHeld",
                    icon: "calendar.circle.fill"
                )
                GroupInsightCard(
                    value: "\(vm.attendanceRate)%",
                    label: "Avg\nAttendance",
                    icon: "person.fill.checkmark"
                )
                GroupInsightCard(
                    value: vm.mostAttendedMember ?? "—",
                    label: "Most\nAttended",
                    icon: "star.fill",
                    isText: true
                )
                GroupInsightCard(
                    value: "\(vm.totalRSVPs)",
                    label: "Total\nRSVPs",
                    icon: "hand.raised.fill"
                )
            }
            .padding(.horizontal)
        }
    }
}

struct GroupInsightCard: View {
    let value: String
    let label: String
    let icon: String
    var isText: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.white)

            if isText {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            } else {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Invite Members Sheet

private struct InviteMembersSheet: View {
    let group: AppGroup
    let members: [GroupMember]
    let friendsViewModel: FriendsViewModel
    let currentUserId: UUID?
    let groupVM: GroupViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var sentInvites: Set<String> = []
    @State private var showFriendShareSheet = false
    @State private var shareItems: [Any] = []

    var existingMemberIds: Set<String> {
        Set(members.map { $0.userId.uuidString })
    }

    var invitableFriends: [FriendProfile] {
        friendsViewModel.friends.compactMap { friendship -> FriendProfile? in
            guard friendship.status == "accepted" else { return nil }
            let profile: FriendProfile?
            if friendship.requesterId.lowercased() == currentUserId?.uuidString.lowercased() ?? "" {
                profile = friendship.receiver
            } else {
                profile = friendship.requester
            }
            guard let p = profile, !existingMemberIds.contains(p.id) else { return nil }
            return p
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.opacity(0.95).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {

                        // FRIENDS SECTION
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Add Friends")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal)

                            if invitableFriends.isEmpty {
                                Text("No friends to add — share the invite code below.")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.55))
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(invitableFriends, id: \.id) { friend in
                                        HStack(spacing: 12) {
                                            Circle()
                                                .fill(Color.white.opacity(0.15))
                                                .frame(width: 38, height: 38)
                                                .overlay(
                                                    Text(String(friend.displayName?.prefix(1) ?? "?").uppercased())
                                                        .font(.system(size: 15, weight: .semibold))
                                                        .foregroundStyle(.white)
                                                )
                                            Text(friend.displayName ?? "Unknown")
                                                .font(.subheadline)
                                                .foregroundStyle(.white)
                                            Spacer()

                                            let alreadySent = sentInvites.contains(friend.id)
                                            Button {
                                                guard !alreadySent,
                                                      let invitedBy = currentUserId?.uuidString else { return }
                                                sentInvites.insert(friend.id)
                                                Task {
                                                    await groupVM.inviteFriendToGroup(
                                                        groupId: group.id,
                                                        inviteeId: friend.id,
                                                        invitedBy: invitedBy
                                                    )
                                                }
                                            } label: {
                                                Text(alreadySent ? "Invited ✓" : "Invite")
                                                    .font(.caption)
                                                    .fontWeight(.semibold)
                                                    .foregroundStyle(alreadySent ? .white.opacity(0.4) : .white)
                                                    .padding(.horizontal, 14)
                                                    .padding(.vertical, 7)
                                                    .background(alreadySent ? Color.white.opacity(0.08) : Color(red: 0.2, green: 0.5, blue: 0.9))
                                                    .clipShape(Capsule())
                                            }
                                            .buttonStyle(.plain)
                                            .disabled(alreadySent)
                                        }
                                        .padding(.horizontal)
                                        .padding(.vertical, 10)

                                        if friend.id != invitableFriends.last?.id {
                                            Divider()
                                                .background(Color.white.opacity(0.1))
                                                .padding(.leading, 62)
                                        }
                                    }
                                }
                                .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .padding(.horizontal)
                            }
                        }

                        // INVITE CODE SECTION (for non-friends)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Or invite via code")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white.opacity(0.5))
                                .padding(.horizontal)

                            HStack(spacing: 12) {
                                Label(group.inviteCode, systemImage: "key.fill")
                                    .font(.system(.subheadline, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.85))
                                Spacer()
                                Button {
                                    UIPasteboard.general.string = group.inviteCode
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                                Button {
                                    shareItems = ["Join my group \"\(group.name)\" on OnTrack Focus! Add me with friend code #\(friendsViewModel.friendCode) to get an invite!"]
                                    showFriendShareSheet = true
                                } label: {
                                    Image(systemName: "square.and.arrow.up")
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                            }
                            .padding(14)
                            .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Invite Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .task {
            if friendsViewModel.friendCode.isEmpty, let uid = currentUserId {
                await friendsViewModel.fetchOrCreateFriendCode(userId: uid.uuidString)
            }
        }
        .sheet(isPresented: $showFriendShareSheet) {
            ShareSheet(items: shareItems)
        }
    }
}
