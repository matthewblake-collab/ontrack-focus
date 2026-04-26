import SwiftUI
import Charts
import Supabase

struct MentalHealthView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appState: AppState
    @State private var showCheckIn = false
    @State private var checkInVM = DailyCheckInViewModel()
    @State private var showTrends = false
    @State private var showProfile = false
    @State private var showNotifications = false
    @State private var showProgress = false
    @State private var showBreathwork = false
    @State private var showCycleTracker = false

    @State private var days: Int = {
        let v = UserDefaults.standard.integer(forKey: "wellbeing_chart_days")
        return v == 0 ? 30 : v
    }()
    @State private var cardOrder: [String] = {
        (UserDefaults.standard.array(forKey: "wellbeing_chart_order") as? [String])
            ?? ["wellbeing", "sessions", "habits", "supplements"]
    }()
    @State private var progressVM = ProgressViewModel()

    private var isCycleTrackerEnabled: Bool {
        UserDefaults.standard.bool(forKey: "cycle_tracker_enabled")
    }

    // For future AI prompt enhancement
    @State private var sessionData: [(date: Date, count: Int)] = []
    @State private var habitPct: Double = 0
    @State private var supplementPct: Double = 0

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
                            Color.black.opacity(0.84),
                            Color.black.opacity(0.67)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                }

                ScrollView {
                    VStack(spacing: 16) {
                        // Header
                        HStack {
                            Text("Wellbeing")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                            Spacer()
                            HStack(spacing: 8) {
                                Button { showNotifications = true } label: {
                                    Image(systemName: "bell")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.white)
                                }
                                Button { showProfile = true } label: {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 26))
                                        .foregroundStyle(.white)
                                }
                            }
                        }

                        // 1. Daily check-in card
                        checkInCard

                        // 1b. Breathwork card
                        breathworkCard

                        // 1c. Cycle Tracker card (opt-in only)
                        if isCycleTrackerEnabled {
                            cycleTrackerCard
                        }

                        // 2. Timeframe toggle + card carousel
                        timeframeToggle
                        cardCarousel

                        // 3. View Trends button
                        Button {
                            showTrends = true
                        } label: {
                            HStack {
                                Image(systemName: "chart.xyaxis.line")
                                    .font(.subheadline)
                                Text("View Wellbeing Trends")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                            .foregroundStyle(.white)
                            .padding(14)
                            .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)

                        // 4. AI Insight card
                        if let userId = appState.currentUser?.id.uuidString {
                            // TODO: pass sessionData.reduce(0) { $0 + $1.count }, habitPct, supplementPct to AI prompt (Step 4)
                            AIInsightCard(userId: userId)
                        }
                    }
                    .padding(16)
                    .padding(.top, 8)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showCheckIn) {
                DailyCheckInView(vm: checkInVM)
            }
            .navigationDestination(isPresented: $showTrends) {
                CheckInInsightsView()
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
            }
            .sheet(isPresented: $showNotifications) {
                NotificationsView()
            }
            .sheet(isPresented: $showProgress) {
                if let userId = appState.currentUser?.id {
                    PersonalProgressSheet(progressVM: progressVM, userId: userId)
                }
            }
            .sheet(isPresented: $showBreathwork) {
                if let userId = appState.currentUser?.id.uuidString {
                    BreathworkCoachView(userId: userId)
                }
            }
            .sheet(isPresented: $showCycleTracker) {
                if let userId = appState.currentUser?.id.uuidString {
                    CycleTrackerView(userId: userId)
                }
            }
            .task(id: days) {
                guard let userId = appState.currentUser?.id else { return }
                async let s = progressVM.fetchSessionsCompleted(userId: userId, days: days)
                async let h = progressVM.fetchHabitAdherence(userId: userId, days: days)
                async let su = progressVM.fetchSupplementAdherence(userId: userId, days: days)
                sessionData = await s
                (habitPct, supplementPct) = await (h, su)
            }
            .onChange(of: days) { _, newValue in
                UserDefaults.standard.set(newValue, forKey: "wellbeing_chart_days")
            }
            .onboardingTooltip(
                screen: "mentalhealth",
                title: "Mental Health",
                message: "Check in daily with your sleep, energy and wellbeing. Track trends over time and get AI-powered wellness insights.",
                icon: "brain.head.profile"
            )
        }
        .onAppear {
            AnalyticsManager.shared.screen("MentalHealth")
        }
    }

    // MARK: - Check-in Card

    private var isCheckedInToday: Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        return UserDefaults.standard.string(forKey: "checkin_completed_date") == today
    }

    private var checkInCard: some View {
        HStack(spacing: 12) {
            // --- Daily Check-in card (left side) ---
            Button {
                showCheckIn = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(isCheckedInToday ? Color.green.opacity(0.25) : Color.white.opacity(0.08))
                            .frame(width: 44, height: 44)
                        Image(systemName: isCheckedInToday ? "checkmark.circle.fill" : "heart.text.square")
                            .font(.title2)
                            .foregroundStyle(isCheckedInToday ? .green : .white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Check-in")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                        Text(isCheckedInToday ? "Done today ✓" : "Tap to log")
                            .font(.caption)
                            .foregroundStyle(isCheckedInToday ? .green : .white.opacity(0.6))
                    }
                    Spacer()
                }
                .padding(12)
                .frame(maxWidth: .infinity, minHeight: 72)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(isCheckedInToday ? Color.green.opacity(0.6) : Color.white.opacity(0.12), lineWidth: 1.5)
                        )
                )
            }

            // --- My Progress card (right side) ---
            Button {
                showProgress = true
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.25))
                            .frame(width: 44, height: 44)
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.title2)
                            .foregroundStyle(Color(red: 0.12, green: 0.08, blue: 0.0))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Progress")
                            .font(.subheadline.bold())
                            .foregroundStyle(Color(red: 0.10, green: 0.07, blue: 0.0))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text("My stats")
                            .font(.caption)
                            .foregroundStyle(Color(red: 0.10, green: 0.07, blue: 0.0).opacity(0.7))
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(12)
                .frame(maxWidth: .infinity, minHeight: 72)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.84, blue: 0.0),
                                    Color(red: 0.95, green: 0.70, blue: 0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(red: 1.0, green: 0.90, blue: 0.30).opacity(0.6), lineWidth: 1.5)
                        )
                )
            }
        }
    }

    // MARK: - Breathwork Card

    private var isBreathworkDoneToday: Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        return UserDefaults.standard.string(forKey: "breathwork_completed_date") == today
    }

    private var breathworkCard: some View {
        Button {
            showBreathwork = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isBreathworkDoneToday ? Color.green.opacity(0.25) : Color.white.opacity(0.08))
                        .frame(width: 44, height: 44)
                    Image(systemName: isBreathworkDoneToday ? "checkmark.circle.fill" : "wind")
                        .font(.title2)
                        .foregroundStyle(isBreathworkDoneToday ? .green : .white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Breathwork")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                    Text(isBreathworkDoneToday ? "Done today ✓" : "Tap to begin")
                        .font(.caption)
                        .foregroundStyle(isBreathworkDoneToday ? .green : .white.opacity(0.6))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isBreathworkDoneToday ? Color.green.opacity(0.6) : Color.white.opacity(0.12), lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Cycle Tracker Card

    private var cycleTrackerCard: some View {
        Button {
            showCycleTracker = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 44, height: 44)
                    Image(systemName: "circle.dashed")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cycle Tracker")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                    Text("Track your cycle")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Timeframe Toggle

    private var timeframeToggle: some View {
        HStack(spacing: 0) {
            ForEach([7, 30], id: \.self) { option in
                Button {
                    days = option
                } label: {
                    Text("\(option) Days")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(days == option ? .black : .white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(days == option ? Color.green : Color.clear)
                        )
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
        )
    }

    // MARK: - Card Carousel

    private var cardCarousel: some View {
        let userId = appState.currentUser?.id
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(cardOrder, id: \.self) { cardId in
                    cardContent(cardId: cardId, userId: userId)
                        .frame(width: 320, height: 260)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                        )
                        .draggable(cardId)
                        .dropDestination(for: String.self) { droppedItems, _ in
                            guard let source = droppedItems.first,
                                  source != cardId,
                                  let fromIndex = cardOrder.firstIndex(of: source),
                                  let toIndex = cardOrder.firstIndex(of: cardId) else { return false }
                            withAnimation {
                                cardOrder.move(
                                    fromOffsets: IndexSet(integer: fromIndex),
                                    toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
                                )
                            }
                            UserDefaults.standard.set(cardOrder, forKey: "wellbeing_chart_order")
                            return true
                        }
                }
            }
            .padding(.horizontal, 16)
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
    }

    @ViewBuilder
    private func cardContent(cardId: String, userId: UUID?) -> some View {
        switch cardId {
        case "wellbeing":
            WellbeingTrendCard(userId: userId, days: days)
        case "sessions":
            SessionsTrendCard(sessionData: sessionData)
        case "habits":
            HabitsTrendCard(userId: userId, days: days, progressVM: progressVM)
        case "supplements":
            SupplementsTrendCard(userId: userId, days: days, progressVM: progressVM)
        default:
            EmptyView()
        }
    }
}

// MARK: - Wellbeing Trend Card

private struct WellbeingTrendCard: View {
    let userId: UUID?
    let days: Int

    private struct WellbeingRecord: Decodable, Identifiable {
        let id: UUID
        let checkinDate: String
        let sleep: Int
        let energy: Int
        let wellbeing: Int
        let mood: Int?
        let stress: Int?
        enum CodingKeys: String, CodingKey {
            case id
            case checkinDate = "checkin_date"
            case sleep, energy, wellbeing, mood, stress
        }
        var date: Date {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            return f.date(from: checkinDate) ?? Date.distantPast
        }
    }

    @State private var records: [WellbeingRecord] = []
    @State private var isLoading = false
    @State private var selectedMetric: String = "Sleep"

    private func metricValue(for record: WellbeingRecord) -> Int {
        switch selectedMetric {
        case "Sleep": return record.sleep
        case "Energy": return record.energy
        case "Wellbeing": return record.wellbeing
        case "Mood": return record.mood ?? 0
        case "Stress": return record.stress ?? 0
        default: return record.wellbeing
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Sleep · Energy · Wellbeing · Mood · Stress")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(["Sleep", "Energy", "Wellbeing", "Mood", "Stress"], id: \.self) { label in
                        Button {
                            selectedMetric = label
                        } label: {
                            Text(label)
                                .font(.subheadline)
                                .fontWeight(selectedMetric == label ? .semibold : .regular)
                                .foregroundColor(selectedMetric == label ? .white : .white.opacity(0.6))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    selectedMetric == label
                                        ? Color(red: 0.08, green: 0.45, blue: 0.25)
                                        : Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92)
                                )
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 8)

            if isLoading {
                ProgressView()
                    .tint(.green)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if records.isEmpty {
                Text("No check-ins yet")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Chart {
                    ForEach(records) { record in
                        LineMark(
                            x: .value("Date", record.date, unit: .day),
                            y: .value(selectedMetric, metricValue(for: record))
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color.green)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        AreaMark(
                            x: .value("Date", record.date, unit: .day),
                            y: .value(selectedMetric, metricValue(for: record))
                        )
                        .foregroundStyle(Color.green.opacity(0.15))

                        PointMark(
                            x: .value("Date", record.date, unit: .day),
                            y: .value(selectedMetric, metricValue(for: record))
                        )
                        .foregroundStyle(Color.green)
                        .symbolSize(30)
                    }
                }
                .chartYScale(domain: 0...10)
                .chartYAxis {
                    AxisMarks(values: [0, 5, 10]) {
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.15))
                        AxisValueLabel().foregroundStyle(.white)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: days > 14 ? 7 : 2)) {
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.15))
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .foregroundStyle(.white)
                    }
                }
                .chartPlotStyle { plotArea in
                    plotArea.background(Color.clear)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
        }
        .task(id: days) {
            guard let userId else { return }
            await fetchData(userId: userId)
        }
    }

    private func fetchData(userId: UUID) async {
        isLoading = true
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let cutoff = formatter.string(
            from: Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        )
        do {
            let rows: [WellbeingRecord] = try await supabase
                .from("daily_checkins")
                .select()
                .eq("user_id", value: userId.uuidString)
                .gte("checkin_date", value: cutoff)
                .order("checkin_date", ascending: true)
                .execute()
                .value
            records = rows
        } catch {
            print("[WellbeingTrendCard] Fetch failed: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Sessions Trend Card

private struct SessionsTrendCard: View {
    let sessionData: [(date: Date, count: Int)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Sessions Completed")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            if sessionData.isEmpty {
                Text("No sessions yet")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let maxCount = max(sessionData.map(\.count).max() ?? 0, 3)
                Chart {
                    ForEach(sessionData, id: \.date) { entry in
                        LineMark(
                            x: .value("Date", entry.date, unit: .day),
                            y: .value("Sessions", entry.count)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color.green)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        AreaMark(
                            x: .value("Date", entry.date, unit: .day),
                            y: .value("Sessions", entry.count)
                        )
                        .foregroundStyle(Color.green.opacity(0.15))

                        PointMark(
                            x: .value("Date", entry.date, unit: .day),
                            y: .value("Sessions", entry.count)
                        )
                        .foregroundStyle(Color.green)
                        .symbolSize(30)
                    }
                }
                .chartYScale(domain: 0...maxCount)
                .chartYAxis {
                    AxisMarks {
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.15))
                        AxisValueLabel().foregroundStyle(.white)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: sessionData.count > 14 ? 7 : 2)) {
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.15))
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .foregroundStyle(.white)
                    }
                }
                .chartPlotStyle { plotArea in
                    plotArea.background(Color.clear)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
        }
    }
}

