import SwiftUI

struct FriendProfileView: View {
    let profile: FriendProfile
    let friendship: Friendship
    let currentUserId: String
    @Bindable var friendsVM: FriendsViewModel

    @State private var vm = FriendProfileViewModel()
    @Environment(\.dismiss) private var dismiss

    private let teal = Color(red: 0.08, green: 0.35, blue: 0.45)
    private let cardBG = Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92)

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection
                comparisonStrip
                statsStrip
                if !vm.pbs.isEmpty { pbSection }
                if !vm.checkIns.isEmpty { checkInScores }
                if !vm.habitLogs.filter({ !($0.habit?.isPrivate ?? true) }).isEmpty { recentActivity }
                if !vm.mutualGroups.isEmpty { mutualGroupsSection }
                cheerButton
                removeFriendButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(Color.black.opacity(0.85).ignoresSafeArea())
        .navigationTitle(profile.displayName ?? "Friend")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.loadAll(friendId: profile.id, currentUserId: currentUserId) }
        .overlay {
            if vm.isLoading {
                ProgressView().tint(.white)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 10) {
            InitialsCircle(name: profile.displayName ?? "?", size: 72)
            Text(profile.displayName ?? "Unknown")
                .font(.title2).bold()
                .foregroundColor(.white)
            if !vm.friendCode.isEmpty {
                Text("#\(vm.friendCode)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.45))
            }
            activeLabel
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(cardBG.cornerRadius(16))
    }

    private var activeLabel: some View {
        Group {
            if friendsVM.activeTodayIDs.contains(profile.id) {
                Label("Active today", systemImage: "circle.fill")
                    .font(.caption).fontWeight(.medium)
                    .foregroundColor(Color(red: 0.15, green: 0.75, blue: 0.45))
            } else if let lastDate = vm.habitLogs.first.flatMap({ DateFormatter.habitDate.date(from: $0.loggedDate) }) {
                let days = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
                Text(days == 0 ? "Active today" : "Last active \(days) day\(days == 1 ? "" : "s") ago")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.45))
            } else {
                Text("No recent activity")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.45))
            }
        }
    }

    // MARK: - Comparison Strip

    private var comparisonStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("vs You")
                .font(.caption).bold()
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)

            HStack(spacing: 0) {
                comparisonCell(
                    label: "Streak",
                    youValue: "\(myCurrentStreak)",
                    themValue: "\(vm.currentStreak)",
                    youWins: myCurrentStreak >= vm.currentStreak
                )
                Divider().background(Color.white.opacity(0.15)).frame(width: 1)
                comparisonCell(
                    label: "Check-ins",
                    youValue: "\(myTotalCheckIns)",
                    themValue: "\(vm.totalCheckIns)",
                    youWins: myTotalCheckIns >= vm.totalCheckIns
                )
                Divider().background(Color.white.opacity(0.15)).frame(width: 1)
                comparisonCell(
                    label: "Top PB",
                    youValue: myTopPBLabel,
                    themValue: theirTopPBLabel,
                    youWins: myTopPBValue >= theirTopPBValue
                )
            }
        }
        .padding(16)
        .background(cardBG.cornerRadius(16))
    }

    private func comparisonCell(label: String, youValue: String, themValue: String, youWins: Bool) -> some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.caption2).bold()
                .foregroundColor(.white.opacity(0.45))
                .textCase(.uppercase)
            Text("You")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.45))
            Text(youValue)
                .font(.subheadline).bold()
                .foregroundColor(youWins ? teal : .white.opacity(0.45))
            Text("Them")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.45))
            Text(themValue)
                .font(.subheadline).bold()
                .foregroundColor(youWins ? .white.opacity(0.45) : teal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Stats Strip

    private var statsStrip: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(title: "🔥 Current Streak", value: "\(vm.currentStreak) days")
            StatCard(title: "🏆 Longest Streak", value: "\(vm.longestStreak) days")
            StatCard(title: "📋 Check-ins", value: "\(vm.totalCheckIns) in 7 days")
            StatCard(title: "🎯 Personal Bests", value: "\(vm.pbs.count)")
        }
    }

    // MARK: - Personal Bests

    private var pbSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Personal Bests")
            ForEach(vm.pbs.prefix(5)) { pb in
                HStack(spacing: 12) {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 14))
                    Text(pb.eventName)
                        .font(.subheadline)
                        .foregroundColor(.white)
                    Spacer()
                    Text(formatPBValue(pb))
                        .font(.subheadline).bold()
                        .foregroundColor(teal)
                }
                .padding(12)
                .background(cardBG.cornerRadius(12))
            }
        }
    }

    // MARK: - Check-in Scores

    private var checkInScores: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Check-in Scores (7 days)")
            HStack(spacing: 6) {
                ForEach(vm.checkIns.suffix(7)) { record in
                    VStack(spacing: 4) {
                        Text(shortDay(record.checkinDate))
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.45))
                        scoreDot(value: record.mood ?? record.energy, max: 5, color: Color.purple)
                        scoreDot(value: record.energy, max: 5, color: Color.orange)
                        scoreDot(value: record.sleep, max: 5, color: Color.blue)
                        scoreDot(value: record.wellbeing, max: 5, color: Color.green)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            HStack(spacing: 12) {
                legendDot(color: .purple, label: "Mood")
                legendDot(color: .orange, label: "Energy")
                legendDot(color: .blue, label: "Sleep")
                legendDot(color: .green, label: "Wellbeing")
            }
            .font(.caption2)
            .foregroundColor(.white.opacity(0.45))
        }
        .padding(16)
        .background(cardBG.cornerRadius(16))
    }

    // MARK: - Recent Activity

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Recent Activity")
            let visible = vm.habitLogs.filter { !($0.habit?.isPrivate ?? true) }.prefix(5)
            ForEach(Array(visible)) { log in
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(teal)
                        .font(.system(size: 14))
                    Text(log.habit?.name ?? "Habit")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    Spacer()
                    Text(daysAgoLabel(log.loggedDate))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.45))
                }
                .padding(12)
                .background(cardBG.cornerRadius(12))
            }
        }
    }

    // MARK: - Mutual Groups

    private var mutualGroupsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Mutual Groups")
            ForEach(vm.mutualGroups) { group in
                NavigationLink(destination: GroupDetailView(group: group)) {
                    HStack(spacing: 12) {
                        Image(systemName: "person.3.fill")
                            .foregroundColor(teal)
                            .font(.system(size: 14))
                        Text(group.name)
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .padding(12)
                    .background(cardBG.cornerRadius(12))
                }
            }
        }
    }

    // MARK: - Cheer Button

    private var cheerButton: some View {
        Button {
            Task { await vm.sendCheer(from: currentUserId, to: profile.id) }
        } label: {
            HStack {
                Text(vm.alreadyCheeredToday ? "Cheered today 🔥" : "👊 Send Cheer")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(vm.alreadyCheeredToday ? Color.white.opacity(0.1) : teal)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(vm.alreadyCheeredToday)
    }

    // MARK: - Remove Friend

    private var removeFriendButton: some View {
        Button(role: .destructive) {
            Task {
                await friendsVM.removeFriend(friendshipId: friendship.id)
                dismiss()
            }
        } label: {
            Text("Remove Friend")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.red.opacity(0.15))
                .foregroundColor(Color.red.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption).bold()
            .foregroundColor(.white.opacity(0.5))
            .textCase(.uppercase)
    }

    private func scoreDot(value: Int, max: Int, color: Color) -> some View {
        let ratio = Double(value) / Double(max)
        return Circle()
            .fill(color.opacity(0.3 + ratio * 0.7))
            .frame(width: 10, height: 10)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }

    private func formatPBValue(_ pb: PersonalBest) -> String {
        if let reps = pb.reps, reps > 0 {
            return "\(Int(pb.value))\(pb.valueUnit) × \(reps)"
        }
        return "\(Int(pb.value))\(pb.valueUnit)"
    }

    private func shortDay(_ dateString: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: dateString) else { return "" }
        f.dateFormat = "E"
        return String(f.string(from: date).prefix(1))
    }

    private func daysAgoLabel(_ dateString: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: dateString) else { return "" }
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        return "\(days)d ago"
    }

    // MARK: - Comparison Computed Values

    private var myCurrentStreak: Int { vm.currentUserStreak }

    private var myTotalCheckIns: Int { vm.currentUserCheckInCount }

    private var myTopPBValue: Double {
        vm.currentUserPBs.map { $0.value }.max() ?? 0
    }

    private var theirTopPBValue: Double {
        vm.pbs.map { $0.value }.max() ?? 0
    }

    private var myTopPBLabel: String {
        guard let pb = vm.currentUserPBs.max(by: { $0.value < $1.value }) else { return "–" }
        return "\(Int(pb.value))\(pb.valueUnit)"
    }

    private var theirTopPBLabel: String {
        guard let pb = vm.pbs.max(by: { $0.value < $1.value }) else { return "–" }
        return "\(Int(pb.value))\(pb.valueUnit)"
    }
}

// MARK: - Initials Circle

struct InitialsCircle: View {
    let name: String
    let size: CGFloat

    private var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.08, green: 0.35, blue: 0.45))
            Text(initials)
                .font(.system(size: size * 0.35, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
    }
}
