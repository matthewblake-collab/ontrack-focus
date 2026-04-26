import SwiftUI
import Supabase

// MARK: - ViewModel

@Observable
final class GroupStatsViewModel {

    struct MonthBar: Identifiable {
        let id = UUID()
        let month: String
        let count: Int
    }

    struct MemberStat: Identifiable {
        let id = UUID()
        let name: String
        let attended: Int
        let total: Int
        var rate: Double { total == 0 ? 0 : Double(attended) / Double(total) }
    }

    struct SessionRSVP: Identifiable {
        let id = UUID()
        let sessionTitle: String
        let going: Int
        let maybe: Int
        let notGoing: Int
    }

    var monthBars: [MonthBar] = []
    var mostActiveMonth: String? = nil
    var mostActiveMonthCount: Int = 0
    var memberStats: [MemberStat] = []
    var sessionRSVPs: [SessionRSVP] = []
    var isLoading = false

    // MARK: - Decode structs

    private struct SessionRow: Decodable {
        let id: UUID
        let title: String
        let proposedAt: Date?
        enum CodingKeys: String, CodingKey {
            case id, title
            case proposedAt = "proposed_at"
        }
    }

    private struct AttendanceRow: Decodable {
        let sessionId: UUID
        let userId: UUID
        let attended: Bool
        enum CodingKeys: String, CodingKey {
            case sessionId = "session_id"
            case userId = "user_id"
            case attended
        }
    }

    private struct RSVPRow: Decodable {
        let sessionId: UUID
        let status: String
        enum CodingKeys: String, CodingKey {
            case sessionId = "session_id"
            case status
        }
    }

    private struct MemberRow: Decodable {
        let userId: UUID
        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
        }
    }

    private struct ProfileRow: Decodable {
        let id: UUID
        let displayName: String
        enum CodingKeys: String, CodingKey {
            case id
            case displayName = "display_name"
        }
    }

    // MARK: - Fetch

    func fetchStats(groupId: UUID) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let sessions: [SessionRow] = try await supabase
                .from("sessions")
                .select("id, title, proposed_at")
                .eq("group_id", value: groupId.uuidString)
                .neq("status", value: "cancelled")
                .execute()
                .value

            let sessionIds = sessions.map { $0.id.uuidString }
            guard !sessionIds.isEmpty else { return }

            async let attendanceTask = fetchAttendance(sessionIds: sessionIds)
            async let rsvpTask = fetchRSVPs(sessionIds: sessionIds)
            async let membersTask = fetchMembers(groupId: groupId)
            let (attendance, rsvps, members) = await (attendanceTask, rsvpTask, membersTask)

            let profiles = await fetchProfiles(userIds: members.map { $0.userId.uuidString })

            buildMonthBars(sessions: sessions)
            buildMemberStats(members: members, profiles: profiles, attendance: attendance, totalSessions: sessions.count)
            buildRSVPBreakdown(sessions: sessions, rsvps: rsvps)
        } catch {}
    }

    private func fetchAttendance(sessionIds: [String]) async -> [AttendanceRow] {
        (try? await supabase
            .from("attendance")
            .select("session_id, user_id, attended")
            .in("session_id", values: sessionIds)
            .execute()
            .value) ?? []
    }

    private func fetchRSVPs(sessionIds: [String]) async -> [RSVPRow] {
        (try? await supabase
            .from("rsvps")
            .select("session_id, status")
            .in("session_id", values: sessionIds)
            .execute()
            .value) ?? []
    }

    private func fetchMembers(groupId: UUID) async -> [MemberRow] {
        (try? await supabase
            .from("group_members")
            .select("user_id")
            .eq("group_id", value: groupId.uuidString)
            .execute()
            .value) ?? []
    }

    private func fetchProfiles(userIds: [String]) async -> [ProfileRow] {
        (try? await supabase
            .from("profiles")
            .select("id, display_name")
            .in("id", values: userIds)
            .execute()
            .value) ?? []
    }

    // MARK: - Build helpers

    private func buildMonthBars(sessions: [SessionRow]) {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        var counts: [String: Int] = [:]
        for session in sessions {
            guard let date = session.proposedAt else { continue }
            let key = formatter.string(from: date)
            counts[key, default: 0] += 1
        }
        let sorted = counts.sorted {
            (formatter.date(from: $0.key) ?? .distantPast) < (formatter.date(from: $1.key) ?? .distantPast)
        }
        monthBars = sorted.map { MonthBar(month: $0.key, count: $0.value) }
        if let best = sorted.max(by: { $0.value < $1.value }) {
            mostActiveMonth = best.key
            mostActiveMonthCount = best.value
        }
    }

    private func buildMemberStats(members: [MemberRow], profiles: [ProfileRow], attendance: [AttendanceRow], totalSessions: Int) {
        guard totalSessions > 0 else { return }
        memberStats = members.map { member in
            let name = profiles.first { $0.id == member.userId }?.displayName ?? "Unknown"
            let attended = attendance.filter { $0.userId == member.userId && $0.attended }.count
            return MemberStat(name: name, attended: attended, total: totalSessions)
        }
        .sorted { $0.rate > $1.rate }
    }

    private func buildRSVPBreakdown(sessions: [SessionRow], rsvps: [RSVPRow]) {
        sessionRSVPs = sessions.compactMap { session in
            let matched = rsvps.filter { $0.sessionId == session.id }
            let going = matched.filter { $0.status == "going" }.count
            let maybe = matched.filter { $0.status == "maybe" }.count
            let notGoing = matched.filter { $0.status == "not_going" }.count
            guard going + maybe + notGoing > 0 else { return nil }
            return SessionRSVP(sessionTitle: session.title, going: going, maybe: maybe, notGoing: notGoing)
        }
    }
}

