import SwiftUI
import Supabase

struct HabitDetailView: View {
    let habit: Habit
    @ObservedObject var viewModel: HabitViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    @State private var showingDeleteAlert = false
    @State private var showingEditSheet = false
    @State private var showingInviteSheet = false
    @State private var friendsViewModel = FriendsViewModel()
    @State private var habitMembers: [HabitMember] = []

    var currentUserId: UUID { appState.currentUser?.id ?? UUID() }
    var acceptedMembers: [HabitMember] { habitMembers.filter { $0.status == "accepted" } }
    var pendingMembers: [HabitMember] { habitMembers.filter { $0.status == "pending" } }

    var body: some View {
        ZStack {
            themeManager.backgroundColour().ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    streakCard
                    inviteFriendsCard
                    historyCard
                }
                .padding(.vertical)
            }
        }
        .navigationTitle(habit.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundColor(themeManager.currentTheme.primary)
                    }
                    Button {
                        showingDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .task {
            await friendsViewModel.fetchFriends(userId: currentUserId.uuidString)
            await fetchHabitMembers()
        }
        .alert("Delete Habit?", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteHabit(habit)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete all logs for this habit too.")
        }
        .sheet(isPresented: $showingEditSheet) {
            EditHabitView(habit: habit, viewModel: viewModel)
        }
        .sheet(isPresented: $showingInviteSheet) {
            InviteFriendsToHabitView(
                habit: habit,
                friendsViewModel: friendsViewModel,
                habitMembers: habitMembers,
                currentUserId: currentUserId,
                onInvite: { await fetchHabitMembers() }
            )
        }
    }

    func fetchHabitMembers() async {
        do {
            let members: [HabitMember] = try await supabase
                .from("habit_members")
                .select()
                .eq("habit_id", value: habit.id)
                .execute()
                .value
            habitMembers = members
        } catch {}
    }

    func friendName(for userId: String) -> String {
        for f in friendsViewModel.friends {
            if f.requesterId == userId { return f.receiver?.displayName ?? "Friend" }
            if f.receiverId == userId { return f.requester?.displayName ?? "Friend" }
        }
        return "Friend"
    }

    var streakCard: some View {
        let current = viewModel.currentStreak(for: habit, userId: currentUserId)
        let best = viewModel.bestStreak(for: habit, userId: currentUserId)
        return VStack(spacing: 16) {
            Text("Streaks")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            HStack(spacing: 0) {
                VStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                            .font(.title2)
                        Text("\(current)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                    }
                    Text("Current streak")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                Divider().frame(height: 50)
                VStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(.yellow)
                            .font(.title2)
                        Text("\(best)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                    }
                    Text("Best streak")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 8)
        }
        .padding(.vertical, 16)
        .background(themeManager.cardColour())
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    var inviteFriendsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Accountability Partners")
                    .font(.headline)
                Spacer()
                Button {
                    showingInviteSheet = true
                } label: {
                    Label("Invite", systemImage: "person.badge.plus")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(themeManager.currentTheme.primary)
                }
            }
            .padding(.horizontal)

            if acceptedMembers.isEmpty && pendingMembers.isEmpty {
                Text("Invite friends to do this habit together 💪")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
            } else {
                ForEach(acceptedMembers, id: \.userId) { member in
                    HStack {
                        Image(systemName: "person.fill.checkmark")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text(friendName(for: member.userId))
                            .font(.subheadline)
                        Spacer()
                        Text("Active")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
                ForEach(pendingMembers, id: \.userId) { member in
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text(friendName(for: member.userId))
                            .font(.subheadline)
                        Spacer()
                        Text("Invited")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.vertical, 16)
        .background(themeManager.cardColour())
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    var historyCard: some View {
        VStack(spacing: 12) {
            Text("History")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            HabitCalendarGrid(habit: habit, viewModel: viewModel, userId: currentUserId)
                .padding(.horizontal)
        }
        .padding(.vertical, 16)
        .background(themeManager.cardColour())
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

// MARK: - InviteFriendsToHabitView

struct InviteFriendsToHabitView: View {
    let habit: Habit
    let friendsViewModel: FriendsViewModel
    let habitMembers: [HabitMember]
    let currentUserId: UUID
    let onInvite: () async -> Void
    @Environment(\.dismiss) var dismiss
    @State private var sentInvites: Set<String> = []

    var body: some View {
        NavigationView {
            List {
                if friendsViewModel.friends.isEmpty {
                    Text("No friends yet — add friends from the Groups tab!")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(friendsViewModel.friends) { friendship in
                        let profile = friendship.requesterId == currentUserId.uuidString
                            ? friendship.receiver
                            : friendship.requester
                        if let profile {
                            HStack {
                                AvatarView(url: profile.avatarUrl, size: 36)
                                Text(profile.displayName ?? "Friend")
                                    .font(.subheadline)
                                Spacer()
                                inviteButton(for: profile)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Invite Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    func alreadyInvited(_ profileId: String) -> Bool {
        habitMembers.contains { $0.userId == profileId }
    }

    @ViewBuilder
    func inviteButton(for profile: FriendProfile) -> some View {
        if sentInvites.contains(profile.id) {
            Text("Invited!")
                .font(.caption).bold()
                .foregroundColor(.green)
        } else if alreadyInvited(profile.id) {
            Text(habitMembers.first { $0.userId == profile.id }?.status == "accepted" ? "Active" : "Pending")
                .font(.caption)
                .foregroundColor(.secondary)
        } else {
            Button {
                Task {
                    await friendsViewModel.inviteFriendToHabit(
                        habitId: habit.id.uuidString,
                        friendUserId: profile.id,
                        invitedBy: currentUserId.uuidString
                    )
                    sentInvites.insert(profile.id)
                    await onInvite()
                }
            } label: {
                Text("Invite")
                    .font(.caption).bold()
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.08, green: 0.35, blue: 0.45))
                    .cornerRadius(8)
            }
        }
    }
}

// MARK: - EditHabitView

struct EditHabitView: View {
    let habit: Habit
    @ObservedObject var viewModel: HabitViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    @State private var name: String
    @State private var hasTarget: Bool
    @State private var targetCount: Int
    @State private var isPrivate: Bool

    init(habit: Habit, viewModel: HabitViewModel) {
        self.habit = habit
        self.viewModel = viewModel
        _name = State(initialValue: habit.name)
        _hasTarget = State(initialValue: habit.targetCount != nil)
        _targetCount = State(initialValue: habit.targetCount ?? 1)
        _isPrivate = State(initialValue: habit.isPrivate)
    }

    @ViewBuilder
    private func formCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline).padding(.horizontal)
            VStack(alignment: .leading, spacing: 0) {
                content().padding()
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                themeManager.backgroundColour().ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        formCard(title: "Habit Name") {
                            TextField("Habit name", text: $name)
                        }
                        formCard(title: "Daily Target") {
                            VStack(spacing: 10) {
                                Toggle("Set a target count", isOn: $hasTarget)
                                    .tint(themeManager.currentTheme.primary)
                                if hasTarget {
                                    Divider()
                                    Stepper("\(targetCount) times per day", value: $targetCount, in: 2...100)
                                }
                            }
                        }
                        formCard(title: "Privacy") {
                            VStack(alignment: .leading, spacing: 8) {
                                Toggle("Keep this habit private", isOn: $isPrivate)
                                    .tint(themeManager.currentTheme.primary)
                                Text(isPrivate
                                    ? "Friends will see you hit a streak but won't see the habit name."
                                    : "Friends will see your streak and habit name.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Edit Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(themeManager.currentTheme.primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await viewModel.updateHabit(
                                habit,
                                name: name,
                                targetCount: hasTarget ? targetCount : nil,
                                isPrivate: isPrivate
                            )
                            dismiss()
                        }
                    }
                    .foregroundColor(name.isEmpty ? .secondary : themeManager.currentTheme.primary)
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - HabitCalendarGrid

struct HabitCalendarGrid: View {
    let habit: Habit
    @ObservedObject var viewModel: HabitViewModel
    let userId: UUID
    @EnvironmentObject var themeManager: ThemeManager

    @State private var windowOffset = 0

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let dayHeaders = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var windowEndDate: Date {
        calendar.date(byAdding: .day, value: windowOffset * 28, to: Date()) ?? Date()
    }

    var days: [Date] {
        (0..<28).compactMap { offset in
            calendar.date(byAdding: .day, value: -(27 - offset), to: windowEndDate)
        }
    }

    var periodLabel: String {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        let fYear = DateFormatter()
        fYear.dateFormat = "d MMM yyyy"
        guard let first = days.first, let last = days.last else { return "" }
        return "\(f.string(from: first)) – \(fYear.string(from: last))"
    }

    var isAtCurrentWindow: Bool { windowOffset == 0 }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    windowOffset -= 1
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(themeManager.currentTheme.primary)
                        .frame(width: 32, height: 32)
                }
                Spacer()
                Text(periodLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    windowOffset += 1
                } label: {
                    Image(systemName: "chevron.right")
                        .foregroundColor(isAtCurrentWindow ? .secondary.opacity(0.4) : themeManager.currentTheme.primary)
                        .frame(width: 32, height: 32)
                }
                .disabled(isAtCurrentWindow)
                if !isAtCurrentWindow {
                    Button {
                        windowOffset = 0
                    } label: {
                        Text("Today")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(themeManager.currentTheme.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(themeManager.currentTheme.primary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }
            HStack(spacing: 4) {
                ForEach(dayHeaders, id: \.self) { header in
                    Text(header)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(days, id: \.self) { date in
                    let completed = viewModel.isCompleted(habit, on: date, userId: userId)
                    let isToday = calendar.isDateInToday(date)
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(completed ? themeManager.currentTheme.primary : Color(.systemGray5))
                            .frame(height: 32)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(isToday ? themeManager.currentTheme.primary : Color.clear, lineWidth: 2)
                            )
                        Text(dayNum(date))
                            .font(.caption2)
                            .fontWeight(isToday ? .bold : .regular)
                            .foregroundColor(completed ? .white : .secondary)
                    }
                }
            }
        }
    }

    func dayNum(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: date)
    }
}
