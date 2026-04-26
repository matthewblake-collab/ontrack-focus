import SwiftUI

struct CoachDashboardView: View {
    let group: AppGroup
    let memberProfiles: [(id: UUID, name: String)]

    @State private var vm = CoachWellnessViewModel()
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // MARK: - Header
                VStack(spacing: 4) {
                    Text("Team Wellness")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Last 7 days")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top)

                if vm.isLoadingData {
                    ProgressView("Loading team data...")
                        .padding(.top, 40)

                } else if let error = vm.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .padding()

                } else if vm.members.isEmpty {
                    Text("No member data available.")
                        .foregroundStyle(.secondary)
                        .padding(.top, 40)

                } else {

                    // MARK: - Member Cards
                    ForEach(vm.members) { member in
                        MemberWellnessCard(member: member)
                    }

                    // MARK: - AI Team Summary
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.purple)
                            Text("AI Team Summary")
                                .font(.headline)
                            Spacer()
                        }

                        if vm.isLoadingInsight {
                            HStack {
                                ProgressView()
                                Text("Generating summary...")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        } else if !vm.teamInsight.isEmpty {
                            Text(vm.teamInsight)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)

                            Button(action: { vm.generateTeamInsight() }) {
                                Label("Refresh", systemImage: "arrow.clockwise")
                                    .font(.caption)
                                    .foregroundStyle(.purple)
                            }
                        } else {
                            Button(action: { vm.generateTeamInsight() }) {
                                Label("Generate Team Summary", systemImage: "sparkles")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.purple)
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                }

                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Coach Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.load(groupId: group.id, memberProfiles: memberProfiles)
        }
    }
}

// MARK: - Member Wellness Card
struct MemberWellnessCard: View {
    let member: MemberWellnessSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .foregroundStyle(.secondary)
                Text(member.name)
                    .font(.headline)
                Spacer()
                if member.checkInCount == 0 {
                    Text("No check-ins")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(member.checkInCount) check-ins")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if member.checkInCount > 0 {
                HStack(spacing: 16) {
                    WellnessStatPill(label: "Sleep", value: member.avgSleep, color: .blue)
                    WellnessStatPill(label: "Energy", value: member.avgEnergy, color: .orange)
                    WellnessStatPill(label: "Mood", value: member.avgWellbeing, color: .green)
                }
            }

            HStack(spacing: 16) {
                Label("\(member.habitCompletions) habits", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let att = member.attendanceRate {
                    Label(String(format: "%.0f%% attendance", att * 100), systemImage: "calendar.badge.checkmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

// MARK: - Stat Pill
struct WellnessStatPill: View {
    let label: String
    let value: Double?
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value.map { String(format: "%.1f", $0) } ?? "--")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}
