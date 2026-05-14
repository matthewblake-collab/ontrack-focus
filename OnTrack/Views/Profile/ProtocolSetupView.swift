import SwiftUI

struct ProtocolSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager

    let vm: ProtocolViewModel

    @State private var selectedConfig: ProtocolTypeConfig? = nil
    @State private var showEndConfirm = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.backgroundColour().ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let active = vm.activeProtocol {
                            activeBanner(active)
                        }

                        Text(vm.activeProtocol == nil ? "Choose your protocol" : "Switch protocol")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.top, 4)

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(ProtocolConfig.all) { cfg in
                                ProtocolTypeCard(config: cfg)
                                    .onTapGesture { selectedConfig = cfg }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("My Protocol")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(themeManager.currentTheme.primary)
                }
            }
            .sheet(item: $selectedConfig) { cfg in
                ProtocolDetailFormView(config: cfg, vm: vm) {
                    selectedConfig = nil
                    dismiss()
                }
                .environmentObject(appState)
                .environmentObject(themeManager)
            }
            .confirmationDialog("End current protocol?",
                                isPresented: $showEndConfirm,
                                titleVisibility: .visible) {
                Button("End Protocol", role: .destructive) {
                    Task {
                        if let uid = appState.currentUser?.id {
                            await vm.endActive(userId: uid)
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will deactivate the protocol. Your history stays intact.")
            }
        }
    }

    @ViewBuilder
    private func activeBanner(_ active: UserProtocol) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(active.protocolName)
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("Week \(active.weekNumber)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(themeManager.currentTheme.primary)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(themeManager.currentTheme.primary.opacity(0.15))
                    .clipShape(Capsule())
            }
            if let cfg = ProtocolConfig.config(for: active.protocolType) {
                Text(cfg.displayName)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            if let goal = active.goal, !goal.isEmpty {
                Text(goal)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(3)
            }
            Button(role: .destructive) {
                showEndConfirm = true
            } label: {
                Text("End current protocol")
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.borderless)
            .padding(.top, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(themeManager.currentTheme.primary.opacity(0.5), lineWidth: 1.2)
                )
        )
    }
}

private struct ProtocolTypeCard: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let config: ProtocolTypeConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(config.emoji).font(.title3)
                Text(config.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
            }
            Text(config.description)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.caption2)
                Text("\(config.suggestedDurationWeeks)w")
                    .font(.caption2)
            }
            .foregroundStyle(.white.opacity(0.55))
            if !config.trackedMarkers.isEmpty {
                Text(config.trackedMarkers.prefix(4).joined(separator: " · ").uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(themeManager.currentTheme.primary.opacity(0.8))
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(themeManager.currentTheme.primary.opacity(0.35), lineWidth: 1)
                )
        )
    }
}
