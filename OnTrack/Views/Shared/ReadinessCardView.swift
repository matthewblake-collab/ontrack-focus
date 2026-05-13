import SwiftUI

struct ReadinessCardView: View {
    let vm: ReadinessViewModel
    let onTap: () -> Void

    private var score: Int { vm.snapshot?.score ?? 0 }

    private var gradientColors: [Color] {
        switch score {
        case 80...:
            return [Color(red: 0.15, green: 0.7, blue: 0.5), Color(red: 0.1, green: 0.55, blue: 0.6)]
        case 60..<80:
            return [Color(red: 1.0, green: 0.55, blue: 0.2), Color(red: 1.0, green: 0.8, blue: 0.25)]
        default:
            return [Color(red: 0.9, green: 0.25, blue: 0.3), Color(red: 0.95, green: 0.35, blue: 0.5)]
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 76, height: 76)
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 8)
                        .frame(width: 64, height: 64)
                    Circle()
                        .trim(from: 0, to: CGFloat(score) / 100.0)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(-90))
                    Text(vm.snapshot.map { "\($0.score)" } ?? "—")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Readiness")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.8))
                    Text(vm.snapshot?.sentence ?? "Tap to compute.")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if let computed = vm.snapshot?.computedAt {
                        Text("Updated \(Self.relativeTime(from: computed))")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
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
