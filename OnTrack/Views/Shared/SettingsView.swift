import SwiftUI
import Supabase

struct SettingsView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appState: AppState
    @State private var showResetConfirm = false
    @State private var showDeleteConfirm = false
    @State private var showDeleteFinalConfirm = false
    @State private var shareAnalytics: Bool = !UserDefaults.standard.bool(forKey: "analytics_opt_out")
    var body: some View {
        List {
            Section("Appearance") {
                HStack {
                    Text("Mode")
                    Spacer()
                    Picker("", selection: $themeManager.colorSchemePreference) {
                        ForEach(ColorSchemePreference.allCases) { scheme in
                            Text(scheme.label).tag(scheme)
                        }
                    }
                    .pickerStyle(.menu)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("Accent Colour", systemImage: "paintpalette.fill")
                        .font(.subheadline)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(AppTheme.allCases) { theme in
                            Button {
                                themeManager.currentTheme = theme
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(theme.gradient)
                                        .frame(width: 40, height: 40)
                                    if themeManager.currentTheme == theme {
                                        Image(systemName: "checkmark")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                    Text("Used for buttons, icons and highlights")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Background") {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Background Colour", systemImage: "circle.lefthalf.filled")
                        .font(.subheadline)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(AppTheme.allCases) { theme in
                            Button {
                                themeManager.backgroundTheme = theme
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(theme.gradient)
                                        .frame(width: 40, height: 40)
                                    if themeManager.backgroundTheme == theme {
                                        Image(systemName: "checkmark")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack {
                        Text("Intensity")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(themeManager.backgroundOpacity * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $themeManager.backgroundOpacity, in: 0...0.5, step: 0.01)
                        .tint(themeManager.backgroundTheme.primary)

                    RoundedRectangle(cornerRadius: 8)
                        .fill(themeManager.backgroundColour())
                        .frame(height: 28)
                        .overlay(Text("Preview").font(.caption2).foregroundStyle(.secondary))
                }
                .padding(.vertical, 4)
            }

            Section("Cards") {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Card Colour", systemImage: "rectangle.fill")
                        .font(.subheadline)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(AppTheme.allCases) { theme in
                            Button {
                                themeManager.cardTheme = theme
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(theme.gradient)
                                        .frame(width: 40, height: 40)
                                    if themeManager.cardTheme == theme {
                                        Image(systemName: "checkmark")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack {
                        Text("Intensity")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(themeManager.cardOpacity * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $themeManager.cardOpacity, in: 0...0.3, step: 0.01)
                        .tint(themeManager.cardTheme.primary)

                    RoundedRectangle(cornerRadius: 8)
                        .fill(themeManager.cardColour())
                        .frame(height: 28)
                        .overlay(Text("Preview").font(.caption2).foregroundStyle(.secondary))
                }
                .padding(.vertical, 4)
            }

            Section("Notifications") {
                HStack {
                    Label("Default Reminder", systemImage: "bell.fill")
                    Spacer()
                    Text("1 hour before")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }

            Section("Privacy") {
                Toggle("Share anonymous usage data", isOn: $shareAnalytics)
                    .onChange(of: shareAnalytics) { _, newValue in
                        AnalyticsManager.shared.setOptOut(!newValue)
                    }
                Text("Helps improve OnTrack. No personal data is collected.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Data") {
                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    Label("Reset My Stats", systemImage: "arrow.counterclockwise.circle.fill")
                }
                .confirmationDialog("Reset Stats", isPresented: $showResetConfirm, titleVisibility: .visible) {
                    Button("Reset All Stats", role: .destructive) {
                        resetAllStats()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will permanently delete all your habit logs, check-ins, supplement logs and attendance records. This cannot be undone.")
                }

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete Account", systemImage: "person.crop.circle.badge.minus")
                }
                .confirmationDialog("Delete Account?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                    Button("Continue to Delete", role: .destructive) {
                        showDeleteFinalConfirm = true
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will permanently delete your account and all your data. This cannot be undone.")
                }
                .confirmationDialog("Are you absolutely sure?", isPresented: $showDeleteFinalConfirm, titleVisibility: .visible) {
                    Button("Delete My Account Forever", role: .destructive) {
                        Task {
                            let vm = AuthViewModel()
                            _ = await vm.deleteAccount(appState: appState)
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Your account, habits, supplements, check-ins and group data will be permanently deleted.")
                }
            }

            Section("About") {
                HStack {
                    Label("Version", systemImage: "info.circle")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
                HStack {
                    Label("Build", systemImage: "hammer")
                    Spacer()
                    Text("Stage 3")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
        }
        .navigationTitle("Settings")
        .themedList(themeManager)
    }

    private func resetAllStats() {
        guard let userId = appState.currentUser?.id else { return }
        Task {
            let uid = userId.uuidString
            async let a: Void = { _ = try? await supabase.from("habit_logs").delete().eq("user_id", value: uid).execute() }()
            async let b: Void = { _ = try? await supabase.from("daily_checkins").delete().eq("user_id", value: uid).execute() }()
            async let c: Void = { _ = try? await supabase.from("supplement_logs").delete().eq("user_id", value: uid).execute() }()
            async let d: Void = { _ = try? await supabase.from("attendance").delete().eq("user_id", value: uid).execute() }()
            _ = await (a, b, c, d)
            UserDefaults.standard.removeObject(forKey: "checkin_completed_date")
        }
    }
}