// MARK: - View

struct GroupStatsView: View {
    let group: AppGroup
    @State private var vm = GroupStatsViewModel()

    private let gradientStart = Color(red: 0.08, green: 0.35, blue: 0.45)
    private let gradientEnd   = Color(red: 0.15, green: 0.55, blue: 0.38)

    private var gradient: LinearGradient {
        LinearGradient(colors: [gradientStart, gradientEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        ScrollView {
            if vm.isLoading {
                ProgressView()
                    .padding(.top, 60)
            } else if vm.monthBars.isEmpty && vm.memberStats.isEmpty && vm.sessionRSVPs.isEmpty {
                emptyState
            } else {
                VStack(spacing: 16) {
                    if let month = vm.mostActiveMonth {
                        mostActiveCard(month: month, count: vm.mostActiveMonthCount)
                    }

                    if !vm.monthBars.isEmpty {
                        statsSection(title: "Sessions by Month", icon: "calendar") {
                            MiniBarChart(bars: vm.monthBars, gradientStart: gradientStart, gradientEnd: gradientEnd)
                        }
                    }

                    if !vm.memberStats.isEmpty {
                        statsSection(title: "Attendance by Member", icon: "person.fill.checkmark") {
                            ForEach(vm.memberStats) { stat in
                                MemberAttendanceRow(stat: stat, gradientEnd: gradientEnd)
                            }
                        }
                    }

                    if !vm.sessionRSVPs.isEmpty {
                        statsSection(title: "RSVPs per Session", icon: "hand.raised.fill") {
                            ForEach(vm.sessionRSVPs) { item in
                                SessionRSVPRow(item: item, gradientEnd: gradientEnd)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Group Stats")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.fetchStats(groupId: group.id) }
    }

    private func mostActiveCard(month: String, count: Int) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "star.fill")
                .font(.largeTitle)
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 4) {
                Text("Most Active Month")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.8))
                Text(month)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                Text("\(count) session\(count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
        }
        .padding()
        .background(gradient)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func statsSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(gradientStart)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            content()
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No stats yet")
                .font(.headline)
            Text("Stats will appear once the group has sessions with RSVPs and attendance.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

// MARK: - Sub-views

private struct MiniBarChart: View {
    let bars: [GroupStatsViewModel.MonthBar]
    let gradientStart: Color
    let gradientEnd: Color

    private var maxCount: Int { bars.map(\.count).max() ?? 1 }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(bars) { bar in
                    VStack(spacing: 4) {
                        Text("\(bar.count)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        RoundedRectangle(cornerRadius: 5)
                            .fill(LinearGradient(
                                colors: [gradientStart, gradientEnd],
                                startPoint: .bottom,
                                endPoint: .top
                            ))
                            .frame(width: 32, height: max(8, CGFloat(bar.count) / CGFloat(maxCount) * 80))
                        Text(bar.month.components(separatedBy: " ").first ?? bar.month)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .frame(height: 120)
    }
}

private struct MemberAttendanceRow: View {
    let stat: GroupStatsViewModel.MemberStat
    let gradientEnd: Color

    private var rateColor: Color {
        switch stat.rate {
        case 0.75...: return gradientEnd
        case 0.5..<0.75: return .orange
        default: return .red
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(stat.name)
                    .font(.subheadline)
                Spacer()
                Text("\(Int(stat.rate * 100))%")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(rateColor)
                Text("(\(stat.attended)/\(stat.total))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(rateColor)
                        .frame(width: geo.size.width * CGFloat(stat.rate), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 4)
    }
}

private struct SessionRSVPRow: View {
    let item: GroupStatsViewModel.SessionRSVP
    let gradientEnd: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.sessionTitle)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
            HStack(spacing: 14) {
                Label("\(item.going)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(gradientEnd)
                Label("\(item.maybe)", systemImage: "questionmark.circle.fill")
                    .foregroundStyle(.orange)
                Label("\(item.notGoing)", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
            .font(.caption)
            Divider()
        }
        .padding(.vertical, 2)
    }
}
