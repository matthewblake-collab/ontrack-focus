import SwiftUI
import Supabase

// MARK: - ViewModel

@Observable
final class GroupLeaderboardViewModel {

    enum Category: String, CaseIterable {
        case attendance = "Attendance"
        case streaks = "Streaks"
        case supplements = "Supplements"
    }

    struct Entry: Identifiable {
        let id: UUID
        let name: String
        let score: String
        let numericScore: Double
    }

    var selectedCategory: Category = .attendance
    var attendanceEntries: [Entry] = []
    var streakEntries: [Entry] = []
    var supplementEntries: [Entry] = []
    var isLoading = false

    var currentEntries: [Entry] {
        switch selectedCategory {
        case .attendance:  return attendanceEntries
        case .streaks:     return streakEntries
        case .supplements: return supplementEntries
        }
    }

    // MARK: - Decode structs

    private struct MemberRow: Decodable {
        let userId: UUID
        enum CodingKeys: String, CodingKey { case userId = "user_id" }
    }

    private struct ProfileRow: Decodable {
        let id: UUID
        let displayName: String
        enum CodingKeys: String, CodingKey {
            case id
            case displayName = "display_name"
        }
    }

    private struct SessionIdRow: Decodable { let id: UUID }

    private struct AttendanceRow: Decodable {
        let userId: UUID
        let attended: Bool
        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case attended
        }
    }

    private struct HabitRow: Decodable { let id: UUID }

    private struct HabitLogRow: Decodable {
        let habitId: UUID
        let userId: UUID
        let loggedDate: String
        enum CodingKeys: String, CodingKey {
            case habitId = "habit_id"
            case userId = "user_id"
            case loggedDate = "logged_date"
        }
    }

    private struct SupplementRow: Decodable {
        let id: UUID
        let userId: UUID
        enum CodingKeys: String, CodingKey {
            case id
            case userId = "user_id"
        }
    }

    private struct SupplementLogRow: Decodable {
        let userId: UUID
        let takenAt: String
        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case takenAt = "taken_at"
        }
    }

    // MARK: - Fetch

    func fetchLeaderboard(groupId: UUID) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let members: [MemberRow] = try await supabase
                .from("group_members")
                .select("user_id")
                .eq("group_id", value: groupId.uuidString)
                .execute()
                .value

            guard !members.isEmpty else { return }

            let memberIds = members.map { $0.userId }
            let memberIdStrings = memberIds.map { $0.uuidString }

            let profiles: [ProfileRow] = (try? await supabase
                .from("profiles")
                .select("id, display_name")
                .in("id", values: memberIdStrings)
                .execute()
                .value) ?? []

            async let attTask = buildAttendanceEntries(groupId: groupId, memberIds: memberIds, profiles: profiles)
            async let strTask = buildStreakEntries(groupId: groupId, memberIds: memberIds, profiles: profiles)
            async let supTask = buildSupplementEntries(memberIds: memberIds, memberIdStrings: memberIdStrings, profiles: profiles)

            let (att, str, sup) = await (attTask, strTask, supTask)
            attendanceEntries = att
            streakEntries = str
            supplementEntries = sup
        } catch {}
    }

    // MARK: - Attendance entries

    private func buildAttendanceEntries(groupId: UUID, memberIds: [UUID], profiles: [ProfileRow]) async -> [Entry] {
        do {
            let sessions: [SessionIdRow] = try await supabase
                .from("sessions")
                .select("id")
                .eq("group_id", value: groupId.uuidString)
                .neq("status", value: "cancelled")
                .execute()
                .value

            guard !sessions.isEmpty else { return [] }

            let sessionIdStrings = sessions.map { $0.id.uuidString }

            let attendance: [AttendanceRow] = try await supabase
                .from("attendance")
                .select("user_id, attended")
                .in("session_id", values: sessionIdStrings)
                .execute()
                .value

            let total = sessions.count
            return memberIds.map { userId in
                let name = profiles.first { $0.id == userId }?.displayName ?? "Unknown"
                let attended = attendance.filter { $0.userId == userId && $0.attended }.count
                let rate = Double(attended) / Double(total)
                return Entry(id: userId, name: name, score: "\(Int(rate * 100))%", numericScore: rate)
            }
            .sorted { $0.numericScore > $1.numericScore }
        } catch { return [] }
    }

    // MARK: - Habit streak entries

    private func buildStreakEntries(groupId: UUID, memberIds: [UUID], profiles: [ProfileRow]) async -> [Entry] {
        do {
            let habits: [HabitRow] = try await supabase
                .from("habits")
                .select("id")
                .eq("group_id", value: groupId.uuidString)
                .eq("is_archived", value: false)
                .execute()
                .value

            guard !habits.isEmpty else { return [] }

            let habitIdStrings = habits.map { $0.id.uuidString }

            let logs: [HabitLogRow] = try await supabase
                .from("habit_logs")
                .select("habit_id, user_id, logged_date")
                .in("habit_id", values: habitIdStrings)
                .execute()
                .value

            return memberIds.map { userId in
                let name = profiles.first { $0.id == userId }?.displayName ?? "Unknown"
                let userLogs = logs.filter { $0.userId == userId }
                let streak = longestCurrentStreak(logs: userLogs)
                return Entry(id: userId, name: name, score: "\(streak) day\(streak == 1 ? "" : "s")", numericScore: Double(streak))
            }
            .sorted { $0.numericScore > $1.numericScore }
        } catch { return [] }
    }

    private func longestCurrentStreak(logs: [HabitLogRow]) -> Int {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let grouped = Dictionary(grouping: logs) { $0.habitId }
        var maxStreak = 0

        for (_, habitLogs) in grouped {
            let dateSet = Set(
                habitLogs.compactMap { formatter.date(from: $0.loggedDate) }
                    .map { calendar.startOfDay(for: $0) }
            )
            let sortedDates = dateSet.sorted(by: >)
            var checkDate = calendar.startOfDay(for: Date())
            if !dateSet.contains(checkDate) {
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            }
            var streak = 0
            for date in sortedDates {
                if date == checkDate {
                    streak += 1
                    checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
                } else if date < checkDate {
                    break
                }
            }
            maxStreak = max(maxStreak, streak)
        }
        return maxStreak
    }

    // MARK: - Supplement consistency entries

    private func buildSupplementEntries(memberIds: [UUID], memberIdStrings: [String], profiles: [ProfileRow]) async -> [Entry] {
        do {
            let supplements: [SupplementRow] = try await supabase
                .from("supplements")
                .select("id, user_id")
                .in("user_id", values: memberIdStrings)
                .eq("is_active", value: true)
                .execute()
                .value

            guard !supplements.isEmpty else { return [] }

            let supplementIdStrings = supplements.map { $0.id.uuidString }

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let cutoff = formatter.string(from: Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date())

            let logs: [SupplementLogRow] = try await supabase
                .from("supplement_logs")
                .select("user_id, taken_at")
                .in("supplement_id", values: supplementIdStrings)
                .eq("taken", value: true)
                .gte("taken_at", value: cutoff)
                .execute()
                .value

            return memberIds.map { userId in
                let name = profiles.first { $0.id == userId }?.displayName ?? "Unknown"
                let uniqueDays = Set(logs.filter { $0.userId == userId }.map { $0.takenAt }).count
                let rate = Double(uniqueDays) / 30.0
                return Entry(id: userId, name: name, score: "\(uniqueDays)/30 days", numericScore: rate)
            }
            .sorted { $0.numericScore > $1.numericScore }
        } catch { return [] }
    }
}

