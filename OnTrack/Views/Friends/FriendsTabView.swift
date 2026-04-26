import SwiftUI

struct FriendsTabView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @State var selectedTab: Int = 0
    @State var feedVM = FeedViewModel()
    @State private var friendsVM = FriendsViewModel()
    @State private var searchText = ""
    @State private var searchResults: [Profile] = []
    @State private var isSearching = false
    @State private var showFriendCode = false
    @State private var showQRScanner = false
    @State private var friendsExpanded = false
    @State private var searchTask: Task<Void, Never>? = nil

    private var currentUserID: String {
        appState.currentUser?.id.uuidString ?? ""
    }

    private var currentUserDisplayName: String {
        appState.currentUser?.displayName ?? ""
    }

    private var derivedFriendIDs: [String] {
        friendsVM.friends.compactMap { f -> String? in
            f.requesterId.lowercased() == currentUserID.lowercased() ? f.receiverId : f.requesterId
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Background
            GeometryReader { geo in
                Image(themeManager.currentBackgroundImage)
                    .resizable()
                    .scaledToFill()
                    .grayscale(1.0)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .ignoresSafeArea()
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                // Tab bar
                HStack(spacing: 0) {
                    tabButton(label: "Feed", index: 0)
                    tabButton(label: "Friends", index: 1)
                    tabButton(label: "Requests", index: 2)
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)

                Divider()
                    .background(Color.white.opacity(0.1))

                // Content
                TabView(selection: $selectedTab) {
                    FeedView(
                        vm: feedVM,
                        friendIDs: derivedFriendIDs,
                        currentUserID: currentUserID,
                        currentUserDisplayName: currentUserDisplayName,
                        friendCode: friendsVM.friendCode
                    )
                    .tag(0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    friendsContent
                        .tag(1)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    requestsContent
                        .tag(2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: selectedTab)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await friendsVM.fetchFriends(userId: currentUserID)
            await friendsVM.fetchOrCreateFriendCode(userId: currentUserID)
            let ids = derivedFriendIDs
            await friendsVM.fetchActiveTodayStatus(friendIds: ids)
            await friendsVM.fetchMutualGroupCounts(currentUserId: currentUserID, friendIds: ids)
        }
        .sheet(isPresented: $showFriendCode) {
            FriendCodeSheet(code: friendsVM.friendCode)
        }
        .sheet(isPresented: $showQRScanner) {
            QRScannerSheet { code in
                let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                searchText = trimmed
                searchTask?.cancel()
                searchTask = Task { await performSearch(query: trimmed) }
            }
        }
        .onAppear {
            AnalyticsManager.shared.screen("Friends")
        }
    }

    // MARK: - Tab button helper
    @ViewBuilder
    private func tabButton(label: String, index: Int) -> some View {
        Button {
            withAnimation { selectedTab = index }
        } label: {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text(label)
                        .font(.subheadline)
                        .fontWeight(selectedTab == index ? .semibold : .regular)
                        .foregroundColor(selectedTab == index ? .white : .white.opacity(0.4))
                    if index == 2 && !friendsVM.pendingReceived.isEmpty {
                        Text("\(friendsVM.pendingReceived.count)")
                            .font(.caption2).bold()
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                }
                Rectangle()
                    .fill(selectedTab == index ? Color.white : Color.clear)
                    .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.plain)
    }

    // MARK: - Friends content

    var friendsContent: some View {
        VStack(spacing: 0) {
            // Search bar (outside NavigationStack — stays sticky at top)
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
                Button { showFriendCode = true } label: {
                    Image(systemName: "qrcode").foregroundColor(.white)
                }
                Button { showQRScanner = true } label: {
                    Image(systemName: "qrcode.viewfinder")
                        .foregroundColor(.white)
                }
            }
            .padding(10)
            .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.vertical, 12)

            // NavigationStack wraps scrollable content for friend profile navigation
            NavigationStack {
                ScrollView {
                    VStack(spacing: 12) {
                        if !searchText.isEmpty {
                            if isSearching {
                                ProgressView().padding()
                            } else if searchResults.isEmpty {
                                Text("No users found")
                                    .foregroundColor(.white.opacity(0.5))
                                    .padding()
                            } else {
                                ForEach(searchResults) { profile in
                                    SearchResultRow(profile: profile, currentUserId: currentUserID,
                                                    viewModel: friendsVM,
                                                    existingStatus: friendshipStatus(for: profile.id.uuidString))
                                }
                            }
                        } else if friendsVM.friends.isEmpty {
                            emptyState(icon: "person.2.fill",
                                       message: "No friends yet\nSearch for people or share your friend code!")
                        } else {
                            friendsCollapsedCard
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)

                    FriendsPBView(friendsVM: friendsVM)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
                .navigationBarHidden(true)
            }
        }
    }

    // MARK: - Friends Collapsed Card

    @ViewBuilder
    private var friendsCollapsedCard: some View {
        VStack(spacing: 0) {
            // Card header — always visible
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    friendsExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    // Stacked initials (first 3)
                    let previewFriends = friendsVM.friends.prefix(3)
                    ZStack {
                        ForEach(Array(previewFriends.enumerated()), id: \.offset) { index, friendship in
                            let p = friendship.requesterId.lowercased() == currentUserID.lowercased() ? friendship.receiver : friendship.requester
                            if let p {
                                InitialsCircle(name: p.displayName ?? "?", size: 32)
                                    .offset(x: CGFloat(index) * 18)
                            }
                        }
                    }
                    .frame(width: CGFloat(min(previewFriends.count, 3)) * 18 + 32, alignment: .leading)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(friendsVM.friends.count) Friends")
                            .font(.subheadline).bold()
                            .foregroundColor(.white)
                        if friendsVM.friends.count > 0 {
                            Text(friendsExpanded ? "Tap to collapse" : "Tap to expand")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.45))
                        }
                    }
                    Spacer()
                    Image(systemName: friendsExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.45))
                }
                .padding(14)
                .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
            }
            .buttonStyle(.plain)

            // Expanded rows
            if friendsExpanded {
                VStack(spacing: 1) {
                    ForEach(friendsVM.friends) { friendship in
                        let profile = friendship.requesterId.lowercased() == currentUserID.lowercased()
                            ? friendship.receiver
                            : friendship.requester
                        if let profile {
                            NavigationLink(destination:
                                FriendProfileView(
                                    profile: profile,
                                    friendship: friendship,
                                    currentUserId: currentUserID,
                                    friendsVM: friendsVM
                                )
                            ) {
                                friendRowExpanded(profile: profile)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func friendRowExpanded(profile: FriendProfile) -> some View {
        HStack(spacing: 12) {
            InitialsCircle(name: profile.displayName ?? "?", size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.displayName ?? "Unknown")
                    .font(.subheadline)
                    .foregroundColor(.white)
                if let count = friendsVM.mutualGroupCounts[profile.id], count > 0 {
                    Text("\(count) mutual group\(count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.45))
                }
            }
            Spacer()
            if friendsVM.activeTodayIDs.contains(profile.id) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(red: 0.15, green: 0.75, blue: 0.45))
                        .frame(width: 7, height: 7)
                    Text("Active")
                        .font(.caption2)
                        .foregroundColor(Color(red: 0.15, green: 0.75, blue: 0.45))
                }
            }
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.25))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
    }

    // MARK: - Requests content

    var requestsContent: some View {
        ScrollView {
            VStack(spacing: 12) {
                if friendsVM.pendingReceived.isEmpty && friendsVM.pendingSent.isEmpty {
                    emptyState(icon: "person.badge.clock.fill", message: "No pending requests")
                } else {
                    if !friendsVM.pendingReceived.isEmpty {
                        SectionHeader(title: "Received")
                        ForEach(friendsVM.pendingReceived) { friendship in
                            if let profile = friendship.requester {
                                FriendRequestRow(profile: profile, friendship: friendship,
                                                 viewModel: friendsVM, currentUserId: currentUserID)
                            }
                        }
                    }
                    if !friendsVM.pendingSent.isEmpty {
                        SectionHeader(title: "Sent")
                        ForEach(friendsVM.pendingSent) { friendship in
                            if let profile = friendship.receiver {
                                PendingSentRow(profile: profile, friendship: friendship, viewModel: friendsVM)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Helpers

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
        let all = friendsVM.friends + friendsVM.pendingReceived + friendsVM.pendingSent
        let lowerId = userId.lowercased()
        if let match = all.first(where: {
            $0.requesterId.lowercased() == lowerId || $0.receiverId.lowercased() == lowerId
        }) {
            return match.status == "accepted" ? "friends" : (match.requesterId.lowercased() == currentUserID.lowercased() ? "sent" : "received")
        }
        return nil
    }

    func performSearch(query: String) async {
        guard query.count >= 2 else { searchResults = []; return }
        isSearching = true
        defer { isSearching = false }
        if query.count == 6 {
            let profile = await friendsVM.findUserByFriendCode(query)
            guard !Task.isCancelled else { return }
            if let profile, profile.id.uuidString.lowercased() != currentUserID.lowercased() {
                searchResults = [profile]
            } else {
                searchResults = []
            }
            return
        }
        let results = await friendsVM.searchUsers(query: query, currentUserId: currentUserID)
        guard !Task.isCancelled else { return }
        searchResults = results.filter { $0.id.uuidString.lowercased() != currentUserID.lowercased() }
    }
}
