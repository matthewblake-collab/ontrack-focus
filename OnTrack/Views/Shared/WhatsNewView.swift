import SwiftUI

struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss
    private let vm = VersionChangeManager.shared

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

                // Icon + Title
                VStack(spacing: 8) {
                    Text("✨")
                        .font(.system(size: 40))
                    Text("What's New in \(vm.currentVersion)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 24)

                // Bullet list
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(vm.changelogForCurrentVersion, id: \.self) { bullet in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color(red: 0.4, green: 0.8, blue: 0.6))
                                .font(.system(size: 18))
                                .frame(width: 22)
                            Text(bullet)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 28)

                // Got it button
                Button {
                    vm.markSeen()
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
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(24)
    }
}
