import SwiftUI

struct FoundationMemberCardView: View {
    let onDismiss: () -> Void

    @State private var appeared = false

    private let greenAccent = Color(red: 0.102, green: 0.620, blue: 0.459) // #1A9E75
    private let iconBackground = Color(red: 0.08, green: 0.12, blue: 0.15)

    var body: some View {
        ZStack {
            Color.black.opacity(0.92)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(iconBackground)
                        .frame(width: 112, height: 112)
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(greenAccent)
                }

                Text("FOUNDATION MEMBER")
                    .font(.custom("DMSans-Bold", size: 11))
                    .tracking(2)
                    .foregroundStyle(greenAccent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .overlay(
                        Capsule()
                            .stroke(greenAccent, lineWidth: 1)
                    )

                Text("You're one of the first.")
                    .font(.custom("Syne-Bold", size: 28))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("You were here before the doors opened. As a Foundation Member, you'll be first in line for exclusive prizes as the OnTrack community grows.")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 1)
                    .padding(.vertical, 4)

                Button(action: onDismiss) {
                    Text("Let's go →")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(greenAccent)
                        )
                }
            }
            .frame(maxWidth: 340)
            .padding(.horizontal, 24)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(.easeOut(duration: 0.4), value: appeared)
        }
        .onAppear {
            appeared = true
        }
    }
}
