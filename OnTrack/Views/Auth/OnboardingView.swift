import SwiftUI
import PhotosUI
import Supabase

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager

    @State private var currentPage = 0
    @State private var displayName = ""
    @State private var selectedGoals: Set<String> = []
    @State private var isLoading = false
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage? = nil
    @State private var pulseScale: CGFloat = 1.0

    private let goals = [
        "Build strength", "Improve sleep", "Track nutrition", "Build habits",
        "Stay accountable", "Improve wellness", "Team performance", "Lose weight"
    ]

    var body: some View {
        ZStack {
            themeManager.backgroundColour().ignoresSafeArea()

            VStack(spacing: 0) {
                // PROGRESS DOTS + SKIP
                HStack {
                    HStack(spacing: 8) {
                        ForEach(0..<4, id: \.self) { index in
                            Circle()
                                .fill(index <= currentPage ? themeManager.currentTheme.primary : Color(.systemGray4))
                                .frame(width: 8, height: 8)
                                .animation(.easeInOut, value: currentPage)
                        }
                    }
                    Spacer()
                    if currentPage == 1 || currentPage == 2 {
                        Button("Skip") {
                            withAnimation(.easeInOut) { currentPage = 3 }
                        }
                        .foregroundStyle(themeManager.currentTheme.primary)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 8)

                // PAGE CONTENT
                Group {
                    switch currentPage {
                    case 0: welcomePage
                    case 1: featuresPage
                    case 2: profilePage
                    case 3: goalsPage
                    default: EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity.combined(with: .move(edge: .trailing)))

                // NEXT / LET'S GO BUTTON
                Button {
                    if currentPage < 3 {
                        withAnimation(.easeInOut) { currentPage += 1 }
                    } else {
                        Task { await saveAndFinish() }
                    }
                } label: {
                    if isLoading {
                        ProgressView().tint(.white).frame(maxWidth: .infinity).padding()
                    } else {
                        Text(currentPage == 3 ? "Let's Go!" : "Next")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundStyle(.white)
                    }
                }
                .background(themeManager.currentTheme.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .disabled(isLoading)
                .padding()
            }
        }
        .onAppear {
            displayName = appState.currentUser?.displayName ?? ""
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage)
        }
    }

    // MARK: - Page 0: Welcome

    private var welcomePage: some View {
        VStack(spacing: 28) {
            Spacer()

            Circle()
                .fill(themeManager.currentTheme.primary)
                .frame(width: 120, height: 120)
                .overlay(
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.white)
                )
                .scaleEffect(pulseScale)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                        pulseScale = 1.08
                    }
                }

            VStack(spacing: 12) {
                Text("Welcome to OnTrack Focus")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text("Your all-in-one tracker for health, habits and team performance")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - Page 1: Features

    private var featuresPage: some View {
        VStack(spacing: 40) {
            Spacer()

            Text("Everything you need")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 24) {
                featureRow(
                    icon: "person.3.fill",
                    title: "Groups & Teams",
                    subtitle: "Schedule sessions, track attendance and chat with your crew"
                )
                featureRow(
                    icon: "checkmark.circle.fill",
                    title: "Habits & Supplements",
                    subtitle: "Build streaks and never run out of stock"
                )
                featureRow(
                    icon: "heart.text.square.fill",
                    title: "Daily Wellbeing",
                    subtitle: "Check in on sleep, energy and mood every day"
                )
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    // MARK: - Page 2: Profile Setup

    private var profilePage: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("Set up your profile")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button { showImagePicker = true } label: {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(themeManager.currentTheme.primary)
                        .frame(width: 100, height: 100)
                        .overlay(
                            Text(initials(from: displayName))
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        )
                }
            }

            TextField("Display name", text: $displayName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Page 3: Goals

    private var goalsPage: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text("What are your goals?")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                Text("Select all that apply")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32)

            ChipWrapView(items: goals, selected: $selectedGoals, themeManager: themeManager)
                .padding(.horizontal, 24)

            Spacer()
        }
    }

    // MARK: - Feature Row

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(themeManager.currentTheme.primary)
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Helpers

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first.map { String($0).uppercased() } }.joined()
    }

    // MARK: - Save

    private func saveAndFinish() async {
        guard let userId = appState.currentUser?.id else { return }
        isLoading = true

        do {
            let name = displayName.isEmpty ? (appState.currentUser?.displayName ?? "") : displayName
            let goalsList = Array(selectedGoals)

            if let image = selectedImage, let data = image.jpegData(compressionQuality: 0.8) {
                let path = "\(userId.uuidString)/avatar.jpg"
                try await supabase.storage
                    .from("avatars")
                    .upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
                let url = try supabase.storage
                    .from("avatars")
                    .getPublicURL(path: path)

                struct ProfileFullUpdate: Encodable {
                    let displayName: String
                    let goals: [String]
                    let avatarUrl: String
                    enum CodingKeys: String, CodingKey {
                        case displayName = "display_name"
                        case goals
                        case avatarUrl = "avatar_url"
                    }
                }
                try await supabase
                    .from("profiles")
                    .update(ProfileFullUpdate(displayName: name, goals: goalsList, avatarUrl: url.absoluteString))
                    .eq("id", value: userId.uuidString)
                    .execute()
            } else {
                struct ProfileBasicUpdate: Encodable {
                    let displayName: String
                    let goals: [String]
                    enum CodingKeys: String, CodingKey {
                        case displayName = "display_name"
                        case goals
                    }
                }
                try await supabase
                    .from("profiles")
                    .update(ProfileBasicUpdate(displayName: name, goals: goalsList))
                    .eq("id", value: userId.uuidString)
                    .execute()
            }

            await appState.fetchProfile(userId: userId)
            appState.completeOnboarding()

            // Welcome friendship via SECURITY DEFINER function (bypasses RLS correctly)
            let mattId = "d4513d7c-0acc-4917-83b3-cb350a09a5f7"
            if userId.uuidString.lowercased() != mattId {
                try? await supabase
                    .rpc("create_welcome_friendship", params: ["new_user_id": userId.uuidString.lowercased()])
                    .execute()
            }

            // Generate friend code immediately so it exists before the user hits the Friends tab
            let existingCodes: [FriendCode] = (try? await supabase
                .from("friend_codes")
                .select()
                .eq("user_id", value: userId.uuidString.lowercased())
                .execute()
                .value) ?? []
            if existingCodes.isEmpty {
                let newCode = String((0..<6).map { _ in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()! })
                try? await supabase
                    .from("friend_codes")
                    .insert(NewFriendCode(userId: userId.uuidString.lowercased(), code: newCode))
                    .execute()
            }
        } catch {
            print("[Onboarding] Save failed: \(error)")
        }

        isLoading = false
    }
}

// MARK: - Chip Wrap Layout

struct ChipWrapView: View {
    let items: [String]
    @Binding var selected: Set<String>
    let themeManager: ThemeManager

    var body: some View {
        FlowLayout(spacing: 10) {
            ForEach(items, id: \.self) { item in
                let isSelected = selected.contains(item)
                Button {
                    if isSelected { selected.remove(item) } else { selected.insert(item) }
                } label: {
                    Text(item)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(isSelected ? themeManager.currentTheme.primary : Color(.systemGray5))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.15), value: isSelected)
            }
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { image, _ in
                DispatchQueue.main.async {
                    self.parent.image = image as? UIImage
                }
            }
        }
    }
}
