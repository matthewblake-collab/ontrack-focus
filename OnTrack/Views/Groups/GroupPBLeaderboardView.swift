import SwiftUI

struct GroupPBLeaderboardView: View {
    let group: AppGroup
    let memberProfiles: [Profile]

    @State private var progressVM = ProgressViewModel()
    @State private var pbsByUser: [UUID: [PersonalBest]] = [:]
    @State private var isLoading = true

    private struct LeaderRow: Identifiable {
        let id = UUID()
        let eventName: String
        let winnerName: String
        let valueDisplay: String
        let category: String
    }

    private var leaderRows: [LeaderRow] {
        var eventMap: [String: (profile: Profile, pb: PersonalBest)] = [:]
        for profile in memberProfiles {
            guard let pbs = pbsByUser[profile.id] else { continue }
            for pb in pbs {
                let key = pb.eventName.lowercased()
                let isTime = isTimeBased(pb)
                if let existing = eventMap[key] {
                    let existingBetter = isTime
                        ? existing.pb.value < pb.value
                        : existing.pb.value >= pb.value
                    if !existingBetter {
                        eventMap[key] = (profile, pb)
                    }
                } else {
                    eventMap[key] = (profile, pb)
                }
            }
        }
        return eventMap.values
            .sorted { $0.pb.eventName < $1.pb.eventName }
            .map { entry in
                LeaderRow(
                    eventName: entry.pb.eventName,
                    winnerName: entry.profile.displayName,
                    valueDisplay: formatValue(entry.pb),
                    category: entry.pb.category
                )
            }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if isLoading {
                ProgressView()
                    .tint(.green)
            } else if leaderRows.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "trophy")
                        .font(.system(size: 44))
                        .foregroundColor(.green.opacity(0.5))
                    Text("No personal bests recorded yet")
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(leaderRows) { row in
                            HStack(spacing: 12) {
                                Image(systemName: "trophy.fill")
                                    .foregroundColor(.yellow)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.eventName)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text(row.winnerName)
                                        .font(.system(size: 13))
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Text(row.valueDisplay)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                            )
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
        }
        .navigationTitle("PB Leaderboard")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let ids = memberProfiles.map { $0.id }
            pbsByUser = await progressVM.fetchPBsForUsers(userIds: ids)
            isLoading = false
        }
    }

    private func isTimeBased(_ pb: PersonalBest) -> Bool {
        let unit = pb.valueUnit.lowercased()
        return unit.contains("min") || unit.contains("sec") || unit == "s"
    }

    private func formatValue(_ pb: PersonalBest) -> String {
        if let reps = pb.reps {
            return "\(Int(pb.value)) \(pb.valueUnit) × \(reps)"
        }
        let display = pb.value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(pb.value))
            : String(format: "%.1f", pb.value)
        return "\(display) \(pb.valueUnit)"
    }
}
