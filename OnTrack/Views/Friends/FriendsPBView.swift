import SwiftUI

struct FriendsPBView: View {
    @EnvironmentObject var appState: AppState
    let friendsVM: FriendsViewModel

    @State private var progressVM = ProgressViewModel()
    @State private var pbsByUser: [UUID: [PersonalBest]] = [:]
    @State private var friendProfiles: [UUID: String] = [:]
    @State private var isLoading = true
    @State private var showAddPB = false

    private struct LeaderRow: Identifiable {
        let id = UUID()
        let eventName: String
        let winnerName: String
        let valueDisplay: String
    }

    private var leaderRows: [LeaderRow] {
        var eventMap: [String: (userId: UUID, pb: PersonalBest)] = [:]
        for (userId, pbs) in pbsByUser {
            for pb in pbs {
                let key = pb.eventName.lowercased()
                let isTime = isTimeBased(pb)
                if let existing = eventMap[key] {
                    let existingBetter = isTime
                        ? existing.pb.value < pb.value
                        : existing.pb.value >= pb.value
                    if !existingBetter {
                        eventMap[key] = (userId, pb)
                    }
                } else {
                    eventMap[key] = (userId, pb)
                }
            }
        }
        return eventMap.values
            .sorted { $0.pb.eventName < $1.pb.eventName }
            .map { entry in
                LeaderRow(
                    eventName: entry.pb.eventName,
                    winnerName: friendProfiles[entry.userId] ?? "Friend",
                    valueDisplay: formatValue(entry.pb)
                )
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Friends PB Leaderboard")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.leading, 16)
                Spacer()
                Button { showAddPB = true } label: {
                    Label("Log PB", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                        .padding(.trailing, 16)
                }
            }

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView().tint(.green)
                    Spacer()
                }
                .padding(.vertical, 16)
            } else if leaderRows.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "trophy")
                            .font(.system(size: 32))
                            .foregroundColor(.green.opacity(0.4))
                        Text("No friend PBs yet")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding(.vertical, 16)
            } else {
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
        }
        .task {
            await loadData()
        }
        .sheet(isPresented: $showAddPB) {
            AddPBView(vm: progressVM)
        }
        .onChange(of: showAddPB) { _, isShowing in
            if !isShowing { Task { await loadData() } }
        }
    }

    private func loadData() async {
        let currentId = appState.currentUser?.id.uuidString ?? ""
        var friendUUIDs: [UUID] = []
        var nameMap: [UUID: String] = [:]

        for friendship in friendsVM.friends {
            // Determine which side is the friend (not current user)
            let isRequester = friendship.requesterId == currentId
            let friendIdStr = isRequester ? friendship.receiverId : friendship.requesterId
            let friendProfile = isRequester ? friendship.receiver : friendship.requester

            if let uuid = UUID(uuidString: friendIdStr) {
                friendUUIDs.append(uuid)
                nameMap[uuid] = friendProfile?.displayName ?? "Friend"
            }
        }

        // Include current user's own PBs
        if let me = appState.currentUser {
            friendUUIDs.append(me.id)
            nameMap[me.id] = "Me"
        }

        guard !friendUUIDs.isEmpty else {
            isLoading = false
            return
        }

        pbsByUser = await progressVM.fetchPBsForUsers(userIds: friendUUIDs)
        friendProfiles = nameMap
        isLoading = false
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
