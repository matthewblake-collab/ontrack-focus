import SwiftUI

struct ReadinessView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    let vm: ReadinessViewModel

    private static let metrics: [(key: String, label: String, weight: Double, icon: String, accent: Color)] = [
        ("sleep", "Sleep", 30, "moon.fill", Color(red: 0.3, green: 0.6, blue: 1.0)),
        ("hrv", "HRV", 20, "waveform.path.ecg.rectangle", Color(red: 0.7, green: 0.4, blue: 1.0)),
        ("rhr", "Resting HR", 15, "heart.fill", Color(red: 0.9, green: 0.3, blue: 0.3)),
        ("checkin", "Check-in", 20, "checkmark.circle.fill", Color(red: 0.2, green: 0.8, blue: 0.7)),
        ("attendance", "Attendance (7d)", 10, "figure.run", Color(red: 0.2, green: 0.8, blue: 0.4)),
        ("workout", "Recent workout", 5, "bolt.fill", Color(red: 1.0, green: 0.55, blue: 0.0))
    ]

    private var score: Int { vm.snapshot?.score ?? 0 }

    private var scoreGradientColors: [Color] {
        switch score {
        case 80...:
            return [Color(red: 0.2, green: 0.85, blue: 0.55), Color(red: 0.15, green: 0.65, blue: 0.7)]
        case 60..<80:
            return [Color(red: 1.0, green: 0.6, blue: 0.2), Color(red: 1.0, green: 0.85, blue: 0.3)]
        default:
            return [Color(red: 0.95, green: 0.3, blue: 0.35), Color(red: 1.0, green: 0.45, blue: 0.55)]
        }
    }

    private var scoreTier: String {
        switch score {
        case 90...: return "PRIME"
        case 80..<90: return "HIGH"
        case 70..<80: return "GOOD"
        case 60..<70: return "MODERATE"
        default: return "LOW"
        }
    }

    var body: some View {
        ZStack {
            Image(themeManager.currentBackgroundImage)
                .resizable()
                .scaledToFill()
                .grayscale(1.0)
                .ignoresSafeArea()
            LinearGradient(
                colors: [Color.black.opacity(0.85), Color.black.opacity(0.6)],
                startPoint: .bottom,
                endPoint: .top
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    heroSection
                        .padding(.top, 24)
                    breakdownCards
                    if let computed = vm.snapshot?.computedAt {
                        Text("Last updated \(Self.relativeTime(from: computed))")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                            .frame(maxWidth: .infinity)
                            .padding(.top, 12)
                    }
                    Spacer(minLength: 40)
                }
            }
        }
        .navigationTitle("Readiness")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 14) {
            ZStack {
                // Track arc (270° sweep, gap at bottom)
                Circle()
                    .trim(from: 0.125, to: 0.875)
                    .stroke(
                        Color.white.opacity(0.12),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(90))
                // Score-filled arc
                Circle()
                    .trim(from: 0.125, to: 0.125 + (CGFloat(score) / 100.0) * 0.75)
                    .stroke(
                        AngularGradient(
                            colors: scoreGradientColors,
                            center: .center,
                            startAngle: .degrees(135),
                            endAngle: .degrees(135 + 270)
                        ),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(90))
                    .animation(.easeOut(duration: 0.9), value: score)

                VStack(spacing: 2) {
                    Text(vm.snapshot.map { "\($0.score)" } ?? "—")
                        .font(.system(size: 80, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 200, height: 200)

            Text(scoreTier)
                .font(.caption)
                .fontWeight(.bold)
                .tracking(4)
                .foregroundStyle(
                    LinearGradient(
                        colors: scoreGradientColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Text(vm.snapshot?.sentence ?? "Not computed yet.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - Breakdown cards

    private var breakdownCards: some View {
        VStack(spacing: 10) {
            ForEach(Self.metrics, id: \.key) { metric in
                metricCard(metric)
            }
        }
    }

    @ViewBuilder
    private func metricCard(_ metric: (key: String, label: String, weight: Double, icon: String, accent: Color)) -> some View {
        let contribution = vm.snapshot?.breakdown[metric.key]
        let normalized: Double = contribution.map { $0 / metric.weight } ?? 0
        let available = contribution != nil
        let opacity: Double = available ? 1.0 : 0.35

        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: metric.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(metric.accent)
                    .opacity(opacity)
                VStack(alignment: .leading, spacing: 2) {
                    Text(metric.label)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .opacity(opacity)
                    Text("×\(Int(metric.weight))%")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }
                Spacer()
                Text(available ? "\(Int(normalized.rounded()))" : "—")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .opacity(opacity)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                    Capsule()
                        .fill(metric.accent)
                        .frame(width: proxy.size.width * CGFloat(normalized / 100.0))
                        .animation(.easeOut(duration: 0.8), value: vm.snapshot?.score)
                }
            }
            .frame(height: 8)
        }
        .padding(14)
        .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
    }

    private static func relativeTime(from date: Date) -> String {
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .full
        return fmt.localizedString(for: date, relativeTo: Date())
    }
}
