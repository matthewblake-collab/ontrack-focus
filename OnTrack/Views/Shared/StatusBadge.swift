import SwiftUI

struct StatusBadge: View {
    let status: String

    var color: Color {
        switch status {
        case "upcoming": return .blue
        case "cancelled": return .red
        case "completed": return .green
        default: return .gray
        }
    }

    var body: some View {
        Text(status.capitalized)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
