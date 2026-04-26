import SwiftUI
import Supabase

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(ProgressViewModel.self) private var progressVM
    @State private var isEditing = false
    @State private var newDisplayName = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showSignOutConfirm = false
    @State private var showImagePicker = false
    @State private var isUploadingAvatar = false
    @State private var insightsVM = InsightsViewModel()
    @State private var showProgress = false
    @State private var showTrophyRoom = false

    var body: some View {
        NavigationStack {
            List {
                // AVATAR + NAME
                Section {
                    VStack(spacing: 12) {
                        Button {
                            showImagePicker = true
                        } label: {
                            ZStack(alignment: .bottomTrailing) {
                                avatarView
                                Image(systemName: "camera.circle.fill")
                                    .font(.system(size: 26))
                                    .foregroundStyle(themeManager.currentTheme.primary)
                                    .background(Color(.systemBackground).clipShape(Circle()))
                                    .offset(x: 4, y: 4)
                            }
                        }
                        .buttonStyle(.plain)
                        .overlay {
                            if isUploadingAvatar {
                                ProgressView()
                                    .tint(themeManager.currentTheme.primary)
                            }
                        }

                        Text(appState.currentUser?.displayName ?? "User")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text(appState.currentUser?.id.uuidString.prefix(8).description ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                // MY PROGRESS + TROPHY ROOM
                Section {
                    // My Progress card
                    Button {
                        showProgress = true
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "chart.bar.fill")
                                .font(.title3)
                                .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.0))
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("My Progress")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.8))
                                Text("Habits · Sessions · Supplements")
                                    .font(.caption)
                                    .foregroundStyle(Color.white.opacity(0.6))
                                Text("\(progressVM.todayCompletionPct)% done today")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.9))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Color.white.opacity(0.4))
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.6), lineWidth: 1.5)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 0, trailing: 16))
                    .listRowBackground(Color.clear)

                    // Trophy Room card
                    Button {
                        showTrophyRoom = true
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "trophy.fill")
                                .font(.title3)
                                .foregroundStyle(Color.green)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Trophy Room")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.green.opacity(0.8))
                                Text("Running · Personal Bests")
                                    .font(.caption)
                                    .foregroundStyle(Color.white.opacity(0.6))
                                Text(progressVM.mostRecentPBSummary.isEmpty ? "Loading..." : progressVM.mostRecentPBSummary)
                                    .font(.caption)
                                    .foregroundStyle(Color.white.opacity(0.7))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Color.white.opacity(0.4))
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.green.opacity(0.6), lineWidth: 1.5)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
                }
                .onAppear {
                    Task { await progressVM.loadAll() }
                }

                // INSIGHTS
                Section("My Stats") {
                    InsightsGridView(vm: insightsVM)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                // DISPLAY NAME
                Section("Display Name") {
                    if isEditing {
                        TextField("Display Name", text: $newDisplayName)
                        Button("Save") {
                            Task { await saveDisplayName() }
                        }
                        .disabled(newDisplayName.isEmpty || isLoading)
                        Button("Cancel", role: .cancel) {
                            isEditing = false
                        }
                    } else {
                        HStack {
                            Text(appState.currentUser?.displayName ?? "User")
                            Spacer()
                            Button("Edit") {
                                newDisplayName = appState.currentUser?.displayName ?? ""
                                isEditing = true
                            }
                            .font(.subheadline)
                        }
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                Section {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showSignOutConfirm = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(themeManager.backgroundColour())
            .navigationTitle("Profile")
            .sheet(isPresented: $showProgress) {
                UserProgressView(vm: progressVM)
            }
            .sheet(isPresented: $showTrophyRoom) {
                TrophyRoomView(vm: progressVM)
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePickerView { data in
                    Task { await uploadAvatar(data: data) }
                }
            }
            .confirmationDialog("Sign Out", isPresented: $showSignOutConfirm) {
                Button("Sign Out", role: .destructive) {
                    Task { await appState.signOut() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .task {
                if let userId = appState.currentUser?.id {
                    await insightsVM.fetchInsights(userId: userId)
                }
            }
        }
    }

    @ViewBuilder
    var avatarView: some View {
        if let urlString = appState.currentUser?.avatarURL,
           let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 90, height: 90)
                        .clipShape(Circle())
                default:
                    defaultAvatar
                }
            }
        } else {
            defaultAvatar
        }
    }

    var defaultAvatar: some View {
        Image(systemName: "person.circle.fill")
            .font(.system(size: 90))
            .foregroundStyle(themeManager.currentTheme.gradient)
    }

    func uploadAvatar(data: Data) async {
        guard let userId = appState.currentUser?.id else { return }
        isUploadingAvatar = true
        errorMessage = nil
        do {
            let path = "\(userId.uuidString)/avatar.jpg"
            try await supabase.storage
                .from("avatars")
                .upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
            let publicURL = try supabase.storage
                .from("avatars")
                .getPublicURL(path: path)
            try await supabase
                .from("profiles")
                .update(["avatar_url": publicURL.absoluteString])
                .eq("id", value: userId.uuidString)
                .execute()
            await appState.fetchProfile(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isUploadingAvatar = false
    }

    func saveDisplayName() async {
        isLoading = true
        errorMessage = nil
        do {
            guard let userId = appState.currentUser?.id else { return }
            try await supabase
                .from("profiles")
                .update(["display_name": newDisplayName])
                .eq("id", value: userId.uuidString)
                .execute()
            await appState.fetchProfile(userId: userId)
            isEditing = false
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Insights Grid

struct InsightsGridView: View {
    let vm: InsightsViewModel
    @EnvironmentObject private var themeManager: ThemeManager

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        if vm.isLoading {
            HStack {
                Spacer()
                ProgressView()
                    .tint(themeManager.currentTheme.primary)
                Spacer()
            }
            .padding()
        } else {
            LazyVGrid(columns: columns, spacing: 12) {
                InsightCard(
                    value: "\(vm.sessionsAttended)",
                    label: "Sessions\nAttended",
                    icon: "figure.run",
                    gradient: themeManager.currentTheme.gradient
                )
                InsightCard(
                    value: "\(vm.supplementsTaken)",
                    label: "Supplements\nLogged",
                    icon: "pills.fill",
                    gradient: themeManager.currentTheme.gradient
                )
                InsightCard(
                    value: "\(vm.longestCurrentStreak)",
                    label: "Longest\nStreak",
                    icon: "flame.fill",
                    gradient: themeManager.currentTheme.gradient
                )
                InsightCard(
                    value: vm.mostConsistentHabit ?? "—",
                    label: "Most\nConsistent",
                    icon: "star.fill",
                    gradient: themeManager.currentTheme.gradient,
                    isText: true
                )
            }
            .padding(12)
        }
    }
}

struct InsightCard: View {
    let value: String
    let label: String
    let icon: String
    let gradient: LinearGradient
    var isText: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(gradient)

            if isText {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            } else {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Text(label)
                .font(.caption)
                .foregroundStyle(Color.green.opacity(0.8))
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.6), lineWidth: 1.5)
                )
        )
    }
}
