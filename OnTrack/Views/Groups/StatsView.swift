import SwiftUI

struct StatsView: View {
    let group: AppGroup
    @State private var viewModel = StatsViewModel()
    @State private var selectedMember: MemberStats? = nil
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        List {
            if viewModel.isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
                .listRowBackground(themeManager.cardColour())
            } else if viewModel.memberStats.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 50))
                            .foregroundStyle(.secondary)
                        Text("No stats yet")
                            .font(.headline)
                        Text("Stats appear once sessions are marked as completed")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .listRowBackground(themeManager.cardColour())
            } else {
                Section("Leaderboard") {
                    ForEach(Array(viewModel.memberStats.enumerated()), id: \.element.id) { index, member in
                        Button {
                            selectedMember = member
                        } label: {
                            HStack(spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(member.displayName)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.primary)
                                    Text("\(member.attended)/\(member.totalSessions) sessions")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(member.attendanceRateText)
                                        .font(.headline)
                                        .foregroundStyle(attendanceColor(rate: member.attendanceRate))
                                    if member.currentStreak > 0 {
                                        HStack(spacing: 2) {
                                            Image(systemName: "flame.fill")
                                                .font(.caption2)
                                                .foregroundStyle(.orange)
                                            Text("\(member.currentStreak)")
                                                .font(.caption)
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listRowBackground(themeManager.cardColour())
            }
        }
        .themedList(themeManager)
        .navigationTitle("Stats")
        .task {
            await viewModel.fetchStats(groupId: group.id)
        }
        .sheet(item: $selectedMember) { member in
            MemberStatsDetailView(member: member)
        }
    }

    func attendanceColor(rate: Double) -> Color {
        if rate >= 0.8 { return .green }
        if rate >= 0.5 { return .orange }
        return .red
    }
}

struct MemberStatsDetailView: View {
    let member: MemberStats
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(red: 0.08, green: 0.35, blue: 0.45),
                                             Color(red: 0.15, green: 0.55, blue: 0.38)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text(member.displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .listRowBackground(themeManager.cardColour())

                Section("Attendance") {
                    StatRow(label: "Sessions Attended", value: "\(member.attended) / \(member.totalSessions)")
                    StatRow(label: "Attendance Rate", value: member.attendanceRateText, valueColor: attendanceColor(rate: member.attendanceRate))
                }
                .listRowBackground(themeManager.cardColour())

                Section("Streaks") {
                    StatRow(label: "Current Streak", value: "\(member.currentStreak) 🔥", valueColor: member.currentStreak > 0 ? .orange : .secondary)
                    StatRow(label: "Longest Streak", value: "\(member.longestStreak)")
                }
                .listRowBackground(themeManager.cardColour())

                Section("RSVP") {
                    StatRow(label: "RSVP Accuracy", value: member.rsvpAccuracyText, valueColor: member.rsvpGoingCount > 0 ? rsvpColor(rate: member.rsvpAccuracy) : .secondary)
                    StatRow(label: "Times Said Going", value: "\(member.rsvpGoingCount)")
                }
                .listRowBackground(themeManager.cardColour())
            }
            .themedList(themeManager)
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    func attendanceColor(rate: Double) -> Color {
        if rate >= 0.8 { return .green }
        if rate >= 0.5 { return .orange }
        return .red
    }

    func rsvpColor(rate: Double) -> Color {
        if rate >= 0.8 { return .green }
        if rate >= 0.5 { return .orange }
        return .red
    }
}

struct StatRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(valueColor)
        }
    }
}
