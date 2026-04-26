import SwiftUI
import UIKit

// MARK: - Direction

enum TooltipDirection {
    case above, below, trailing
}

// MARK: - Modifier

struct ButtonTooltipModifier: ViewModifier {
    let key: String
    let title: String
    let message: String
    let direction: TooltipDirection

    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard !UserDefaults.standard.bool(forKey: key) else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    guard !UserDefaults.standard.bool(forKey: key) else { return }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        isVisible = true
                    }
                }
            }
            .overlay {
                if isVisible {
                    ButtonTooltipOverlay(
                        title: title,
                        message: message,
                        direction: direction,
                        isVisible: $isVisible,
                        key: key
                    )
                }
            }
    }
}

// MARK: - Overlay

struct ButtonTooltipOverlay: View {
    let title: String
    let message: String
    let direction: TooltipDirection
    @Binding var isVisible: Bool
    let key: String

    private let cardBg = Color(red: 0.08, green: 0.12, blue: 0.15)
    private let arrowW: CGFloat = 12
    private let arrowH: CGFloat = 8
    private let cardMaxW: CGFloat = 210
    private let gap: CGFloat = 10
    private let estimatedCardBodyH: CGFloat = 68

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.2)) { isVisible = false }
        UserDefaults.standard.set(true, forKey: key)
    }

    var body: some View {
        ZStack {
            // Full-screen dim using ignoresSafeArea so it fills the entire screen
            // regardless of where the modifier is attached.
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .allowsHitTesting(true)
                .onTapGesture { dismiss() }

            // Tooltip card — positioned using only the button's local size.
            GeometryReader { geo in
                cardView
                    .frame(maxWidth: cardMaxW)
                    .fixedSize(horizontal: false, vertical: true)
                    .scaleEffect(isVisible ? 1 : 0.85, anchor: scaleAnchor)
                    .opacity(isVisible ? 1 : 0)
                    .position(cardPosition(btnW: geo.size.width, btnH: geo.size.height))
            }
        }
        .allowsHitTesting(true)
    }

    @ViewBuilder
    private var cardView: some View {
        if direction == .trailing {
            HStack(spacing: 0) {
                TooltipArrow(pointing: .left)
                    .fill(cardBg.opacity(0.95))
                    .frame(width: arrowH, height: arrowW)
                cardBody
            }
        } else {
            VStack(spacing: 0) {
                if direction == .below {
                    TooltipArrow(pointing: .up)
                        .fill(cardBg.opacity(0.95))
                        .frame(width: arrowW, height: arrowH)
                }
                cardBody
                if direction == .above {
                    TooltipArrow(pointing: .down)
                        .fill(cardBg.opacity(0.95))
                        .frame(width: arrowW, height: arrowH)
                }
            }
        }
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline).bold()
                .foregroundStyle(.white)
            Text(message)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(cardBg.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var scaleAnchor: UnitPoint {
        switch direction {
        case .above:    return .bottom
        case .below:    return .top
        case .trailing: return .leading
        }
    }

    // Card positioned in local coordinate space where button = (0,0)–(btnW, btnH).
    // x is clamped to keep the card within screen bounds using the actual screen width.
    private func cardPosition(btnW: CGFloat, btnH: CGFloat) -> CGPoint {
        let totalCardH = arrowH + estimatedCardBodyH
        let screenW = UIScreen.main.bounds.width
        let lo = cardMaxW / 2 + 16
        let hi = screenW - cardMaxW / 2 - 16

        switch direction {
        case .below:
            let x = max(lo, min(btnW / 2, hi))
            return CGPoint(x: x, y: btnH + gap + totalCardH / 2)
        case .above:
            let x = max(lo, min(btnW / 2, hi))
            return CGPoint(x: x, y: -(gap + totalCardH / 2))
        case .trailing:
            return CGPoint(x: btnW + gap + cardMaxW / 2, y: btnH / 2)
        }
    }
}

// MARK: - Arrow Shape

struct TooltipArrow: Shape {
    enum Direction { case up, down, left, right }
    let pointing: Direction

    func path(in rect: CGRect) -> Path {
        var p = Path()
        switch pointing {
        case .up:
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        case .down:
            p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        case .left:
            p.move(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        case .right:
            p.move(to: CGPoint(x: rect.maxX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - View Extension

extension View {
    func buttonTooltip(key: String, title: String, message: String, direction: TooltipDirection = .below) -> some View {
        modifier(ButtonTooltipModifier(key: key, title: title, message: message, direction: direction))
    }
}
