import SwiftUI

struct ReadinessCardView: View {
    let vm: ReadinessViewModel
    let onTap: () -> Void

    private var score: Int { vm.snapshot?.score ?? 0 }

    private var tierColor: Color {
        switch score {
        case 80...: return Color(red: 0.2, green: 0.85, blue: 0.5)
        case 60..<80: return Color(red: 1.0, green: 0.6, blue: 0.2)
        default: return Color(red: 0.95, green: 0.3, blue: 0.35)
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {

                // Ring + score
                ZStack {
                    Circle()
                        .fill(tierColor.opacity(0.1))
                        .frame(width: 76, height: 76)
                    Circle()
                        .stroke(tierColor.opacity(0.25), lineWidth: 7)
                        .frame(width: 64, height: 64)
                    Circle()
                        .trim(from: 0, to: vm.snapshot != nil ? CGFloat(score) / 100.0 : 0)
                        .stroke(tierColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(-90))
                        .shadow(color: tierColor.opacity(0.6), radius: 6)
                    Text(vm.snapshot != nil ? "\(score)" : "—")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                }

                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text("READINESS")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(1.4)
                        .foregroundStyle(tierColor.opacity(0.7))
                    Text(vm.snapshot?.sentence ?? "Open app to compute.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if let computed = vm.snapshot?.computedAt {
                        Text("Updated \(Self.relativeTime(from: computed))")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(16)
            .background(
                ZStack {
                    Color(red: 0.05, green: 0.08, blue: 0.10)
                    RadialGradient(
                        colors: [tierColor.opacity(0.2), Color.clear],
                        center: .leading,
                        startRadius: 0,
                        endRadius: 120
                    )
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(tierColor.opacity(0.25), lineWidth: 8)
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(tierColor.opacity(0.8), lineWidth: 1.5)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }

    private static func relativeTime(from date: Date) -> String {
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .short
        return fmt.localizedString(for: date, relativeTo: Date())
    }
}
