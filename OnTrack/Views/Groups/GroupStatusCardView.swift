import SwiftUI
import Supabase

@Observable
final class GroupStatusVM {
    var members: [(userId: UUID, name: String, checkedIn: Bool)] = []
    var leaderName: String? = nil
    var accountabilityLine: String? = nil
    var hasTodaySessions: Bool = false
    var isLoading = false

    var checkedInCount: Int { members.filter { $0.checkedIn }.count }
    var totalCount: Int { members.count }

    func isCheckedIn(userId: UUID) -> Bool {
        members.first(where: { $0.userId == userId })?.checkedIn ?? false
    }

    func load(groupId: UUID, userId: UUID) async {
        isLoading = true
        do {
            let groupMembers: [GroupMember] = try await supabase
                .from("group_members")
                .select()
                .eq("group_id", value: groupId.uuidString)
                .execute()
                .value

            let profiles: [Profile] = try await supabase
                .from("profiles")
                .select()
                .in("id", values: groupMembers.map { $0.userId.uuidString })
                .execute()
                .value

            // Find today's sessions for this group
            struct SessionIdRow: Decodable { let id: UUID }

            let todayStr = String(ISO8601DateFormatter().string(from: Date()).prefix(10))
            let tomorrowDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            let tomorrowStr = String(ISO8601DateFormatter().string(from: tomorrowDate).prefix(10))

            let todaySessions: [SessionIdRow] = (try? await supabase
                .from("sessions")
                .select("id")
                .eq("group_id", value: groupId.uuidString)
                .neq("status", value: "cancelled")
                .gte("proposed_at", value: "\(todayStr)T00:00:00")
                .lt("proposed_at", value: "\(tomorrowStr)T00:00:00")
                .execute()
                .value) ?? []

            self.hasTodaySessions = !todaySessions.isEmpty

            // Build checked-in set from session attendance
            let checkedInIds: Set<String>
            if todaySessions.isEmpty {
                checkedInIds = []
            } else {
                struct AttendanceRecord: Decodable {
                    let userId: UUID
                    enum CodingKeys: String, CodingKey {
                        case userId = "user_id"
                    }
                }

                let attendance: [AttendanceRecord] = (try? await supabase
                    .from("attendance")
                    .select("user_id")
                    .in("session_id", values: todaySessions.map { $0.id.uuidString })
                    .eq("attended", value: true)
                    .execute()
                    .value) ?? []

                checkedInIds = Set(attendance.map { $0.userId.uuidString })
            }

            self.members = groupMembers.map { m in
                let name = profiles.first(where: { $0.id == m.userId })?.displayName ?? "Member"
                let checkedIn = checkedInIds.contains(m.userId.uuidString)
                return (userId: m.userId, name: name, checkedIn: checkedIn)
            }

            if let topMember = groupMembers.max(by: { $0.sessionStreak < $1.sessionStreak }),
               topMember.sessionStreak > 0 {
                self.leaderName = profiles.first(where: { $0.id == topMember.userId })?.displayName
            } else {
                self.leaderName = nil
            }

            // Accountability partner: fetch accepted friendships for current user
            struct FriendshipRecord: Decodable {
                let requesterId: String
                let receiverId: String
                enum CodingKeys: String, CodingKey {
                    case requesterId = "requester_id"
                    case receiverId = "receiver_id"
                }
            }

            let myIdString = userId.uuidString
            let friendships: [FriendshipRecord] = (try? await supabase
                .from("friendships")
                .select("requester_id, receiver_id")
                .eq("status", value: "accepted")
                .or("requester_id.eq.\(myIdString),receiver_id.eq.\(myIdString)")
                .execute()
                .value) ?? []

            let friendIdStrings: Set<String> = Set(friendships.compactMap { f in
                if f.requesterId == myIdString { return f.receiverId }
                if f.receiverId == myIdString { return f.requesterId }
                return nil
            })

            if let partner = self.members.first(where: {
                $0.userId != userId && friendIdStrings.contains($0.userId.uuidString)
            }) {
                if partner.checkedIn {
                    self.accountabilityLine = "👥 You and \(partner.name) are both active today"
                } else {
                    self.accountabilityLine = "⚠️ \(partner.name) hasn't checked in yet"
                }
            } else {
                self.accountabilityLine = nil
            }
        } catch {
            print("[GroupStatusVM] load error: \(error)")
        }
        isLoading = false
    }
}

struct GroupStatusCardView: View {
    let groupId: UUID
    let groupName: String
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @State private var vm = GroupStatusVM()

    private var currentUserId: UUID { appState.currentUser?.id ?? UUID() }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("👥")
                Text(groupName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Spacer()
            }

            if vm.isLoading {
                ProgressView()
                    .tint(.white)
            } else {
                // Signal 1 & 2: session status for today
                if !vm.hasTodaySessions {
                    Text("No session today")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                } else {
                    let checkedIn = vm.isCheckedIn(userId: currentUserId)
                    if checkedIn {
                        Text("✅ All sessions completed today")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    } else {
                        Text("1 session today")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                // Signal 3: streak leaderboard leader
                if let leader = vm.leaderName {
                    Text("🏆 \(leader) leading this week")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }

                // Signal 4: accountability partner
                if let partnerLine = vm.accountabilityLine {
                    Text(partnerLine)
                        .font(.caption)
                        .foregroundColor(partnerLine.hasPrefix("👥") ? .white.opacity(0.7) : .orange)
                }

                let hour = Calendar.current.component(.hour, from: Date())
                if hour >= 18 && hour < 22 {
                    let hoursLeft = 22 - hour
                    Text("⏰ \(hoursLeft)h left")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(14)
        .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .task {
            await vm.load(groupId: groupId, userId: currentUserId)
        }
    }
}
