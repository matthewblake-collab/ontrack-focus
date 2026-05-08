import SwiftUI

struct StreakCelebrationView: View {
    let streakCount: Int
    var onDismiss: (() -> Void)? = nil

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @State private var iconScale: CGFloat = 0.4
    @State private var contentOpacity: Double = 0

    private var milestone: Milestone {
        switch streakCount {
        case 100...: return .century
        case 30...:  return .month
        default:     return .week
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(themeManager.currentTheme.gradient)
                    .frame(width: 96, height: 96)
                Image(systemName: milestone.icon)
                    .font(.system(size: 44))
                    .foregroundColor(.white)
            }
            .scaleEffect(iconScale)
            .accessibilityHidden(true)

            Spacer().frame(height: 28)

            Text("\(streakCount)")
                .font(.system(size: 80, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .accessibilityLabel("\(streakCount) days")

            Text("DAY STREAK")
                .font(.system(size: 13, weight: .semibold))
                .tracking(4)
                .foregroundColor(.white.opacity(0.6))
                .padding(.top, 4)

            Spacer().frame(height: 24)

            VStack(spacing: 10) {
                Text(milestone.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(milestone.subtitle)
                    .font(.callout)
                    .foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 40)
            }

            Spacer()

            Button {
                onDismiss?()
                dismiss()
            } label: {
                Text("Keep Going")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(themeManager.currentTheme.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
            .accessibilityLabel("Keep going — dismiss streak milestone")
        }
        .opacity(contentOpacity)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color(red: 0.06, green: 0.09, blue: 0.12)
                .ignoresSafeArea()
        )
        .presentationDetents([.fraction(0.65)])
        .presentationBackground(Color(red: 0.06, green: 0.09, blue: 0.12))
        .presentationDragIndicator(.visible)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                iconScale = 1.0
            }
            withAnimation(.easeIn(duration: 0.25)) {
                contentOpacity = 1
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(streakCount) day streak milestone: \(milestone.title)")
    }

    private enum Milestone {
        case week, month, century

        var icon: String {
            switch self {
            case .week:    return "flame.fill"
            case .month:   return "bolt.fill"
            case .century: return "trophy.fill"
            }
        }

        var title: String {
            switch self {
            case .week:    return "One Week Strong"
            case .month:   return "30 Days. No Excuses."
            case .century: return "100 Days. Elite."
            }
        }

        var subtitle: String {
            switch self {
            case .week:    return "You've built something real.\nDon't stop now."
            case .month:   return "Most people quit by now.\nYou didn't."
            case .century: return "You're in rare company.\nThis is who you are now."
            }
        }
    }
}

#Preview("7-Day") {
    Color.black.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            StreakCelebrationView(streakCount: 7)
                .environmentObject(ThemeManager.shared)
        }
}

#Preview("30-Day") {
    Color.black.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            StreakCelebrationView(streakCount: 30)
                .environmentObject(ThemeManager.shared)
        }
}

#Preview("100-Day") {
    Color.black.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            StreakCelebrationView(streakCount: 100)
                .environmentObject(ThemeManager.shared)
        }
}