// MARK: - View

struct GroupLeaderboardView: View {
    let group: AppGroup
    @State private var vm = GroupLeaderboardViewModel()

    private let gradientStart = Color(red: 0.08, green: 0.35, blue: 0.45)
    private let gradientEnd   = Color(red: 0.15, green: 0.55, blue: 0.38)

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("Category", selection: $vm.selectedCategory) {
                    ForEach(GroupLeaderboardViewModel.Category.allCases, id: \.self) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if vm.isLoading {
                    ProgressView()
                        .padding(.top, 40)
                } else if vm.currentEntries.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 8) {
                        ForEach(Array(vm.currentEntries.enumerated()), id: \.element.id) { index, entry in
                            LeaderboardRow(
                                rank: index + 1,
                                entry: entry,
                                gradientStart: gradientStart,
                                gradientEnd: gradientEnd
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top)
            .padding(.bottom, 32)
        }
        .navigationTitle("Leaderboard")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.fetchLeaderboard(groupId: group.id) }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "trophy")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No data yet")
                .font(.headline)
            Text("Leaderboard will populate once members start tracking.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

// MARK: - Row

private struct LeaderboardRow: View {
    let rank: Int
    let entry: GroupLeaderboardViewModel.Entry
    let gradientStart: Color
    let gradientEnd: Color

    private var medalColor: Color? {
        switch rank {
        case 1: return Color(red: 1.0,  green: 0.84, blue: 0.0)   // gold
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75)  // silver
        case 3: return Color(red: 0.80, green: 0.50, blue: 0.20)  // bronze
        default: return nil
        }
    }

    private var initial: String {
        String(entry.name.prefix(1)).uppercased()
    }

    var body: some View {
        HStack(spacing: 14) {
            // Rank / medal
            Group {
                if let color = medalColor {
                    Image(systemName: "medal.fill")
                        .font(.title3)
                        .foregroundStyle(color)
                } else {
                    Text("\(rank)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 28)

            // Avatar circle
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [gradientStart, gradientEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 40, height: 40)
                Text(initial)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }

            Text(entry.name)
                .font(.subheadline)
                .lineLimit(1)

            Spacer()

            Text(entry.score)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(medalColor ?? .primary)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
