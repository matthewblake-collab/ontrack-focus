import SwiftUI

struct ReadinessView: View {
    @Environment(\.dismiss) private var dismiss
    let vm: ReadinessViewModel

    private static let labels: [(key: String, label: String, weight: Double)] = [
        ("sleep", "Sleep", 30),
        ("hrv", "HRV", 20),
        ("rhr", "Resting HR", 15),
        ("checkin", "Check-in", 20),
        ("attendance", "Attendance (7d)", 10),
        ("workout", "Recent workout", 5)
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    headerCard
                    breakdownSection
                    if let computed = vm.snapshot?.computedAt {
                        Text("Last updated \(Self.relativeTime(from: computed))")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.top, 8)
                    }
                    Spacer(minLength: 40)
                }
                .padding(.top, 16)
            }
        }
        .navigationTitle("Readiness")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        VStack(spacing: 12) {
            Text(vm.snapshot.map { "\($0.score)" } ?? "—")
                .font(.system(size: 72, weight: .bold))
                .foregroundStyle(.white)
            Text(vm.snapshot?.sentence ?? "Not computed yet.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Breakdown")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 16)
                .padding(.top, 4)

            VStack(spacing: 0) {
                ForEach(Self.labels, id: \.key) { entry in
                    breakdownRow(key: entry.key, label: entry.label, weight: entry.weight)
                    if entry.key != Self.labels.last?.key {
                        Divider().background(Color.white.opacity(0.06))
                    }
                }
            }
            .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func breakdownRow(key: String, label: String, weight: Double) -> some View {
        let contribution = vm.snapshot?.breakdown[key]
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.white)
            Spacer()
            if let c = contribution {
                Text("\(Int((c / weight).rounded())) / 100")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                Text("×\(Int(weight))%")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.35))
            } else {
                Text("unavailable")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private static func relativeTime(from date: Date) -> String {
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .full
        return fmt.localizedString(for: date, relativeTo: Date())
    }
}
