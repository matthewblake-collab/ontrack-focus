import SwiftUI

/// The Quick-Log FAB hub — a compact half-sheet with two big tiles. Each tile opens
/// its own focused mini-sheet; when a log completes there, the sub-sheet calls
/// `onComplete` which dismisses this hub, so the whole flow collapses back to the app.
struct QuickLogHubSheet: View {
    @ObservedObject var supplementVM: SupplementViewModel
    @ObservedObject var habitVM: HabitViewModel
    let quickLogVM: QuickLogViewModel
    let userId: UUID?

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var showSupplementSheet = false
    @State private var showSessionSheet = false

    private let cardColor = Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92)

    var body: some View {
        ZStack {
            themeManager.backgroundColour().ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Quick Log")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.top, 12)

                HStack(spacing: 12) {
                    tile(emoji: "💊", label: "Supplement") { showSupplementSheet = true }
                    tile(emoji: "🏋️", label: "Session") { showSessionSheet = true }
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 0)
            }
        }
        .presentationDetents([.height(260)])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showSupplementSheet) {
            QuickLogSupplementSheet(supplementVM: supplementVM, userId: userId, onComplete: { dismiss() })
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showSessionSheet) {
            QuickLogSessionSheet(habitVM: habitVM, quickLogVM: quickLogVM, userId: userId, onComplete: { dismiss() })
                .environmentObject(themeManager)
        }
    }

    private func tile(emoji: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Text(emoji).font(.system(size: 36))
                Text(label)
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(cardColor)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(themeManager.currentTheme.primary.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
