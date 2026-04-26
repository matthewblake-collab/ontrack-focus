import Foundation

struct KnowledgeItem: Codable, Identifiable {
    let id: UUID
    let category: String
    let title: String
    let subtitle: String?
    let description: String
    let benefits: [String]?
    let dosage: String?
    let duration: String?
    let difficulty: String?
    let tags: [String]?
    let imageUrl: String?
    let sources: [String]?
    let isPublished: Bool
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, category, title, subtitle, description
        case benefits, dosage, duration, difficulty, tags
        case imageUrl = "image_url"
        case sources
        case isPublished = "is_published"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct KnowledgeItemLink: Codable, Identifiable {
    let id: UUID
    let itemId: UUID
    let relatedItemId: UUID

    enum CodingKeys: String, CodingKey {
        case id
        case itemId = "item_id"
        case relatedItemId = "related_item_id"
    }
}

struct UserKnowledgeSave: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let itemId: UUID
    let savedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case itemId = "item_id"
        case savedAt = "saved_at"
    }
}

struct ProtocolPhase: Codable, Identifiable {
    var id: String { name }
    let name: String
    let dose: String
    let frequency: String
    let duration: String
    let notes: String?
}

struct KnowledgeProtocol: Codable, Identifiable {
    let id: UUID
    let title: String
    let compound: String
    let category: String
    let goal: String?
    let overview: String?
    let phases: [ProtocolPhase]?
    let bacWaterRatio: String?
    let storage: String?
    let halfLife: String?
    let stackWith: [String]?
    let warnings: [String]?
    let isPublished: Bool

    enum CodingKeys: String, CodingKey {
        case id, title, compound, category, goal, overview, phases
        case bacWaterRatio = "bac_water_ratio"
        case storage
        case halfLife = "half_life"
        case stackWith = "stack_with"
        case warnings
        case isPublished = "is_published"
    }
}
