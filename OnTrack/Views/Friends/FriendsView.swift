import SwiftUI

struct FriendsView: View {
    @EnvironmentObject var appState: AppState
    @State private var viewModel = FriendsViewModel()
    @State private var searchText = ""
    @State private var searchResults: [Profile] = []
    @State private var isSearching = false
    @State private var showFriendCode = false
    @State private var selectedTab = 0
    @State private var searchTask: Task<Void, Never>? = nil

    private var currentUserId: String {
        appState.currentUser?.id.uuidString ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Friends")
                    .font(.title2).bold()
                    .foregroundColor(.white)
                Spacer()
                Button {
                    showFriendCode = true
                } label: {
                    Image(systemName: "qrcode")
                        .foregroundColor(.white)
                        .font(.title3)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 12)

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search by username or friend code", text: $searchText)
                    .foregroundColor(.white)
                    .autocapitalization(.none)
                    .onChange(of: searchText) { _, newValue in
                        searchTask?.cancel()
                        searchTask = Task { await performSearch(query: newValue) }
                    }
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                    }
                }
            }
            .padding(10)
            .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.bottom, 12)

            // Search results
            if !searchText.isEmpty {
                searchResultsList
            } else {
                // Tabs
                HStack(spacing: 0) {
                    ForEach(["Friends", "Requests", "Feed"].indices, id: \.self) { i in
                        let labels = ["Friends", "Requests", "Feed"]
                        Button {
                            withAnimation { selectedTab = i }
                        } label: {
                            VStack(spacing: 4) {
                                HStack(spacing: 4) {
                                    Text(labels[i])
                                        .font(.subheadline)
                                        .fontWeight(selectedTab == i ? .semibold : .regular)
                                        .foregroundColor(selectedTab == i ? .white : .white.opacity(0.5))
                                    if i == 1 && !viewModel.pendingReceived.isEmpty {
                                        Text("\(viewModel.pendingReceived.count)")
                                            .font(.caption2).bold()
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(Color.red)
                                            .clipShape(Capsule())
                                    }
                                }
                                Rectangle()
                                    .fill(selectedTab == i ? Color.white : Color.clear)
                                    .frame(height: 2)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)

                ScrollView {
                    VStack(spacing: 12) {
                        switch selectedTab {
                        case 0: friendsList
                        case 1: requestsList
                        case 2: feedList
                        default: EmptyView()
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
        }
        .task {
            await viewModel.fetchFriends(userId: currentUserId)
            await viewModel.fetchOrCreateFriendCode(userId: currentUserId)
        }
        .onAppear {
            Task { await viewModel.fetchFriends(userId: currentUserId) }
        }
        .sheet(isPresented: $showFriendCode) {
            FriendCodeSheet(code: viewModel.friendCode)
        }
    }

    // MARK: - Search Results

    var searchResultsList: some View {
        ScrollView {
            VStack(spacing: 8) {
                if isSearching {
                    ProgressView().padding()
                } else if searchResults.isEmpty {
                    Text("No users found")
                        .foregroundColor(.white.opacity(0.5))
                        .padding()
                } else {
                    ForEach(searchResults) { profile in
                        SearchResultRow(
                            profile: profile,
                            currentUserId: currentUserId,
                            viewModel: viewModel,
                            existingStatus: friendshipStatus(for: profile.id.uuidString)
                        )
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }

    // MARK: - Friends List

    var friendsList: some View {
        Group {
            if viewModel.friends.isEmpty {
                emptyState(icon: "person.2.fill", message: "No friends yet\nSearch for people or share your friend code!")
            } else {
                ForEach(viewModel.friends) { friendship in
                    let profile = friendship.requesterId.lowercased() == currentUserId.lowercased()
                        ? friendship.receiver
                        : friendship.requester
                    if let profile, profile.id.lowercased() != currentUserId.lowercased() {
                        FriendRow(profile: profile, friendship: friendship, viewModel: viewModel)
                    }
                }
            }
        }
    }

    // MARK: - Requests List

    var requestsList: some View {
        Group {
            if viewModel.pendingReceived.isEmpty && viewModel.pendingSent.isEmpty {
                emptyState(icon: "person.badge.clock.fill", message: "No pending requests")
            } else {
                if !viewModel.pendingReceived.isEmpty {
                    SectionHeader(title: "Received")
                    ForEach(viewModel.pendingReceived) { friendship in
                        if let profile = friendship.requester {
                            FriendRequestRow(
                                profile: profile,
                                friendship: friendship,
                                viewModel: viewModel,
                                currentUserId: currentUserId
                            )
                        }
                    }
                }
                if !viewModel.pendingSent.isEmpty {
                    SectionHeader(title: "Sent")
                    ForEach(viewModel.pendingSent) { friendship in
                        if let profile = friendship.receiver {
                            PendingSentRow(profile: profile, friendship: friendship, viewModel: viewModel)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Feed

    var feedList: some View {
        Group {
            if viewModel.friends.isEmpty {
                emptyState(icon: "newspaper.fill", message: "Add friends to see their milestones here!")
            } else {
                FriendsFeedView(viewModel: viewModel, currentUserId: currentUserId)
            }
        }
    }

    func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.3))
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }

    func friendshipStatus(for userId: String) -> String? {
        let all = viewModel.friends + viewModel.pendingReceived + viewModel.pendingSent
        let lowerId = userId.lowercased()
        if let match = all.first(where: {
            $0.requesterId.lowercased() == lowerId || $0.receiverId.lowercased() == lowerId
        }) {
            return match.status == "accepted" ? "friends" : (match.requesterId.lowercased() == currentUserId.lowercased() ? "sent" : "received")
        }
        return nil
    }

    func performSearch(query: String) async {
        guard query.count >= 2 else { searchResults = []; return }
        isSearching = true
        defer { isSearching = false }
        if query.count == 6 {
            let profile = await viewModel.findUserByFriendCode(query)
            guard !Task.isCancelled else { return }
            if let profile, profile.id.uuidString.lowercased() != currentUserId.lowercased() {
                searchResults = [profile]
            } else {
                searchResults = []
            }
            return
        }
        let results = await viewModel.searchUsers(query: query, currentUserId: currentUserId)
        guard !Task.isCancelled else { return }
        searchResults = results.filter { $0.id.uuidString.lowercased() != currentUserId.lowercased() }
    }
}

// MARK: - Supporting Views

struct SectionHeader: View {
    let title: String
    var body: some View {
        HStack {
            Text(title)
                .font(.caption).bold()
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.top, 4)
    }
}

struct FriendRow: View {
    let profile: FriendProfile
    let friendship: Friendship
    @State var viewModel: FriendsViewModel
    @State private var showRemoveAlert = false

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(url: profile.avatarUrl, size: 40)
            Text(profile.displayName ?? "Unknown")
                .foregroundColor(.white)
                .font(.subheadline)
            Spacer()
            Button {
                showRemoveAlert = true
            } label: {
                Image(systemName: "person.fill.xmark")
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(12)
        .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
        .cornerRadius(12)
        .alert("Remove Friend", isPresented: $showRemoveAlert) {
            Button("Remove", role: .destructive) {
                Task { await viewModel.removeFriend(friendshipId: friendship.id) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

struct FriendRequestRow: View {
    let profile: FriendProfile
    let friendship: Friendship
    @State var viewModel: FriendsViewModel
    let currentUserId: String

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(url: profile.avatarUrl, size: 40)
            Text(profile.displayName ?? "Unknown")
                .foregroundColor(.white)
                .font(.subheadline)
            Spacer()
            Button {
                Task {
                    await viewModel.declineFriendRequest(friendshipId: friendship.id)
                    await viewModel.fetchFriends(userId: currentUserId)
                }
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(.red.opacity(0.8))
                    .padding(8)
                    .background(Color.red.opacity(0.15))
                    .clipShape(Circle())
            }
            Button {
                Task {
                    let otherId = friendship.requesterId
                    await viewModel.acceptFriendRequest(friendshipId: friendship.id, currentUserId: currentUserId, otherUserId: otherId)
                    await viewModel.fetchFriends(userId: currentUserId)
                }
            } label: {
                Image(systemName: "checkmark")
                    .foregroundColor(.green)
                    .padding(8)
                    .background(Color.green.opacity(0.15))
                    .clipShape(Circle())
            }
        }
        .padding(12)
        .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
        .cornerRadius(12)
    }
}

struct PendingSentRow: View {
    let profile: FriendProfile
    let friendship: Friendship
    @State var viewModel: FriendsViewModel

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(url: profile.avatarUrl, size: 40)
            Text(profile.displayName ?? "Unknown")
                .foregroundColor(.white)
                .font(.subheadline)
            Spacer()
            Text("Pending")
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))
            Button {
                Task { await viewModel.removeFriend(friendshipId: friendship.id) }
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(12)
        .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
        .cornerRadius(12)
    }
}

struct SearchResultRow: View {
    let profile: Profile
    let currentUserId: String
    @State var viewModel: FriendsViewModel
    let existingStatus: String?
    @State private var requestSent = false

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(url: profile.avatarURL, size: 40)
            Text(profile.displayName)
                .foregroundColor(.white)
                .font(.subheadline)
            Spacer()
            if existingStatus == "friends" {
                Text("Friends")
                    .font(.caption).bold()
                    .foregroundColor(.green)
            } else if existingStatus == "sent" || requestSent {
                Text("Sent")
                    .font(.caption).bold()
                    .foregroundColor(.white.opacity(0.4))
            } else if existingStatus == "received" {
                Text("Requested you")
                    .font(.caption).bold()
                    .foregroundColor(.white.opacity(0.4))
            } else {
                Button {
                    print("🔵 Add tapped — from: \(currentUserId) to: \(profile.id.uuidString)")
                    Task {
                        await viewModel.sendFriendRequest(fromUserId: currentUserId, toUserId: profile.id.uuidString)
                        requestSent = true
                    }
                } label: {
                    Text("Add")
                        .font(.caption).bold()
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(colors: [Color(red: 0.08, green: 0.35, blue: 0.45), Color(red: 0.15, green: 0.55, blue: 0.38)], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(8)
                }
            }
        }
        .padding(12)
        .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
        .cornerRadius(12)
    }
}

struct FriendCodeSheet: View {
    let code: String
    @Environment(\.dismiss) var dismiss
    @State private var showShare = false

    var qrImage: UIImage? {
        guard let data = code.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.35, blue: 0.45).ignoresSafeArea()
            VStack(spacing: 24) {
                Text("Your Friend Code")
                    .font(.title2).bold()
                    .foregroundColor(.white)
                Text("Share this code or let friends scan your QR")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)

                if let img = qrImage {
                    Image(uiImage: img)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 180, height: 180)
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(16)
                }

                Text(code)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(24)
                    .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                    .cornerRadius(16)

                HStack(spacing: 12) {
                    Button {
                        UIPasteboard.general.string = code
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.subheadline).bold()
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                            .cornerRadius(12)
                    }
                    Button {
                        showShare = true
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.subheadline).bold()
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                            .cornerRadius(12)
                    }
                }

                Button("Done") { dismiss() }
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding()
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(items: ["Add me on OnTrack Focus! My friend code is \(code) 💪\nDownload: https://apps.apple.com/app/id6760957657"])
        }
    }
}

struct AvatarView: View {
    let url: String?
    let size: CGFloat

    var body: some View {
        Group {
            if let url, let imageUrl = URL(string: url) {
                AsyncImage(url: imageUrl) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color.white.opacity(0.2))
                }
            } else {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.white.opacity(0.5))
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

struct FriendsFeedView: View {
    @State var viewModel: FriendsViewModel
    let currentUserId: String
    @State private var milestones: [Milestone] = []
    @State private var friendProfiles: [String: String] = [:]

    var body: some View {
        Group {
            if milestones.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.3))
                    Text("No milestones yet\nKeep going — streaks incoming! 🔥")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
            } else {
                ForEach(milestones) { milestone in
                    MilestoneCard(milestone: milestone, displayName: friendProfiles[milestone.userId] ?? "Someone")
                }
            }
        }
        .task {
            let friendIds = viewModel.friends.compactMap { f -> String? in
                f.requesterId.lowercased() == currentUserId.lowercased() ? f.receiverId : f.requesterId
            }
            for friend in viewModel.friends {
                let profile = friend.requesterId == currentUserId ? friend.receiver : friend.requester
                if let profile {
                    friendProfiles[profile.id] = profile.displayName ?? "Someone"
                }
            }
            milestones = await viewModel.fetchMilestones(userIds: friendIds)
        }
    }
}

struct MilestoneCard: View {
    let milestone: Milestone
    let displayName: String

    var body: some View {
        HStack(spacing: 12) {
            Text("🔥")
                .font(.title2)
                .padding(10)
                .background(Color.orange.opacity(0.15))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text("\(displayName) hit a \(milestone.streakCount)-day streak!")
                    .font(.subheadline).bold()
                    .foregroundColor(.white)
                if !milestone.isPrivate, let name = milestone.habitName {
                    Text(name)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
        .cornerRadius(12)
    }
}
