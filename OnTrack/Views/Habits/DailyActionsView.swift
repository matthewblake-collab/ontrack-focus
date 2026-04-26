import SwiftUI
import Supabase

struct DailyActionsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var viewModel = HabitViewModel()
    @State private var sessionVM = SessionViewModel()
    @State private var challengeVM = ChallengeViewModel()
    @State private var friendsVM = FriendsViewModel()
    @StateObject private var supplementVM = SupplementViewModel()
    @State private var selectedDate = Date()
    @State private var showingAddHabit = false
    @State private var groupIds: [UUID] = []
    @State private var selectedSession: AppSession? = nil
    @State private var selectedSupplement: Supplement? = nil
    @State private var groupsById: [UUID: AppGroup] = [:]
    @State private var showCompleted = true
    @State private var attendedSessionIds: Set<UUID> = []
    @State private var showProfile = false
    @State private var showNotifications = false
    @State private var selectedHabitId: UUID? = nil
    @State private var scrollToItemId: String? = nil
    @State private var showCelebration = false
    @State private var showCreateChallenge = false
    @State private var showChallengeInvite = false
    @State private var selectedChallenge: Challenge? = nil
    @Environment(ProgressViewModel.self) private var progressVM

    private let calendar = Calendar.current

    // MARK: - Computed item lists

    private var todaysHabits: [Habit] {
        viewModel.habitsForDate(selectedDate, groupIds: groupIds)
    }

    private var completedHabitIdsForDate: Set<UUID> {
        guard let userId = appState.currentUser?.id else { return [] }
        let ds = dateString(selectedDate)
        return Set(
            todaysHabits.compactMap { habit -> UUID? in
                guard let log = viewModel.logs.first(where: {
                    $0.habitId == habit.id && $0.userId == userId && $0.loggedDate == ds
                }) else { return nil }
                return log.count >= (habit.targetCount ?? 1) ? habit.id : nil
            }
        )
    }

    private var completedSupplementIdsForDate: Set<UUID> {
        let ds = dateString(selectedDate)
        return Set(
            todaysSupplements.compactMap { supplement -> UUID? in
                let taken = supplementVM.supplementLogs.contains {
                    $0.supplementId == supplement.id && $0.takenAt == ds
                }
                return taken ? supplement.id : nil
            }
        )
    }

    private var allSortedItems: [DailyItem] {
        let habitItems = todaysHabits.map { DailyItem.habit($0) }
        let sessionItems = todaysSessions.map { DailyItem.session($0) }
        let supplementItems = todaysSupplements.map { DailyItem.supplement($0) }
        return (habitItems + sessionItems + supplementItems).sorted { a, b in
            let timeA = a.sortTime, timeB = b.sortTime
            if let ta = timeA, let tb = timeB { return ta < tb }
            if timeA != nil { return true }
            if timeB != nil { return false }
            return false
        }
    }

    private var isCheckinCompletedToday: Bool {
        guard let dateStr = UserDefaults.standard.string(forKey: "checkin_completed_date") else { return false }
        return dateStr == DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
    }

    private var completedItemCount: Int {
        let attendedTodayCount = todaysSessions.filter { attendedSessionIds.contains($0.id) }.count
        return completedHabitIdsForDate.count + completedSupplementIdsForDate.count + attendedTodayCount
    }

    private var visibleItems: [DailyItem] {
        allSortedItems.filter { item in
            switch item {
            case .habit(let habit):
                return showCompleted || !completedHabitIdsForDate.contains(habit.id)
            case .supplement(let supplement):
                return showCompleted || !completedSupplementIdsForDate.contains(supplement.id)
            case .session(let session):
                return showCompleted || !attendedSessionIds.contains(session.id)
            }
        }
    }

    private var firstIncompleteItem: DailyItem? {
        allSortedItems.first { item in
            switch item {
            case .habit(let habit):
                return !completedHabitIdsForDate.contains(habit.id)
            case .supplement(let supplement):
                return !completedSupplementIdsForDate.contains(supplement.id)
            case .session(let session):
                return !attendedSessionIds.contains(session.id)
            }
        }
    }

    private var firstIncompleteItemName: String {
        guard let item = firstIncompleteItem else { return "" }
        switch item {
        case .habit(let habit): return habit.name
        case .session(let session): return session.title
        case .supplement(let supplement): return supplement.name
        }
    }

    private var longestStreakToday: Int {
        guard let userId = appState.currentUser?.id else { return 0 }
        return todaysHabits.map { viewModel.currentStreak(for: $0, userId: userId) }.max() ?? 0
    }

    // MARK: - Sessions / Supplements

    var todaysSessions: [AppSession] {
        sessionVM.sessions.filter { session in
            guard let scheduledAt = session.proposedAt else { return false }
            return calendar.isDate(scheduledAt, inSameDayAs: selectedDate)
        }
    }

    var todaysSupplements: [Supplement] {
        let weekdayNum = calendar.component(.weekday, from: selectedDate)
        let weekdayStr = String(weekdayNum)
        return supplementVM.protocolSupplements.filter { supplement in
            let days = supplement.daysOfWeek
            if days == "everyday" || days.isEmpty { return true }
            return days.components(separatedBy: ",").contains(weekdayStr)
        }
    }

    func isSupplementTakenToday(_ supplement: Supplement) -> Bool {
        let ds = dateString(selectedDate)
        return supplementVM.supplementLogs.contains {
            $0.supplementId == supplement.id && $0.takenAt == ds
        }
    }

    func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    // MARK: - Attendance

    private func loadAttendance() async {
        guard let userId = appState.currentUser?.id else { return }
        let sessions = todaysSessions
        guard !sessions.isEmpty else {
            attendedSessionIds = []
            return
        }

        struct AttendanceRecord: Decodable {
            let sessionId: UUID
            let attended: Bool
            enum CodingKeys: String, CodingKey {
                case sessionId = "session_id"
                case attended
            }
        }

        do {
            let records: [AttendanceRecord] = try await supabase
                .from("attendance")
                .select("session_id, attended")
                .eq("user_id", value: userId.uuidString)
                .in("session_id", values: sessions.map { $0.id.uuidString })
                .execute()
                .value
            attendedSessionIds = Set(records.filter { $0.attended }.map { $0.sessionId })
        } catch {
            print("[DailyActions] loadAttendance error: \(error)")
        }
    }

    private func toggleAttendance(for session: AppSession) async {
        guard let userId = appState.currentUser?.id else { return }
        let currentlyAttended = attendedSessionIds.contains(session.id)

        if currentlyAttended {
            attendedSessionIds.remove(session.id)
        } else {
            attendedSessionIds.insert(session.id)
        }

        struct AttendanceUpsert: Encodable {
            let sessionId: UUID
            let userId: UUID
            let attended: Bool
            let markedBy: UUID
            enum CodingKeys: String, CodingKey {
                case sessionId = "session_id"
                case userId = "user_id"
                case attended
                case markedBy = "marked_by"
            }
        }

        do {
            try await supabase
                .from("attendance")
                .upsert(
                    AttendanceUpsert(
                        sessionId: session.id,
                        userId: userId,
                        attended: !currentlyAttended,
                        markedBy: userId
                    ),
                    onConflict: "session_id,user_id"
                )
                .execute()
        } catch {
            if currentlyAttended {
                attendedSessionIds.insert(session.id)
            } else {
                attendedSessionIds.remove(session.id)
            }
            print("[DailyActions] toggleAttendance error: \(error)")
        }
    }

    // MARK: - Priority Card

    var priorityCard: some View {
        Group {
            if !allSortedItems.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    if let incomplete = firstIncompleteItem {
                        HStack(spacing: 8) {
                            Text("🔥 TODAY")
                                .font(.headline)
                                .fontWeight(.heavy)
                                .foregroundStyle(.white)
                            Text("\(completedItemCount)/\(allSortedItems.count) actions complete")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white.opacity(0.8))
                            Spacer()
                        }
                        Text("Up next: \(firstIncompleteItemName)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                        Button {
                            scrollToItemId = incomplete.id
                        } label: {
                            Text("Complete Now")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.08, green: 0.35, blue: 0.45),
                                            Color(red: 0.15, green: 0.55, blue: 0.38)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    } else {
                        ZStack {
                            // Animated particles
                            TimelineView(.animation) { timeline in
                                Canvas { context, size in
                                    let t = timeline.date.timeIntervalSinceReferenceDate
                                    for i in 0..<18 {
                                        let seed = Double(i) * 137.5
                                        let x = (sin(t * 0.4 + seed) * 0.5 + 0.5) * size.width
                                        let y = (cos(t * 0.3 + seed * 0.7) * 0.5 + 0.5) * size.height
                                        let radius = 2.0 + sin(t + seed) * 1.5
                                        let opacity = 0.3 + sin(t * 0.6 + seed) * 0.2
                                        context.fill(
                                            Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                                            with: .color(Color.white.opacity(opacity))
                                        )
                                    }
                                }
                            }
                            .allowsHitTesting(false)

                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Day Complete")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Text("All actions completed")
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.9))
                                    Text("Consistency builds results")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.75))
                                }
                                Spacer()
                                ZStack {
                                    Circle()
                                        .stroke(Color.white.opacity(0.35), lineWidth: 4)
                                        .frame(width: 56, height: 56)
                                    Circle()
                                        .trim(from: 0, to: 1.0)
                                        .stroke(Color.white, lineWidth: 4)
                                        .frame(width: 56, height: 56)
                                        .rotationEffect(.degrees(-90))
                                    Text("100%")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 0, maxHeight: 72)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(
                    Group {
                        if firstIncompleteItem == nil && !allSortedItems.isEmpty {
                            LinearGradient(
                                colors: [Color(red: 0.05, green: 0.45, blue: 0.55), Color(red: 0.10, green: 0.75, blue: 0.50)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        } else {
                            Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92)
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Celebration Overlay

    var celebrationOverlay: some View {
        CelebrationOverlayView(
            show: $showCelebration,
            completedCount: completedItemCount,
            totalCount: allSortedItems.count,
            streakDays: longestStreakToday
        )
    }

    // MARK: - Challenge Sheet

    @ViewBuilder
    private var challengeSheet: some View {
        if let user = appState.currentUser {
            CreateChallengeView(
                viewModel: challengeVM,
                userId: user.id,
                friends: friendsVM.friends.compactMap { friendship in
                    let currentUserId = appState.currentUser?.id.uuidString ?? ""
                    if friendship.receiverId.lowercased() == currentUserId.lowercased() {
                        return friendship.requester
                    } else {
                        return friendship.receiver
                    }
                }.compactMap { $0 },
                groups: Array(groupsById.values),
                onDismiss: { showCreateChallenge = false }
            )
        }
    }

    // MARK: - Challenge Invite Overlay

    @ViewBuilder
    private var challengeInviteOverlay: some View {
        if showChallengeInvite,
           let challenge = challengeVM.incomingChallenge,
           let invite = challengeVM.incomingInvite {
            ZStack {
                Color.black.opacity(0.72)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.3)) { showChallengeInvite = false }
                    }

                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.2))
                            .frame(width: 80, height: 80)
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 36))
                            .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                    }

                    Text("You've Been Challenged!")
                        .font(.title2.bold())
                        .foregroundColor(.white)

                    Text(challenge.title)
                        .font(.headline)
                        .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                        .multilineTextAlignment(.center)

                    if let desc = challenge.description {
                        Text(desc)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 4) {
                        Text("Goal: \(Int(challenge.goalTarget)) \(challenge.goalUnit ?? "") \(challenge.frequency ?? "")")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        if let end = challenge.endDate {
                            Text("Ends: \(end.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        Text("Accept by: \(challenge.acceptBy.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.3), lineWidth: 1))
                    )

                    HStack(spacing: 16) {
                        Button {
                            Task {
                                if let user = appState.currentUser {
                                    await challengeVM.respondToInvite(inviteId: invite.id, accept: false, userId: user.id)
                                }
                                withAnimation(.easeOut(duration: 0.3)) { showChallengeInvite = false }
                            }
                        } label: {
                            Text("Decline")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.1)))
                        }

                        Button {
                            Task {
                                if let user = appState.currentUser {
                                    await challengeVM.respondToInvite(inviteId: invite.id, accept: true, userId: user.id)
                                }
                                withAnimation(.easeOut(duration: 0.3)) { showChallengeInvite = false }
                            }
                        } label: {
                            Text("Accept")
                                .font(.headline.bold())
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color(red: 1.0, green: 0.84, blue: 0.0)))
                        }
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(red: 0.08, green: 0.12, blue: 0.15))
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.4), lineWidth: 1.5))
                )
                .padding(.horizontal, 24)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.92)))
        }
    }

    // MARK: - List Content

    @ViewBuilder
    private var listContent: some View {
        let userId = appState.currentUser?.id ?? UUID()
        LazyVStack(spacing: 8) {
            // Active challenges — shown above habits
            if !challengeVM.challenges.isEmpty {
                ForEach(challengeVM.challenges) { challenge in
                    ChallengeRowView(challenge: challenge)
                        .onTapGesture { selectedChallenge = challenge }
                }
            }
            if allSortedItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.7))
                    Text("Nothing scheduled for this day")
                        .foregroundColor(.white.opacity(0.7))
                    Text("Tap + to add a habit")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                    Button {
                        showingAddHabit = true
                    } label: {
                        Label("Add Habit", systemImage: "plus.circle.fill")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(themeManager.currentTheme.gradient)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                ForEach(visibleItems) { item in
                    switch item {
                    case .habit(let habit):
                        let isCompleted = completedHabitIdsForDate.contains(habit.id)
                        let showFreezeToday = Calendar.current.isDateInToday(selectedDate) && !isCompleted
                        VStack(spacing: 4) {
                            HabitRowView(habit: habit, date: selectedDate, userId: userId, viewModel: viewModel, onNavigate: { selectedHabitId = habit.id })
                                .contextMenu {
                                    if showFreezeToday && viewModel.isFreezeAvailable(for: habit) {
                                        Button {
                                            Task { await viewModel.applyFreeze(habitId: habit.id, userId: userId) }
                                        } label: {
                                            Label("Freeze Streak", systemImage: "snowflake")
                                        }
                                    }
                                    Button(role: .destructive) {
                                        Task { await viewModel.archiveHabit(habit) }
                                    } label: {
                                        Label("Archive", systemImage: "archivebox.fill")
                                    }
                                }
                            if showFreezeToday {
                                HStack {
                                    Text(viewModel.isFreezeAvailable(for: habit) ? "❄️ Freeze available" : "❄️ Freeze used this week")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.45))
                                    Spacer()
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                        .id(item.id)
                    case .session(let session):
                        DailySessionLifecycleRow(
                            session: session,
                            isAttended: attendedSessionIds.contains(session.id),
                            onToggle: { Task { await toggleAttendance(for: session) } },
                            onTap: { selectedSession = session },
                            userId: appState.currentUser?.id ?? UUID()
                        )
                        .id(item.id)
                    case .supplement(let supplement):
                        DailySupplementRowView(
                            supplement: supplement,
                            isTaken: isSupplementTakenToday(supplement),
                            onToggle: {
                                Task {
                                    if let userId = appState.currentUser?.id {
                                        if isSupplementTakenToday(supplement) {
                                            await supplementVM.unlogSupplement(supplement, date: selectedDate, userId: userId)
                                        } else {
                                            await supplementVM.logSupplement(supplement, date: selectedDate, userId: userId)
                                        }
                                    }
                                }
                            },
                            onTap: { selectedSupplement = supplement }
                        )
                        .id(item.id)
                    }
                }
                if completedItemCount > 0 {
                    Button {
                        withAnimation { showCompleted.toggle() }
                    } label: {
                        Text(showCompleted ? "Hide Completed (\(completedItemCount))" : "Show Completed (\(completedItemCount))")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                }
            }
            AppleHealthCard()
                .padding(.horizontal, -16)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 100)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                GeometryReader { geo in
                    Image(themeManager.currentBackgroundImage)
                        .resizable()
                        .scaledToFill()
                        .grayscale(1.0)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .ignoresSafeArea()

                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0.67),
                            Color.black.opacity(0.37),
                            Color.clear
                        ]),
                        startPoint: .top,
                        endPoint: .center
                    )
                    .ignoresSafeArea()
                }

                VStack(spacing: 0) {
                    HStack {
                        Text("Daily Actions")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        if viewModel.consistencyStreak > 0 {
                            Text("🔥 \(viewModel.consistencyStreak)")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color(red: 0.08, green: 0.35, blue: 0.45).opacity(0.85))
                                .cornerRadius(12)
                        }
                        Spacer()
                        HStack(spacing: 16) {
                            Button { showNotifications = true } label: {
                                Image(systemName: "bell")
                                    .foregroundColor(.white)
                            }
                            Button { showProfile = true } label: {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 26))
                                    .foregroundColor(.white)
                            }
                            Menu {
                                Button {
                                    showingAddHabit = true
                                } label: {
                                    Label("Add Habit", systemImage: "plus.circle.fill")
                                }
                                Button {
                                    showCreateChallenge = true
                                } label: {
                                    Label("Challenge", systemImage: "trophy.fill")
                                }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 60)
                    .padding(.bottom, 12)

                    dateBrowser
                        .padding(.bottom, 8)

                    priorityCard
                        .padding(.bottom, 8)

                    ScrollViewReader { proxy in
                        ScrollView {
                            listContent
                        }
                        .onChange(of: scrollToItemId) { _, id in
                            if let id {
                                withAnimation { proxy.scrollTo(id, anchor: .top) }
                                scrollToItemId = nil
                            }
                        }
                    }
                }
            }
            .ignoresSafeArea()
            .overlay {
                if showCelebration {
                    celebrationOverlay
                }
            }
            .overlay {
                challengeInviteOverlay
            }
            .onChange(of: completedItemCount) { _, newValue in
                let total = allSortedItems.count
                if newValue > 0 && total > 0 && newValue == total {
                    withAnimation { showCelebration = true }
                }
                progressVM.updateDailySummary(completed: newValue, total: total)
            }
            .onChange(of: allSortedItems.count) { _, _ in
                let total = allSortedItems.count
                let done = completedItemCount
                if done > 0 && total > 0 && done == total && !showCelebration {
                    withAnimation { showCelebration = true }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddHabit) { AddHabitView(viewModel: viewModel) }
            .sheet(isPresented: $showNotifications) { NotificationsView() }
            .sheet(isPresented: $showProfile) { ProfileView() }
            .sheet(isPresented: $showCreateChallenge) { challengeSheet }
            .sheet(item: $selectedSupplement) { supplement in
                NavigationView {
                    SupplementDetailView(supplement: supplement, viewModel: supplementVM)
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { selectedHabitId != nil },
                set: { if !$0 { selectedHabitId = nil } }
            )) {
                if let habitId = selectedHabitId,
                   let habit = viewModel.habits.first(where: { $0.id == habitId }) {
                    HabitDetailView(habit: habit, viewModel: viewModel)
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { selectedSession != nil },
                set: { if !$0 { selectedSession = nil } }
            )) {
                if let session = selectedSession {
                    if let gid = session.groupId, let group = groupsById[gid] {
                        SessionDetailView(session: session, group: group)
                    } else {
                        ProgressView("Loading session...")
                            .foregroundColor(.white)
                            .task {
                                let groups: [AppGroup] = (try? await supabase.from("groups").select().execute().value) ?? []
                                groupsById = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0) })
                            }
                    }
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { selectedChallenge != nil },
                set: { if !$0 { selectedChallenge = nil } }
            )) {
                if let challenge = selectedChallenge, let user = appState.currentUser {
                    ChallengeDetailView(challenge: challenge, currentUserId: user.id, viewModel: challengeVM)
                }
            }
            .onChange(of: selectedDate) {
                showCompleted = false
                showCelebration = false
                Task { await loadAttendance() }
            }
            .onAppear {
                Task { await sessionVM.fetchAllSessions() }
            }
            .task {
                // Bug 4: parallelise the 10-call serial fetch chain.
                // Independent fetches kick off concurrently via async let; only
                // loadAttendance stays after the await-all since it reads from
                // sessionVM.sessions which must be populated first.
                guard let user = appState.currentUser else { return }
                let userId = user.id
                let userIdString = userId.uuidString

                async let habits: Void = viewModel.fetchHabits()
                async let logs: Void = viewModel.fetchLogs(for: userId)
                async let freezes: Void = viewModel.fetchFreezes(userId: userId)
                async let supplements: Void = supplementVM.fetchSupplements(userId: userId)
                async let suppLogs: Void = supplementVM.fetchSupplementLogs(userId: userId)
                async let friends: Void = friendsVM.fetchFriends(userId: userIdString)
                async let sessions: Void = sessionVM.fetchAllSessions()
                async let myChallenges: Void = challengeVM.fetchMyChallenges(userId: userId)
                async let acceptedChallenges: Void = challengeVM.fetchAcceptedChallenges(userId: userId)
                async let pendingInvite: Void = challengeVM.fetchLatestPendingInvite(userId: userId)
                async let groupsResult: [AppGroup] = (try? await supabase.from("groups").select().execute().value) ?? []

                _ = await habits
                _ = await logs
                _ = await freezes
                _ = await supplements
                _ = await suppLogs
                _ = await friends
                _ = await sessions
                _ = await myChallenges
                _ = await acceptedChallenges
                _ = await pendingInvite
                let groups = await groupsResult

                groupsById = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0) })
                groupIds = groups.map { $0.id }
                await loadAttendance()
                progressVM.updateDailySummary(completed: completedItemCount, total: allSortedItems.count)
                if challengeVM.incomingChallenge != nil {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        showChallengeInvite = true
                    }
                }
            }
        }
        .onAppear {
            AnalyticsManager.shared.screen("Home")
        }
    }

    // MARK: - Date Browser

    var dateBrowser: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                } label: {
                    Image(systemName: "chevron.left").foregroundColor(.white)
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(isToday(selectedDate) ? "Today" : isYesterday(selectedDate) ? "Yesterday" : dayLabel(selectedDate))
                        .font(.headline).foregroundColor(.white)
                    Text(dateLabel(selectedDate))
                        .font(.caption).foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                Button {
                    selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                } label: {
                    Image(systemName: "chevron.right").foregroundColor(.white)
                }
            }
            .padding(.horizontal)

            HStack(spacing: 6) {
                ForEach(-3..<4, id: \.self) { offset in
                    let date = calendar.date(byAdding: .day, value: offset, to: selectedDate) ?? Date()
                    let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                    Button {
                        selectedDate = date
                    } label: {
                        VStack(spacing: 4) {
                            Text(shortWeekday(date))
                                .font(.caption2)
                                .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                            Text(dayNumber(date))
                                .font(.caption)
                                .fontWeight(isSelected ? .bold : .regular)
                                .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                        }
                        .frame(width: 38, height: 44)
                        .background(isSelected ? themeManager.currentTheme.primary : Color.white.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    func isToday(_ date: Date) -> Bool { calendar.isDateInToday(date) }
    func isYesterday(_ date: Date) -> Bool { calendar.isDateInYesterday(date) }
    func dayLabel(_ date: Date) -> String { let f = DateFormatter(); f.dateFormat = "EEEE"; return f.string(from: date) }
    func dateLabel(_ date: Date) -> String { let f = DateFormatter(); f.dateFormat = "d MMM yyyy"; return f.string(from: date) }
    func shortWeekday(_ date: Date) -> String { let f = DateFormatter(); f.dateFormat = "EEE"; return f.string(from: date) }
    func dayNumber(_ date: Date) -> String { let f = DateFormatter(); f.dateFormat = "d"; return f.string(from: date) }
}

// MARK: - Celebration Overlay View (poker-machine win)

private struct CelebrationOverlayView: View {
    @Binding var show: Bool
    let completedCount: Int
    let totalCount: Int
    let streakDays: Int

    @State private var flashOpacity: Double = 1.0
    @State private var ringsActive: Bool = false
    @State private var badgeScale: CGFloat = 0.2
    @State private var textScale: CGFloat = 0.85
    @State private var textOffsetY: CGFloat = 30
    @State private var textOpacity: Double = 0
    @State private var cornerGlowOpacity: Double = 0

    private let gold = Color(red: 1.0, green: 0.84, blue: 0.0)
    private let green = Color(red: 0.2, green: 0.85, blue: 0.45)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 1. Black backdrop (tap to dismiss)
                Color.black.opacity(0.85)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { dismiss() }

                // 2. Four corner radial glow pulses (green → gold → clear)
                ForEach(0..<4, id: \.self) { i in
                    RadialGradient(
                        colors: [green.opacity(0.5), gold.opacity(0.3), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                    .frame(width: 400, height: 400)
                    .position(cornerPosition(i, in: geo.size))
                    .opacity(cornerGlowOpacity)
                    .allowsHitTesting(false)
                }

                // 3. Three concentric gold rings bursting outward
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(gold, lineWidth: 3)
                        .frame(width: 100, height: 100)
                        .scaleEffect(ringsActive ? 2.5 : 0)
                        .opacity(ringsActive ? 0 : 1)
                        .animation(
                            .easeOut(duration: 0.8).delay(0.1 + Double(i) * 0.08),
                            value: ringsActive
                        )
                        .allowsHitTesting(false)
                }

                // 4. Wave 1 — 25 coin/chip particles bursting from centre
                ForEach(0..<25, id: \.self) { i in
                    PokerParticle(kind: .burst, seed: i, screen: geo.size)
                }

                // 5. Wave 2 — 25 coin/chip particles raining from top
                ForEach(0..<25, id: \.self) { i in
                    PokerParticle(kind: .rain, seed: i + 25, screen: geo.size)
                }

                // 6. Central badge + text
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(gold)
                            .frame(width: 140, height: 140)
                            .shadow(color: gold.opacity(0.6), radius: 30)

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 80, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .scaleEffect(badgeScale)

                    VStack(spacing: 10) {
                        Text("DAY COMPLETE")
                            .font(.system(size: 36, weight: .heavy))
                            .foregroundStyle(.white)
                            .tracking(2)
                            .scaleEffect(textScale)
                            .offset(y: textOffsetY)

                        Text("\(completedCount) of \(totalCount) done")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.6))

                        if streakDays > 0 {
                            Text("🔥 \(streakDays) day streak")
                                .font(.headline)
                                .foregroundStyle(.orange)
                        }
                    }
                    .opacity(textOpacity)
                }
                .allowsHitTesting(false)

                // 7. White screen flash (on top, fades 1 → 0)
                Color.white
                    .opacity(flashOpacity)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .onAppear { runAnimations() }
    }

    private func cornerPosition(_ index: Int, in size: CGSize) -> CGPoint {
        switch index {
        case 0: return CGPoint(x: 0, y: 0)
        case 1: return CGPoint(x: size.width, y: 0)
        case 2: return CGPoint(x: 0, y: size.height)
        default: return CGPoint(x: size.width, y: size.height)
        }
    }

    private func runAnimations() {
        // White flash 1.0 → 0 over 0.25s
        withAnimation(.easeOut(duration: 0.25)) { flashOpacity = 0 }

        // Rings burst (staggered via per-ring .animation modifier)
        ringsActive = true

        // Badge slam (0.2 → overshoot → 1.0). Low damping for the slam feel.
        withAnimation(.spring(response: 0.4, dampingFraction: 0.45).delay(0.05)) {
            badgeScale = 1.0
        }

        // Text slide-up + scale bounce (0.85 → overshoot → 1.0)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.55).delay(0.22)) {
            textScale = 1.0
            textOffsetY = 0
            textOpacity = 1
        }

        // Corner glow pulse 0 → 0.35 → 0 over 0.8s starting at 0.2s
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeInOut(duration: 0.4)) { cornerGlowOpacity = 0.35 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeInOut(duration: 0.4)) { cornerGlowOpacity = 0 }
        }

        // Auto-dismiss after 4s
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { dismiss() }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.3)) { show = false }
    }
}

