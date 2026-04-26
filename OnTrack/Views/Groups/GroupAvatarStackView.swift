import SwiftUI

struct GroupAvatarStackView: View {
    let members: [Profile]
    var size: CGFloat = 32

    private var brandGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.35, blue: 0.45),
                Color(red: 0.15, green: 0.55, blue: 0.38)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        let shown = Array(members.prefix(3))
        let extra = members.count - 3
        let chipCount = shown.count + (extra > 0 ? 1 : 0)
        let totalWidth = chipCount > 0 ? size + CGFloat(chipCount - 1) * (size - 10) : size

        ZStack(alignment: .leading) {
            ForEach(Array(shown.enumerated()), id: \.offset) { index, member in
                avatarView(for: member)
                    .offset(x: CGFloat(index) * (size - 10))
                    .zIndex(Double(shown.count - index))
            }
            if extra > 0 {
                ZStack {
                    Circle()
                        .fill(brandGradient)
                    Text("+\(extra)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .frame(width: size, height: size)
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                .offset(x: CGFloat(3) * (size - 10))
                .zIndex(0)
            }
        }
        .frame(width: totalWidth, height: size)
    }

    @ViewBuilder
    private func avatarView(for member: Profile) -> some View {
        if let urlStr = member.avatarURL, !urlStr.isEmpty, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                case .empty, .failure:
                    initialCircle(for: member)
                @unknown default:
                    initialCircle(for: member)
                }
            }
        } else {
            initialCircle(for: member)
        }
    }

    private func initialCircle(for member: Profile) -> some View {
        ZStack {
            Circle()
                .fill(brandGradient)
            Text(String(member.displayName.prefix(1)).uppercased())
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
        .overlay(Circle().stroke(Color.white, lineWidth: 2))
    }
}
