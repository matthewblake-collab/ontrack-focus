import Foundation

enum AppGroupStore {
    static let id = "group.com.blakeMatt.OnTrack"
    static var defaults: UserDefaults? { UserDefaults(suiteName: id) }
}

struct ReadinessSnapshot: Codable {
    let score: Int
    let computedAt: Date
    let nextIncompleteItemName: String?
    let breakdown: [String: Double]

    private static let key = "readiness.snapshot.v1"

    static func load() -> ReadinessSnapshot? {
        guard let data = AppGroupStore.defaults?.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(ReadinessSnapshot.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        AppGroupStore.defaults?.set(data, forKey: Self.key)
    }

    var tier: String {
        switch score {
        case ..<40: return "low"
        case 40..<70: return "moderate"
        default: return "high"
        }
    }

    var sentence: String {
        guard !breakdown.isEmpty else { return "Not enough data yet — log a check-in to start." }
        let labels: [String: String] = [
            "sleep": "Sleep", "hrv": "HRV", "rhr": "Resting HR",
            "checkin": "Check-in", "attendance": "Attendance", "workout": "Recent workout"
        ]
        let sorted = breakdown.sorted { $0.value > $1.value }
        let strongestKey = sorted.first?.key ?? ""
        let weakestKey = sorted.last?.key ?? ""
        let strongest = labels[strongestKey] ?? strongestKey
        let weakest = labels[weakestKey] ?? weakestKey
        if strongestKey == weakestKey {
            return "\(strongest) carrying the score — recovery \(tier)."
        }
        return "\(strongest) strong; \(weakest.lowercased()) weaker — recovery \(tier)."
    }
}
