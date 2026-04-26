import SwiftUI

struct GroupListView: View {
    @State private var viewModel = GroupViewModel()
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showCreateGroup = false
    @State private var showJoinGroup = false
    @State private var showProfile = false
    @State private var showNotifications = false
    @State private var pendingCount: Int = 0

    // TODO: sort by check-in status once async state is available
    var sortedGroups: [AppGroup] {
        viewModel.groups.sorted { $0.name < $1.name }
    }

    private func rsvpBadge(_ status: String?) -> some View {
        let label: String
        let color: Color
        switch status {
        case "going":
            label = "Going"
            color = .green
        case "maybe":
            label = "Maybe"
            color = .orange
        case "not_going":
            label = "Not Going"
            color = .red
        default:
            label = "RSVP Needed"
            color = .red
        }
        return Text(label)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    private func nextSessionLabel(for date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
        switch days {
        case 0: return "📅 Session today"
        case 1: return "📅 Session tomorrow"
        default: return "📅 Next session in \(days) days"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // BACKGROUND
                GeometryReader { geo in
                    ZStack {
                        Image(themeManager.currentBackgroundImage)
                            .resizable()
                            .scaledToFill()
                            .grayscale(1.0)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()

                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.67),
                                Color.black.opacity(0.47),
                                Color.black.opacity(0.72)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
                .ignoresSafeArea()

                // CONTENT
                VStack(spacing: 0) {
                    // HEADER
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("My Groups")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                            Text("Welcome back, \(appState.currentUser?.displayName ?? "there") 👋")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        Spacer()
                        HStack(spacing: 16) {
                            Button {
                                showNotifications = true
                            } label: {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "bell")
                                        .foregroundStyle(.white)
                                    if pendingCount > 0 {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 8, height: 8)
                                            .offset(x: 4, y: -4)
                                    }
                                }
                            }
                            Button {
                                showProfile = true
                            } label: {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 26))
                                    .foregroundStyle(.white)
                            }
                            Menu {
                                Button {
                                    showCreateGroup = true
                                } label: {
                                    Label("Create Group", systemImage: "plus.circle")
                                }
                                Button {
                                    showJoinGroup = true
                                } label: {
                                    Label("Join Group", systemImage: "arrow.right.circle")
                                }
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 20)

                    // GROUPS
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView().tint(.white)
                        Spacer()
                    } else if viewModel.groups.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.white.opacity(0.6))
                            Text("No groups yet")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                            Text("Create a group or join one\nwith an invite code")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                            HStack(spacing: 12) {
                                Button {
                                    showCreateGroup = true
                                } label: {
                                    Label("Create", systemImage: "plus.circle.fill")
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.white)
                                        .foregroundStyle(Color.black)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                Button {
                                    showJoinGroup = true
                                } label: {
                                    Label("Join", systemImage: "arrow.right.circle.fill")
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                                        .foregroundStyle(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding()
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(sortedGroups) { group in
                                    NavigationLink(destination: GroupDetailView(group: group)) {
                                        HStack(spacing: 12) {
                                            GroupAvatarStackView(members: viewModel.groupMembers[group.id] ?? [])
                                                .frame(width: 80)
                                                .clipped()
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(group.name)
                                                    .font(.headline)
                                                    .fontWeight(.semibold)
                                                    .foregroundStyle(.white)
                                                if let members = viewModel.groupMembers[group.id] {
                                                    Text("\(members.count) member\(members.count == 1 ? "" : "s")")
                                                        .font(.caption)
                                                        .foregroundStyle(.white.opacity(0.6))
                                                }
                                                if let next = viewModel.nextSessions[group.id], let proposed = next.proposedAt {
                                                    Text(proposed.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
                                                        .font(.caption)
                                                        .foregroundStyle(.white.opacity(0.5))
                                                    rsvpBadge(viewModel.nextSessionMyRSVPs[group.id])
                                                }
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.5))
                                        }
                                        .padding(16)
                                        .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .strokeBorder(themeManager.currentTheme.primary.opacity(0.6), lineWidth: 2)
                                        )
                                        .padding(.horizontal)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .task {
                await viewModel.fetchGroups()
                if let userId = appState.currentUser?.id {
                    await viewModel.fetchNextSessionRSVPs(userId: userId)
                    pendingCount = await fetchPendingNotificationCount(userId: userId)
                }
            }
            .sheet(isPresented: $showCreateGroup) {
                CreateGroupView(viewModel: viewModel)
            }
            .sheet(isPresented: $showJoinGroup) {
                JoinGroupView(viewModel: viewModel)
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
            }
            .sheet(isPresented: $showNotifications) {
                NotificationsView()
            }
            .onChange(of: showNotifications) { _, isShowing in
                if !isShowing {
                    Task {
                        if let userId = appState.currentUser?.id {
                            pendingCount = await fetchPendingNotificationCount(userId: userId)
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .groupMembershipChanged)) { _ in
                Task { await viewModel.fetchGroups() }
            }
            .onboardingTooltip(screen: "groups", title: "Your Groups", message: "Create or join groups with friends and teammates. Share sessions, track attendance and stay accountable together.", icon: "person.3.fill")
        }
        .onAppear {
            AnalyticsManager.shared.screen("Groups")
        }
    }
}
