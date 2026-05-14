import SwiftUI

/// Card in ProfileView that opens the web premium dashboard.
/// Premium → SFSafariViewController to the magic-link URL.
/// Non-premium → upgrade prompt sheet.
struct DashboardEntryCard: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appState: AppState
    let vm: DashboardEntryViewModel
    @Binding var showSafari: Bool
    @Binding var showUpgrade: Bool

    var isPremium: Bool { appState.currentUser?.isPremium == true }

    var body: some View {
        Button {
            if isPremium {
                Task { await openDashboard() }
            } else {
                showUpgrade = true
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Image(systemName: "rectangle.stack.fill")
                        .font(.title3)
                        .foregroundStyle(themeManager.currentTheme.primary)
                        .frame(width: 28)
                    if vm.badgeCount > 0 && isPremium {
                        Text("\(vm.badgeCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.red)
                            .clipShape(Capsule())
                            .offset(x: 14, y: -10)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(isPremium ? "Health Dashboard" : "Health Dashboard · Premium")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(themeManager.currentTheme.primary.opacity(0.95))
                        if !isPremium {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundStyle(themeManager.currentTheme.primary.opacity(0.6))
                        }
                    }
                    Text(detailLine)
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.6))
                }
                Spacer()
                if vm.isFetchingURL {
                    ProgressView().tint(themeManager.currentTheme.primary)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.4))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(themeManager.currentTheme.primary.opacity(isPremium ? 0.7 : 0.35), lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .alert("Couldn't open dashboard", isPresented: .constant(vm.errorMessage != nil)) {
            Button("OK", role: .cancel) { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    private var detailLine: String {
        if !isPremium { return "Bloodwork · Supplements · Workouts · Journal" }
        if vm.badgeCount > 0 {
            return "\(vm.badgeCount) update\(vm.badgeCount == 1 ? "" : "s") · open in browser"
        }
        return "Open in browser — pre-authenticated"
    }

    private func openDashboard() async {
        await vm.fetchMagicLink()
        if vm.dashboardURL != nil {
            showSafari = true
        }
    }
}
