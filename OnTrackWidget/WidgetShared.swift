import Foundation
import SwiftUI

enum WidgetAppGroup {
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
        guard let data = WidgetAppGroup.defaults?.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(ReadinessSnapshot.self, from: data)
    }

    var tier: String {
        switch score {
        case ..<40: return "low"
        case 40..<70: return "moderate"
        default: return "high"
        }
    }

    var ringColor: Color {
        switch score {
        case ..<40: return Color.red.opacity(0.85)
        case 40..<70: return Color.orange.opacity(0.85)
        default: return Color.green.opacity(0.85)
        }
    }

    var isStale: Bool {
        Date().timeIntervalSince(computedAt) > 6 * 60 * 60
    }
}
