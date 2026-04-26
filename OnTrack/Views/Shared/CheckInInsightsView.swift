import SwiftUI
import Charts
import Supabase

struct CheckInInsightsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager

    @State private var selectedTab = 0
    @State private var checkIns: [CheckInRecord] = []
    @State private var isLoading = false

    struct CheckInRecord: Decodable, Identifiable {
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(["Sleep", "Energy", "Wellbeing", "Mood", "Stress"].indices, id: \.self) { i in
                                let labels = ["Sleep", "Energy", "Wellbeing", "Mood", "Stress"]
                                Button {
                                    selectedTab = i
                                } label: {
                                    Text(labels[i])
                                        .font(.subheadline)
                                        .fontWeight(selectedTab == i ? .semibold : .regular)
                                        .foregroundColor(selectedTab == i ? .white : .white.opacity(0.6))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(
                                            selectedTab == i
                                                ? Color(red: 0.08, green: 0.45, blue: 0.25)
                                                : Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92)
                                        )
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 4)

                    if isLoading {
                        ProgressView()
                            .tint(themeManager.currentTheme.primary)
                            .padding(.top, 60)
                    } else {
                        summaryCard
                        chartCard
                        bestDayCard
                        worstDayCard
                    }
                }
                .padding(.bottom, 24)
            }
            .background(themeManager.backgroundColour())
            .navigationTitle("Wellbeing Trends")
            .task {
                if let userId = appState.currentUser?.id {
                    await fetchCheckIns(userId: userId)
                }
            }
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "star.fill")
                .font(.title2)
                .foregroundStyle(themeManager.currentTheme.gradient)
            VStack(alignment: .leading, spacing: 2) {
                Text(sevenDayAverage)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.currentTheme.gradient)
                Text("7-day avg · \(metricLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(themeManager.cardColour())
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    // MARK: - Chart Card

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(metricLabel)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 14)

            if checkIns.isEmpty {
                Text("No data available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                Chart {
                    ForEach(checkIns) { record in
                        LineMark(
                            x: .value("Date", record.date, unit: .day),
                            y: .value(metricLabel, metricValue(for: record))
                        )
                        .foregroundStyle(Color(red: 0.08, green: 0.35, blue: 0.45))
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", record.date, unit: .day),
                            y: .value(metricLabel, metricValue(for: record))
                        )
                        .foregroundStyle(Color(red: 0.08, green: 0.35, blue: 0.45))
                    }
                }
                .chartYScale(domain: 0...10)
                .chartYAxis {
                    AxisMarks(values: [0, 2, 4, 6, 8, 10]) {
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: checkIns.count > 14 ? 7 : 3)) {
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .frame(height: 220)
                .padding(.horizontal)
                .padding(.bottom, 14)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    // MARK: - Best / Worst Day Cards

    private var bestDayCard: some View {
        statCard(
            title: "Best Day",
            icon: "arrow.up.circle.fill",
            iconColor: .green,
            record: checkIns.max(by: { metricValue(for: $0) < metricValue(for: $1) })
        )
    }

    private var worstDayCard: some View {
        statCard(
            title: "Worst Day",
            icon: "arrow.down.circle.fill",
            iconColor: .orange,
            record: checkIns.min(by: { metricValue(for: $0) < metricValue(for: $1) })
        )
    }

    private func statCard(title: String, icon: String, iconColor: Color, record: CheckInRecord?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(record.map { formattedDate($0.checkinDate) } ?? "No data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let record {
                Text("\(metricValue(for: record))/10")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(themeManager.currentTheme.gradient)
            }
        }
        .padding()
        .background(themeManager.cardColour())
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private var metricLabel: String {
        switch selectedTab {
        case 0: return "Sleep"
        case 1: return "Energy"
        case 2: return "Wellbeing"
        case 3: return "Mood"
        case 4: return "Stress"
        default: return "Wellbeing"
        }
    }

    private func metricValue(for record: CheckInRecord) -> Int {
        switch selectedTab {
        case 0: return record.sleep
        case 1: return record.energy
        case 2: return record.wellbeing
        case 3: return record.mood ?? 0
        case 4: return record.stress ?? 0
        default: return record.wellbeing
        }
    }

    private var sevenDayAverage: String {
        let last7 = checkIns.suffix(7)
        guard !last7.isEmpty else { return "No data" }
        let sum = last7.map { metricValue(for: $0) }.reduce(0, +)
        let avg = Double(sum) / Double(last7.count)
        return String(format: "%.1f", avg)
    }

    private func formattedDate(_ dateString: String) -> String {
        let input = DateFormatter()
        input.dateFormat = "yyyy-MM-dd"
        let output = DateFormatter()
        output.dateFormat = "d MMM yyyy"
        guard let date = input.date(from: dateString) else { return dateString }
        return output.string(from: date)
    }

    // MARK: - Fetch

    private func fetchCheckIns(userId: UUID) async {
        isLoading = true
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let cutoff = formatter.string(from: Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date())

        do {
            let records: [CheckInRecord] = try await supabase
                .from("daily_checkins")
                .select()
                .eq("user_id", value: userId.uuidString.lowercased())
                .gte("checkin_date", value: cutoff)
                .order("checkin_date", ascending: true)
                .execute()
                .value
            checkIns = records
        } catch {
            print("[CheckInInsights] Fetch failed: \(error)")
        }

        isLoading = false
    }
}
