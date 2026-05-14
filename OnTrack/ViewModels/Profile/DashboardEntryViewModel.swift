import Foundation
import Supabase

/// Drives the Dashboard entry card in Profile: magic-link fetch via
/// the `generate-dashboard-magic-link` Edge Function, and the badge
/// count (unread partner offers + recent abnormal bloodwork).
@Observable
final class DashboardEntryViewModel {
    var isFetchingURL: Bool = false
    var dashboardURL: URL? = nil
    var errorMessage: String? = nil

    var unlockCount: Int = 0
    var abnormalBloodCount: Int = 0
    var badgeCount: Int { unlockCount + abnormalBloodCount }

    private struct MagicLinkResponse: Decodable { let url: String }
    private struct IDRow: Decodable { let id: UUID }
    private struct BloodMarkerSummary: Decodable {
        let value: Double?
        let referenceLow: Double?
        let referenceHigh: Double?
        enum CodingKeys: String, CodingKey {
            case value
            case referenceLow = "reference_low"
            case referenceHigh = "reference_high"
        }
    }

    /// Calls the Edge Function and stores the resulting URL.
    /// SwiftUI binding to dashboardURL then opens SFSafariViewController.
    func fetchMagicLink() async {
        isFetchingURL = true
        defer { isFetchingURL = false }
        errorMessage = nil
        do {
            let response: MagicLinkResponse = try await supabase.functions.invoke(
                "generate-dashboard-magic-link"
            )
            guard let url = URL(string: response.url) else {
                errorMessage = "Invalid URL returned from Edge Function."
                return
            }
            dashboardURL = url
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearMagicLink() {
        dashboardURL = nil
    }

    func loadBadge(userId: UUID) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadUnlockCount(userId: userId) }
            group.addTask { await self.loadAbnormalBloodCount(userId: userId) }
        }
    }

    private func loadUnlockCount(userId: UUID) async {
        do {
            let rows: [IDRow] = try await supabase
                .from("user_discount_unlocks")
                .select("id")
                .eq("user_id", value: userId.uuidString)
                .is("viewed_at", value: nil)
                .execute().value
            unlockCount = rows.count
        } catch {
            print("[DashboardEntryVM] unlock count error: \(error)")
        }
    }

    private func loadAbnormalBloodCount(userId: UUID) async {
        do {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime]
            let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            let cutoffStr = iso.string(from: cutoff)
            let rows: [BloodMarkerSummary] = try await supabase
                .from("blood_markers")
                .select("value, reference_low, reference_high")
                .eq("user_id", value: userId.uuidString)
                .gte("created_at", value: cutoffStr)
                .execute().value
            abnormalBloodCount = rows.filter { row in
                guard let v = row.value else { return false }
                if let lo = row.referenceLow, v < lo { return true }
                if let hi = row.referenceHigh, v > hi { return true }
                return false
            }.count
        } catch {
            print("[DashboardEntryVM] abnormal count error: \(error)")
        }
    }
}
