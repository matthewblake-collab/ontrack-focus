import Foundation
import Supabase

@Observable
final class CommentViewModel {
    var comments: [Comment] = []
    var profiles: [Profile] = []
    var isLoading: Bool = false
    var errorMessage: String? = nil
    var newComment: String = ""

    func fetchComments(sessionId: UUID) async {
        isLoading = true
        errorMessage = nil
        do {
            let fetchedComments: [Comment] = try await supabase
                .from("comments")
                .select()
                .eq("session_id", value: sessionId.uuidString)
                .order("created_at", ascending: true)
                .execute()
                .value
            self.comments = fetchedComments

            let userIds = Array(Set(fetchedComments.map { $0.userId.uuidString }))
            if !userIds.isEmpty {
                let fetchedProfiles: [Profile] = try await supabase
                    .from("profiles")
                    .select()
                    .in("id", values: userIds)
                    .execute()
                    .value
                self.profiles = fetchedProfiles
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func addComment(sessionId: UUID, userId: UUID) async {
        guard !newComment.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        errorMessage = nil
        do {
            let _: Comment = try await supabase
                .from("comments")
                .insert([
                    "session_id": sessionId.uuidString,
                    "user_id": userId.uuidString,
                    "content": newComment.trimmingCharacters(in: .whitespaces)
                ])
                .select()
                .single()
                .execute()
                .value
            newComment = ""
            await fetchComments(sessionId: sessionId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteComment(commentId: UUID, sessionId: UUID) async {
        errorMessage = nil
        do {
            try await supabase
                .from("comments")
                .delete()
                .eq("id", value: commentId.uuidString)
                .execute()
            await fetchComments(sessionId: sessionId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func profileName(for userId: UUID) -> String {
        profiles.first { $0.id == userId }?.displayName ?? "Unknown"
    }
}
