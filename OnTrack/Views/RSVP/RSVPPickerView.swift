import SwiftUI
import Supabase

struct RSVPPickerView: View {
    let sessionId: UUID
    let userId: UUID
    @State private var viewModel = RSVPViewModel()

    var body: some View {
        VStack(spacing: 16) {
            if viewModel.isLoading {
                ProgressView()
            } else {
                HStack(spacing: 12) {
                    RSVPButton(
                        title: "Going",
                        icon: "checkmark.circle.fill",
                        color: .green,
                        isSelected: viewModel.myRSVP?.status == "going"
                    ) {
                        Task {
                            await viewModel.upsertRSVP(sessionId: sessionId, userId: userId, status: "going")
                        }
                    }

                    RSVPButton(
                        title: "Maybe",
                        icon: "questionmark.circle.fill",
                        color: .orange,
                        isSelected: viewModel.myRSVP?.status == "maybe"
                    ) {
                        Task {
                            await viewModel.upsertRSVP(sessionId: sessionId, userId: userId, status: "maybe")
                        }
                    }

                    RSVPButton(
                        title: "Can't Go",
                        icon: "xmark.circle.fill",
                        color: .red,
                        isSelected: viewModel.myRSVP?.status == "not_going"
                    ) {
                        Task {
                            await viewModel.upsertRSVP(sessionId: sessionId, userId: userId, status: "not_going")
                        }
                    }
                }

                HStack(spacing: 24) {
                    RSVPCount(count: viewModel.goingCount, label: "Going", color: .green)
                    RSVPCount(count: viewModel.maybeCount, label: "Maybe", color: .orange)
                    RSVPCount(count: viewModel.notGoingCount, label: "Can't Go", color: .red)
                }
                .padding(.top, 4)

                // RSVP member list
                if !viewModel.rsvps.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(viewModel.rsvps) { rsvp in
                            HStack(spacing: 8) {
                                Text(viewModel.rsvpNameMap[rsvp.userId] ?? "Unknown")
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                Spacer()
                                RSVPStatusChip(status: rsvp.status)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
        .task {
            await viewModel.fetchRSVPs(sessionId: sessionId, userId: userId)
        }
    }
}

struct RSVPButton: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? color.opacity(0.15) : Color(.systemGray6))
            .foregroundStyle(isSelected ? color : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct RSVPCount: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct RSVPStatusChip: View {
    let status: String

    private var label: String {
        switch status {
        case "going": return "Going"
        case "maybe": return "Maybe"
        case "not_going": return "Can't Go"
        default: return status.capitalized
        }
    }

    private var color: Color {
        switch status {
        case "going": return .green
        case "maybe": return .orange
        case "not_going": return .red
        default: return .gray
        }
    }

    var body: some View {
        Text(label)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - Session Lifecycle Card

struct SessionLifecycleCard: View {
    let session: AppSession
    let rsvpStatus: String?
    let attended: Bool?
    let onTap: () -> Void
    var showToggle: Bool = false
    var onToggle: (() -> Void)? = nil
    var onRSVP: ((String) -> Void)? = nil

    private static let teal    = Color(red: 0.08, green: 0.35, blue: 0.45)
    private static let cardBg  = Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92)

    private var isPast: Bool {
        (session.proposedAt.map { $0 < Date() } ?? false) || session.status == "completed"
    }

    private struct LifecycleStyle {
        let icon: String
        let iconColor: Color
        let subtitle: String
        let borderColor: Color
        let lineWidth: CGFloat
    }

    private var style: LifecycleStyle {
        if isPast {
            if attended == true {
                return LifecycleStyle(
                    icon: "checkmark.circle.fill", iconColor: .green,
                    subtitle: "Attended ✓",
                    borderColor: .green.opacity(0.7), lineWidth: 2
                )
            } else if attended == false {
                return LifecycleStyle(
                    icon: "xmark.circle.fill", iconColor: .red,
                    subtitle: "Missed",
                    borderColor: .red.opacity(0.4), lineWidth: 2
                )
            } else {
                return LifecycleStyle(
                    icon: "clock.badge.questionmark", iconColor: .gray,
                    subtitle: "No record",
                    borderColor: .gray.opacity(0.3), lineWidth: 2
                )
            }
        } else {
            switch rsvpStatus {
            case "going":
                return LifecycleStyle(
                    icon: "checkmark.circle.fill", iconColor: Self.teal,
                    subtitle: "You're in ✓",
                    borderColor: Self.teal.opacity(0.4), lineWidth: 2
                )
            case "maybe":
                return LifecycleStyle(
                    icon: "questionmark.circle.fill", iconColor: .orange,
                    subtitle: "Maybe",
                    borderColor: .orange.opacity(0.4), lineWidth: 2
                )
            case "not_going":
                return LifecycleStyle(
                    icon: "xmark.circle.fill", iconColor: .gray,
                    subtitle: "Not attending",
                    borderColor: .gray.opacity(0.3), lineWidth: 2
                )
            default:
                return LifecycleStyle(
                    icon: "bell.badge", iconColor: .red,
                    subtitle: "RSVP required",
                    borderColor: .red.opacity(0.5), lineWidth: 2
                )
            }
        }
    }

    private var subtitleColor: Color {
        if attended == true { return .green }
        if !isPast && rsvpStatus == nil { return .red.opacity(0.9) }
        if isPast && attended == false { return .red.opacity(0.7) }
        return .white.opacity(0.7)
    }

    var body: some View {
        let s = style
        HStack(spacing: 16) {
            if showToggle {
                Button {
                    onToggle?()
                } label: {
                    Image(systemName: attended == true ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(attended == true ? .green : .white.opacity(0.6))
                        .font(.title2)
                }
            } else {
                ZStack {
                    Circle()
                        .fill(s.iconColor.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: s.icon)
                        .font(.title2)
                        .foregroundStyle(s.iconColor)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(session.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                if let proposedAt = session.proposedAt {
                    Text(proposedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Text(s.subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(subtitleColor)
            }
            Spacer()
            // Quick RSVP buttons when no response yet and session is upcoming
            if !isPast && rsvpStatus == nil && showToggle == false {
                HStack(spacing: 6) {
                    Button {
                        onRSVP?("going")
                    } label: {
                        Text("Going")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.25))
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(Color.green.opacity(0.5), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    Button {
                        onRSVP?("maybe")
                    } label: {
                        Text("Maybe")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.2))
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(Color.orange.opacity(0.4), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Self.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    showToggle ? (attended == true ? Color.green.opacity(0.7) : Color(red: 0.08, green: 0.35, blue: 0.45).opacity(0.5)) : s.borderColor,
                    lineWidth: 2
                )
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Session Lifecycle Loader

struct SessionLifecycleLoader: View {
    let session: AppSession
    let userId: UUID
    let group: AppGroup
    @State private var rsvpVM = RSVPViewModel()
    @State private var attendanceRecord: Attendance? = nil

    private var goingNames: [String] {
        rsvpVM.rsvps
            .filter { $0.status == "going" }
            .compactMap { rsvpVM.rsvpNameMap[$0.userId] }
    }

    var body: some View {
        NavigationLink(destination: SessionDetailView(session: session, group: group)) {
            VStack(alignment: .leading, spacing: 4) {
                SessionLifecycleCard(
                    session: session,
                    rsvpStatus: rsvpVM.myRSVP?.status,
                    attended: attendanceRecord?.attended,
                    onTap: {},
                    onRSVP: { status in
                        Task { await rsvpVM.upsertRSVP(sessionId: session.id, userId: userId, status: status) }
                    }
                )
                if !goingNames.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.green.opacity(0.8))
                        Text(goingNames.prefix(3).joined(separator: ", ") + (goingNames.count > 3 ? " +\(goingNames.count - 3) more" : ""))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .buttonStyle(.plain)
        .task {
            await rsvpVM.fetchRSVPs(sessionId: session.id, userId: userId)
            do {
                let records: [Attendance] = try await supabase
                    .from("attendance")
                    .select()
                    .eq("session_id", value: session.id.uuidString)
                    .eq("user_id", value: userId.uuidString)
                    .limit(1)
                    .execute()
                    .value
                attendanceRecord = records.first
            } catch {}
        }
    }
}