// MARK: - Habits Trend Card

private struct HabitsTrendCard: View {
    let userId: UUID?
    let days: Int
    let progressVM: ProgressViewModel

    @State private var pct: Double = 0
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Habit Adherence")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.top, 16)

            Spacer()

            if isLoading {
                ProgressView()
                    .tint(.green)
                    .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 16)
                        Circle()
                            .trim(from: 0, to: pct)
                            .stroke(Color.green, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut, value: pct)
                        Text("\(Int(pct * 100))%")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .frame(width: 120, height: 120)
                    Text("of days completed")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
            }

            Spacer()
        }
        .task(id: days) {
            guard let userId else { return }
            isLoading = true
            pct = await progressVM.fetchHabitAdherence(userId: userId, days: days)
            isLoading = false
        }
    }
}

// MARK: - Supplements Trend Card

private struct SupplementsTrendCard: View {
    let userId: UUID?
    let days: Int
    let progressVM: ProgressViewModel

    @State private var pct: Double = 0
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Supplement Adherence")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.top, 16)

            Spacer()

            if isLoading {
                ProgressView()
                    .tint(.green)
                    .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 16)
                        Circle()
                            .trim(from: 0, to: pct)
                            .stroke(Color.green, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut, value: pct)
                        Text("\(Int(pct * 100))%")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .frame(width: 120, height: 120)
                    Text("of days completed")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
            }

            Spacer()
        }
        .task(id: days) {
            guard let userId else { return }
            isLoading = true
            pct = await progressVM.fetchSupplementAdherence(userId: userId, days: days)
            isLoading = false
        }
    }
}
