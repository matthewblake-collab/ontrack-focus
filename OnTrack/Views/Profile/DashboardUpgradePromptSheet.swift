import SwiftUI

/// Non-premium users tap the Dashboard card → this sheet appears
/// listing what premium unlocks. The "Upgrade" CTA is a no-op alert
/// until billing is wired (out of scope for F11).
struct DashboardUpgradePromptSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showComingSoon = false

    private let features: [String] = [
        "Full bloodwork dashboard with trend charts and protocol-aware flags",
        "Daily check-in correlations and 30-day insight reports",
        "Supplement adherence tracking + exclusive partner discounts",
        "Workout volume, attendance, and personal best timelines",
        "Body composition and biometric trend visualisations",
        "Unified journal across web and iOS — Realtime sync",
        "Customisable widget layout, dark and light themes"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.backgroundColour().ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("OnTrack Premium")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.white)
                            Text("Unlock the full health dashboard on web + iOS.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(.top, 8)

                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(features, id: \.self) { f in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(themeManager.currentTheme.primary)
                                        .font(.footnote)
                                        .padding(.top, 2)
                                    Text(f)
                                        .font(.footnote)
                                        .foregroundStyle(.white.opacity(0.85))
                                }
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                        )

                        Button {
                            showComingSoon = true
                        } label: {
                            Text("Upgrade")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(themeManager.currentTheme.primary)
                                .foregroundStyle(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Premium upgrade coming soon", isPresented: $showComingSoon) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Billing is being wired up. Foundation members will be migrated to premium automatically.")
            }
        }
    }
}
