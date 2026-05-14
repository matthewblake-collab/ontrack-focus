import Foundation
import Supabase

@Observable
final class ProtocolViewModel {
    var activeProtocol: UserProtocol? = nil
    var isLoading: Bool = false
    var errorMessage: String? = nil

    func loadActive(userId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let results: [UserProtocol] = try await supabase
                .from("user_protocols")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("is_active", value: true)
                .limit(1)
                .execute().value
            activeProtocol = results.first
        } catch {
            errorMessage = error.localizedDescription
            print("[ProtocolVM] loadActive error: \(error)")
        }
    }

    /// Atomically deactivates the current active protocol (if any) and inserts the new one.
    /// Returns true on success.
    @discardableResult
    func save(
        userId: UUID,
        protocolType: String,
        protocolName: String,
        startDate: Date,
        endDate: Date?,
        goal: String?,
        notes: String?
    ) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")

        do {
            try await supabase
                .from("user_protocols")
                .update(UserProtocolDeactivate())
                .eq("user_id", value: userId.uuidString)
                .eq("is_active", value: true)
                .execute()

            let row = UserProtocolInsert(
                userId: userId,
                protocolType: protocolType,
                protocolName: protocolName,
                startDate: f.string(from: startDate),
                endDate: endDate.map { f.string(from: $0) },
                goal: goal,
                notes: notes,
                isActive: true
            )
            try await supabase
                .from("user_protocols")
                .insert(row)
                .execute()

            await loadActive(userId: userId)
            return true
        } catch {
            errorMessage = error.localizedDescription
            print("[ProtocolVM] save error: \(error)")
            return false
        }
    }

    func endActive(userId: UUID) async {
        do {
            try await supabase
                .from("user_protocols")
                .update(UserProtocolDeactivate())
                .eq("user_id", value: userId.uuidString)
                .eq("is_active", value: true)
                .execute()
            activeProtocol = nil
        } catch {
            print("[ProtocolVM] endActive error: \(error)")
        }
    }
}