// MARK: - Poker Particle

private enum PokerParticleKind { case burst, rain }

private struct PokerParticle: View {
    let kind: PokerParticleKind
    let seed: Int
    let screen: CGSize

    @State private var active = false

    private let startOffset: CGSize
    private let endOffset: CGSize
    private let rotation: Double
    private let duration: Double
    private let delay: Double
    private let colour: Color
    private let size: CGFloat
    private let isCircle: Bool

    init(kind: PokerParticleKind, seed: Int, screen: CGSize) {
        self.kind = kind
        self.seed = seed
        self.screen = screen

        var rng = SeededRNG(seed: UInt64(seed &+ 1) &* 2654435761)

        let colours: [Color] = [
            Color(red: 1.0, green: 0.84, blue: 0.0),
            Color(red: 0.2, green: 0.85, blue: 0.45),
            Color.white.opacity(0.6)
        ]
        self.colour = colours[Int.random(in: 0..<3, using: &rng)]
        self.size = CGFloat.random(in: 6...14, using: &rng)
        self.isCircle = Double.random(in: 0...1, using: &rng) < 0.6
        self.rotation = Double.random(in: 180...540, using: &rng)

        switch kind {
        case .burst:
            let angle = Double.random(in: 0...(2 * .pi), using: &rng)
            let distance = Double.random(in: 80...180, using: &rng)
            self.startOffset = .zero
            self.endOffset = CGSize(
                width: CGFloat(cos(angle) * distance),
                height: CGFloat(sin(angle) * distance)
            )
            self.duration = 0.6
            self.delay = 0

        case .rain:
            let halfW = Double(screen.width) / 2
            let halfH = Double(screen.height) / 2
            let startX = Double.random(in: -halfW...halfW, using: &rng)
            let fall = Double.random(in: 300...500, using: &rng)
            self.startOffset = CGSize(width: CGFloat(startX), height: CGFloat(-halfH))
            self.endOffset = CGSize(width: CGFloat(startX), height: CGFloat(-halfH + fall))
            self.duration = Double.random(in: 0.8...1.2, using: &rng)
            self.delay = 0.3
        }
    }

