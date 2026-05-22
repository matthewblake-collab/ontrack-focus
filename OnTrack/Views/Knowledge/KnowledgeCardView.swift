import SwiftUI

struct KnowledgeCardView: View {
    let item: KnowledgeItem
    let isSaved: Bool
    let onToggleSave: () -> Void

    private static let cardBg = Color(red: 0.05, green: 0.08, blue: 0.10)

    private var categoryColor: Color {
        switch item.category {
        case "Supplements": return .green
        case "Breathwork": return .cyan
        case "Recovery": return .blue
        case "Workouts": return .orange
        case "Nutrition": return .yellow
        default: return .gray
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.category)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(categoryColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(categoryColor.opacity(0.15))
                    .clipShape(Capsule())

                Text(item.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }

                Text(item.description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(2)
            }

            Spacer()

            Button {
                onToggleSave()
            } label: {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .foregroundStyle(isSaved ? .yellow : .white.opacity(0.4))
                    .font(.system(size: 20))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Self.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(categoryColor.opacity(0.25), lineWidth: 7))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(categoryColor.opacity(0.75), lineWidth: 1.5))
    }
}
