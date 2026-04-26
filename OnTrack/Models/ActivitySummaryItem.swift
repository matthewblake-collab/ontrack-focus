import Foundation

struct ActivitySummaryItem: Identifiable {
    let id: String
    let actorName: String
    let action: String
    let targetTitle: String
    let happenedAt: Date
}