    var body: some View {
        shapeView
            .frame(width: size, height: size)
            .offset(active ? endOffset : startOffset)
            .rotationEffect(.degrees(active ? rotation : 0))
            .opacity(active ? 0 : 1)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeOut(duration: duration).delay(delay)) {
                    active = true
                }
            }
    }

    @ViewBuilder
    private var shapeView: some View {
        if isCircle {
            Circle().fill(colour)
        } else {
            RoundedRectangle(cornerRadius: 3).fill(colour)
        }
    }
}

// MARK: - Seeded RNG (stable randomness per particle index)

private struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0xdeadbeef : seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

// MARK: - Challenge Row

struct ChallengeRowView: View {
    let challenge: Challenge

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "trophy.fill")
                .font(.title2)
                .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(challenge.title)
                    .font(.body)
                    .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                HStack(spacing: 4) {
                    Text("Goal: \(Int(challenge.goalTarget)) \(challenge.goalUnit ?? "") \(challenge.frequency ?? "")")
                        .font(.caption2)
                        .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.7))
                    if let end = challenge.endDate {
                        Text("· Ends \(end.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.6),
                    lineWidth: 2
                )
        )
    }
}

// MARK: - Daily Item Enum

enum DailyItem: Identifiable {
    case habit(Habit)
    case session(AppSession)
    case supplement(Supplement)

