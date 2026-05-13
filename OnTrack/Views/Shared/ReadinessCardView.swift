import SwiftUI

struct ReadinessCardView: View {
    let vm: ReadinessViewModel
    let onTap: () -> Void

    private var ringColor: Color {
        guard let s = vm.snapshot?.score else { return .gray }
        switch s {
        case ..<40: return Color.red.opacity(0.85)
        case 40..<70: return Color.orange.opacity(0.85)
        default: return Color.green.opacity(0.85)
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 6)
                        .frame(width: 64, height: 64)
                    Circle()
                        .trim(from: 0, to: CGFloat(vm.snapshot?.score ?? 0) / 100.0)
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(-90))
                    Text(vm.snapshot.map { "\($0.score)" } ?? "—")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Readiness")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.6))
                    Text(vm.snapshot?.sentence ?? "Tap to compute.")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if let computed = vm.snapshot?.computedAt {
                        Text("Updated \(Self.relativeTime(from: computed))")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(16)
            .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 16))
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
