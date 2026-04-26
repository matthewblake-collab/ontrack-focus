import Foundation
import Supabase

@Observable
final class RSVPViewModel {
    var rsvps: [RSVP] = []
    var myRSVP: RSVP? = nil
    var rsvpNameMap: [UUID: String] = [:]
    var isLoading: Bool = false
    var errorMessage: String? = nil

    var goingCount: Int { rsvps.filter { $0.status == "going" }.count }
    var notGoingCount: Int { rsvps.filter { $0.status == "not_going" }.count }
    var maybeCount: Int { rsvps.filter { $0.status == "maybe" }.count }

    func fetchRSVPs(sessionId: UUID, userId: UUID) async {
        isLoading = true
        errorMessage = nil
        do {
            let result: [RSVP] = try await supabase
                .from("rsvps")
                .select()
                .eq("session_id", value: sessionId.uuidString)
                .execute()
                .value
            self.rsvps = result
            self.myRSVP = result.first { $0.userId == userId }
            // Batch-fetch display names for all RSVP'd users
            let userIds = result.map { $0.userId.uuidString }
            if !userIds.isEmpty {
                struct ProfileName: Decodable {
                    let id: UUID
                    let displayName: String?
                    enum CodingKeys: String, CodingKey {
                        case id
                        case displayName = "display_name"
                    }
                }
                let profiles: [ProfileName] = (try? await supabase
                    .from("profiles")
                    .select("id, display_name")
                    .in("id", values: userIds)
                    .execute()
                    .value) ?? []
                self.rsvpNameMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0.displayName ?? "Unknown") })
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func upsertRSVP(sessionId: UUID, userId: UUID, status: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let result: RSVP = try await supabase
                .from("rsvps")
                .upsert([
                    "session_id": sessionId.uuidString,
                    "user_id": userId.uuidString,
                    "status": status,
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ], onConflict: "session_id,user_id")
                .select()
                .single()
                .execute()
                .value
            self.myRSVP = result
            AnalyticsManager.shared.track(.sessionRsvp, properties: ["status": status])
            await fetchRSVPs(sessionId: sessionId, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