    var id: String {
        switch self {
        case .habit(let h): return "habit-\(h.id)"
        case .session(let s): return "session-\(s.id)"
        case .supplement(let sup): return "supplement-\(sup.id)"
        }
    }

    var sortTime: Date? {
        switch self {
        case .habit: return nil
        case .session(let s): return s.proposedAt
        case .supplement: return nil
        }
    }

    var habit: Habit? {
        if case .habit(let h) = self { return h }
        return nil
    }
}

// MARK: - Supplement Row

struct DailySupplementRowView: View {
    let supplement: Supplement
    let isTaken: Bool
    let onToggle: () -> Void
    let onTap: () -> Void
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 14) {
            Button {
                UIImpactFeedbackGenerator(style: isTaken ? .light : .medium).impactOccurred()
                onToggle()
            } label: {
                Image(systemName: isTaken ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isTaken ? .green : .white.opacity(0.6))
                    .font(.title2)
            }
            Button { onTap() } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(supplement.name)
                            .font(.body).foregroundColor(isTaken ? .green : .white)
                        HStack(spacing: 4) {
                            Text(SupplementTiming(rawValue: supplement.timing)?.label ?? "")
                                .font(.caption2).foregroundColor(isTaken ? .green.opacity(0.7) : .white.opacity(0.6))
                            Text(supplement.dose ?? "")
                                .font(.caption).foregroundColor(.white.opacity(0.6))
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption).foregroundColor(.white.opacity(0.5))
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isTaken ? Color.green.opacity(0.7) : themeManager.currentTheme.primary.opacity(0.5),
                    lineWidth: 2
                )
        )
    }
}

