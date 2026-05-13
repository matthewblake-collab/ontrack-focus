import Foundation

struct ReadinessInputs {
    let sleepHours: Double?
    let hrvMs: Double?
    let rhrBpm: Double?
    let checkinAvg: Double?
    let attendance7dCount: Int
    let workoutLast12h: Bool

    private static let weights: [String: Double] = [
        "sleep": 30, "hrv": 20, "rhr": 15, "checkin": 20, "attendance": 10, "workout": 5
    ]

    func computeScore() -> (Int, [String: Double]) {
        var subscores: [String: Double] = [:]

        if let h = sleepHours {
            let s: Double
            switch h {
            case ..<4: s = 20
            case 4..<6: s = 40 + (h - 4) * 15
            case 6..<7: s = 70 + (h - 6) * 15
            case 7..<9: s = 100
            case 9..<10: s = 90
            default: s = 80
            }
            subscores["sleep"] = min(100, max(0, s))
        }

        if let v = hrvMs {
            subscores["hrv"] = min(100, max(0, v / 60 * 100))
        }

        if let r = rhrBpm {
            subscores["rhr"] = min(100, max(0, 100 - (r - 40) * 2.5))
        }

        if let c = checkinAvg {
            subscores["checkin"] = min(100, max(0, c * 10))
        }

        subscores["attendance"] = min(100, Double(attendance7dCount) / 4 * 100)
        subscores["workout"] = workoutLast12h ? 100 : 0

        var weightedSum: Double = 0
        var weightTotal: Double = 0
        var contributions: [String: Double] = [:]

        for (key, sub) in subscores {
            guard let w = Self.weights[key] else { continue }
            weightedSum += sub * w
            weightTotal += w
            contributions[key] = sub * w
        }

        let score = weightTotal > 0 ? Int((weightedSum / weightTotal).rounded()) : 0
        return (score, contributions)
    }
}
