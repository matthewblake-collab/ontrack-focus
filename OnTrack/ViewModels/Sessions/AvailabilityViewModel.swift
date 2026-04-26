import Foundation
import Supabase

@Observable
final class AvailabilityViewModel {
    var windows: [AvailabilityWindow] = []
    var myWindows: [AvailabilityWindow] = []
    var isLoading: Bool = false
    var errorMessage: String? = nil
    var newStartsAt: Date = Date()
    var newEndsAt: Date = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()

    func fetchWindows(sessionId: UUID, userId: UUID) async {
        isLoading = true
        errorMessage = nil
        do {
            let result: [AvailabilityWindow] = try await supabase
                .from("availability_windows")
                .select()
                .eq("session_id", value: sessionId.uuidString)
                .execute()
                .value
            self.windows = result
            self.myWindows = result.filter { $0.userId == userId }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func addWindow(sessionId: UUID, userId: UUID) async {
        isLoading = true
        errorMessage = nil
        do {
            let _: AvailabilityWindow = try await supabase
                .from("availability_windows")
                .insert([
                    "session_id": sessionId.uuidString,
                    "user_id": userId.uuidString,
                    "starts_at": ISO8601DateFormatter().string(from: newStartsAt),
                    "ends_at": ISO8601DateFormatter().string(from: newEndsAt)
                ])
                .select()
                .single()
                .execute()
                .value
            await fetchWindows(sessionId: sessionId, userId: userId)
            newStartsAt = Date()
            newEndsAt = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func deleteWindow(windowId: UUID, sessionId: UUID, userId: UUID) async {
        isLoading = true
        errorMessage = nil
        do {
            try await supabase
                .from("availability_windows")
                .delete()
                .eq("id", value: windowId.uuidString)
                .execute()
            await fetchWindows(sessionId: sessionId, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func membersAvailableCount(at date: Date) -> Int {
        let uniqueUsers = Set(windows.filter { $0.startsAt <= date && $0.endsAt >= date }.map { $0.userId })
        return uniqueUsers.count
    }
}
