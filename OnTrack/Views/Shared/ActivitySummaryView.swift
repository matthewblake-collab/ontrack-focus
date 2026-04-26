import SwiftUI

struct ActivitySummaryView: View {
    let items: [ActivitySummaryItem]
    @Environment(\.dismiss) private var dismiss

    private let relFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.09, blue: 0.12)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Handle
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                // Title
                HStack {
                    Text("While You Were Away")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.4))
                            .font(.system(size: 22))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                // Activity list
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(items) { item in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: iconFor(item.action))
                                    .foregroundStyle(accentFor(item.action))
                                    .font(.system(size: 16))
                                    .frame(width: 22, height: 22)
                                    .padding(.top, 2)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(item.actorName) \(item.action) **\(item.targetTitle)**")
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.9))
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(relFormatter.localizedString(for: item.happenedAt, relativeTo: Date()))
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.45))
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                            )
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.bottom, 16)
                }

                // Dismiss button
                Button {
                    dismiss()
                } label: {
                    Text("Got it")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.3, green: 0.6, blue: 1.0), Color(red: 0.5, green: 0.3, blue: 0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(24)
    }

    private func iconFor(_ action: String) -> String {
        switch action {
        case "added availability to": return "clock.fill"
        case "is going to": return "checkmark.circle.fill"
        default: return "bell.fill"
        }
    }

    private func accentFor(_ action: String) -> Color {
        switch action {
        case "added availability to": return Color(red: 0.4, green: 0.7, blue: 1.0)
        case "is going to": return Color(red: 0.4, green: 0.8, blue: 0.6)
        default: return .white.opacity(0.6)
        }
    }
}
