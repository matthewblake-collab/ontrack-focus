import SwiftUI

struct FeedView: View {
    @Bindable var vm: FeedViewModel
    let friendIDs: [String]
    let currentUserID: String
    let currentUserDisplayName: String
    let friendCode: String

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showFriendCode = false

    var body: some View {
        ZStack(alignment: .top) {

            if vm.isLoading {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.feedItems.isEmpty {
                VStack(spacing: 24) {
                    Spacer()
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.white.opacity(0.25))
                    VStack(spacing: 8) {
                        Text("No activity yet")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                        Text("Invite friends to see their sessions\nand streaks here.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                    }
                    VStack(spacing: 12) {
                        Button {
                            showFriendCode = true
                        } label: {
                            Label("Share Friend Code", systemImage: "person.badge.plus")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(red: 0.08, green: 0.35, blue: 0.45))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        Button {
                            let text = friendCode.isEmpty
                                ? "Join me on OnTrack Focus 💪\nhttps://apps.apple.com/app/id6760957657"
                                : "Join me on OnTrack Focus! Use my friend code \(friendCode) to add me when you sign up 💪\nhttps://apps.apple.com/app/id6760957657"
                            let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
                            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let window = scene.windows.first,
                               let root = window.rootViewController {
                                root.present(av, animated: true)
                            }
                        } label: {
                            Label("Invite via Messages", systemImage: "message.fill")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(.horizontal, 32)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(vm.feedItems) { item in
                            itemCard(item)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
        }
        .task {
            await vm.fetchFeed(friendIDs: friendIDs, currentUserID: currentUserID)
        }
        .sheet(isPresented: $showFriendCode) {
            FriendCodeSheet(code: friendCode)
        }
    }

    // MARK: - Card

    @ViewBuilder
    private func itemCard(_ item: FeedItem) -> some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.ownerName)
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(.white)
                switch item.type {
                case .session:
                    Text(formattedSessionLine(item))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                case .streak:
                    Text("🔥 \(item.streakCount ?? 0) day streak")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                case .habitLog:
                    Text("✅ Completed \(item.habitName ?? "a habit")")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                case .personalBest:
                    Text("🏆 New PB: \(item.pbEventName ?? "Personal Best") · \(formattedPBValue(item))")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            Spacer()
            HStack(spacing: 10) {
                if item.type == .session && item.isPublicSession {
                    Button {
                        Task {
                            await vm.joinSession(item: item, currentUserID: currentUserID,
                                                 currentUserDisplayName: currentUserDisplayName)
                        }
                    } label: {
                        Text("Join")
                            .font(.caption)
                            .foregroundColor(Color(red: 0.15, green: 0.55, blue: 0.38))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(red: 0.15, green: 0.55, blue: 0.38), lineWidth: 1)
                            )
                    }
                }
                if item.type != .personalBest {
                    Button {
                        Task {
                            await vm.toggleLike(item: item, currentUserID: currentUserID,
                                                currentUserDisplayName: currentUserDisplayName)
                        }
                    } label: {
                        Image(systemName: vm.likedItemIDs.contains(item.id) ? "heart.fill" : "heart")
                            .foregroundColor(
                                vm.likedItemIDs.contains(item.id)
                                    ? Color(red: 0.15, green: 0.55, blue: 0.38)
                                    : .white.opacity(0.5)
                            )
                            .font(.system(size: 16))
                    }
                }
            }
        }
        .padding(12)
        .background(
            Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92)
                .cornerRadius(12)
        )
    }

    // MARK: - Helpers

    private func formattedPBValue(_ item: FeedItem) -> String {
        guard let value = item.pbValue, let unit = item.pbValueUnit else { return "" }
        return "\(Int(value))\(unit)"
    }

    private func formattedSessionLine(_ item: FeedItem) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        switch (item.sessionTitle, item.sessionTime) {
        case let (.some(title), .some(time)):
            return "\(title) · \(fmt.string(from: time))"
        case let (.some(title), .none):
            return title
        case let (.none, .some(time)):
            return fmt.string(from: time)
        default:
            return ""
        }
    }
}