// MARK: - Session Row

struct DailySessionLifecycleRow: View {
    let session: AppSession
    let isAttended: Bool
    let onToggle: () -> Void
    let onTap: () -> Void
    let userId: UUID
    @State private var rsvpVM = RSVPViewModel()
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        Button(action: onTap) {
            SessionLifecycleCard(
                session: session,
                rsvpStatus: rsvpVM.myRSVP?.status,
                attended: isAttended,
                onTap: {},
                showToggle: true,
                onToggle: {
                    UIImpactFeedbackGenerator(style: isAttended ? .light : .medium).impactOccurred()
                    onToggle()
                }
            )
        }
        .buttonStyle(.plain)
        .task {
            await rsvpVM.fetchRSVPs(sessionId: session.id, userId: userId)
        }
    }
}

// MARK: - Habit Row

struct HabitRowView: View {
    let habit: Habit
    let date: Date
    let userId: UUID
    @ObservedObject var viewModel: HabitViewModel
    @EnvironmentObject var themeManager: ThemeManager
    var onNavigate: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 14) {
            if let target = habit.targetCount, target > 1 {
                HStack(spacing: 8) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        Task { await viewModel.decrementHabit(habit, on: date, userId: userId) }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.white.opacity(0.6)).font(.title3)
                    }
                    Text("\(viewModel.progressFor(habit, on: date, userId: userId))/\(target)")
                        .font(.subheadline).monospacedDigit().foregroundColor(.white).frame(minWidth: 36)
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        Task { await viewModel.incrementHabit(habit, on: date, userId: userId) }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(themeManager.currentTheme.primary).font(.title3)
                    }
                }
            } else {
                Button {
                    let completing = !viewModel.isCompleted(habit, on: date, userId: userId)
                    UIImpactFeedbackGenerator(style: completing ? .medium : .light).impactOccurred()
                    Task { await viewModel.toggleHabit(habit, on: date, userId: userId) }
                } label: {
                    Image(systemName: viewModel.isCompleted(habit, on: date, userId: userId) ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(viewModel.isCompleted(habit, on: date, userId: userId) ? .green : .white.opacity(0.6))
                        .font(.title2)
                }
            }
            Button {
                onNavigate?()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(habit.name).font(.body).foregroundColor(viewModel.isCompleted(habit, on: date, userId: userId) ? .green : .white)
                        if habit.groupId != nil {
                            Text("Group habit").font(.caption2).foregroundColor(.white.opacity(0.5))
                        }
                    }
                    Spacer()
                    let streak = viewModel.currentStreak(for: habit, userId: userId)
                    if streak > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill").foregroundColor(.orange).font(.caption)
                            Text("\(streak)").font(.caption).foregroundColor(.orange)
                        }
                    }
                    Image(systemName: "chevron.right").font(.caption).foregroundColor(.white.opacity(0.5))
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    viewModel.isCompleted(habit, on: date, userId: userId) ? Color.green.opacity(0.7) : themeManager.currentTheme.primary.opacity(0.5),
                    lineWidth: 2
                )
        )
    }
}
