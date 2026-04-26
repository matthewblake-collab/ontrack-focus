import SwiftUI

struct CommentsView: View {
    let session: AppSession
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var viewModel = CommentViewModel()
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if viewModel.isLoading {
                            ProgressView()
                                .padding()
                        } else if viewModel.comments.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 50))
                                    .foregroundStyle(.secondary)
                                Text("No comments yet")
                                    .font(.headline)
                                Text("Be the first to leave a note")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 60)
                        } else {
                            ForEach(viewModel.comments) { comment in
                                CommentBubble(
                                    comment: comment,
                                    authorName: viewModel.profileName(for: comment.userId),
                                    isCurrentUser: comment.userId == appState.currentUser?.id
                                )
                                .id(comment.id)
                                .contextMenu {
                                    if comment.userId == appState.currentUser?.id {
                                        Button(role: .destructive) {
                                            Task {
                                                await viewModel.deleteComment(commentId: comment.id, sessionId: session.id)
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
                .background(themeManager.backgroundColour())
                .onChange(of: viewModel.comments.count) {
                    if let last = viewModel.comments.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            HStack(spacing: 12) {
                TextField("Add a comment...", text: $viewModel.newComment, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .focused($inputFocused)

                Button {
                    Task {
                        guard let userId = appState.currentUser?.id else { return }
                        await viewModel.addComment(sessionId: session.id, userId: userId)
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            viewModel.newComment.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Color.secondary
                            : Color(red: 0.08, green: 0.35, blue: 0.45)
                        )
                }
                .disabled(viewModel.newComment.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .navigationTitle("Comments")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.fetchComments(sessionId: session.id)
        }
    }
}

struct CommentBubble: View {
    let comment: Comment
    let authorName: String
    let isCurrentUser: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isCurrentUser { Spacer(minLength: 60) }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                if !isCurrentUser {
                    Text(authorName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }

                Text(comment.content)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        isCurrentUser
                        ? Color(red: 0.08, green: 0.35, blue: 0.45)
                        : Color(.systemGray5)
                    )
                    .foregroundStyle(isCurrentUser ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Text(comment.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }

            if !isCurrentUser { Spacer(minLength: 60) }
        }
    }
}
