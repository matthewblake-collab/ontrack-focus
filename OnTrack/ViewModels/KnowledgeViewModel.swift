import Foundation
import Observation
import Supabase

@Observable
final class KnowledgeViewModel {
    var items: [KnowledgeItem] = []
    var savedItemIds: Set<UUID> = []
    var protocols: [KnowledgeProtocol] = []
    var selectedProtocolCategory: String? = nil
    var isLoading = false
    var errorMessage: String?

    func fetchAll(category: String? = nil) async {
        isLoading = true
        errorMessage = nil
        do {
            let result: [KnowledgeItem]
            if let category, category != "All" {
                result = try await supabase
                    .from("knowledge_items")
                    .select()
                    .eq("is_published", value: true)
                    .eq("category", value: category)
                    .order("title", ascending: true)
                    .execute()
                    .value
            } else {
                result = try await supabase
                    .from("knowledge_items")
                    .select()
                    .eq("is_published", value: true)
                    .order("title", ascending: true)
                    .execute()
                    .value
            }
            self.items = result
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func fetchProtocols(category: String? = nil) async {
        isLoading = true
        do {
            let result: [KnowledgeProtocol]
            if let category {
                result = try await supabase
                    .from("knowledge_protocols")
                    .select()
                    .eq("is_published", value: true)
                    .eq("category", value: category)
                    .order("title", ascending: true)
                    .execute()
                    .value
            } else {
                result = try await supabase
                    .from("knowledge_protocols")
                    .select()
                    .eq("is_published", value: true)
                    .order("category", ascending: true)
                    .execute()
                    .value
            }
            self.protocols = result
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func searchItems(query searchQuery: String) async {
        guard !searchQuery.isEmpty else {
            await fetchAll()
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            let result: [KnowledgeItem] = try await supabase
                .from("knowledge_items")
                .select()
                .eq("is_published", value: true)
                .ilike("title", pattern: "%\(searchQuery)%")
                .order("title", ascending: true)
                .execute()
                .value
            self.items = result
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func fetchSaves(userId: UUID) async {
        do {
            struct SaveRow: Decodable {
                let itemId: UUID
                enum CodingKeys: String, CodingKey {
                    case itemId = "item_id"
                }
            }
            let rows: [SaveRow] = try await supabase
                .from("user_knowledge_saves")
                .select("item_id")
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value
            self.savedItemIds = Set(rows.map { $0.itemId })
        } catch {
            print("[KnowledgeVM] fetchSaves error: \(error)")
        }
    }

    func toggleSave(itemId: UUID, userId: UUID) async {
        if savedItemIds.contains(itemId) {
            savedItemIds.remove(itemId)
            do {
                try await supabase
                    .from("user_knowledge_saves")
                    .delete()
                    .eq("user_id", value: userId.uuidString)
                    .eq("item_id", value: itemId.uuidString)
                    .execute()
            } catch {
                savedItemIds.insert(itemId)
                print("[KnowledgeVM] unsave error: \(error)")
            }
        } else {
            savedItemIds.insert(itemId)
            do {
                try await supabase
                    .from("user_knowledge_saves")
                    .insert([
                        "user_id": userId.uuidString,
                        "item_id": itemId.uuidString
                    ])
                    .execute()
            } catch {
                savedItemIds.remove(itemId)
                print("[KnowledgeVM] save error: \(error)")
            }
        }
    }

    func fetchRelatedItems(for itemId: UUID) async -> [KnowledgeItem] {
        do {
            struct LinkRow: Decodable {
                let relatedItemId: UUID
                enum CodingKeys: String, CodingKey {
                    case relatedItemId = "related_item_id"
                }
            }
            let links: [LinkRow] = try await supabase
                .from("knowledge_item_links")
                .select("related_item_id")
                .eq("item_id", value: itemId.uuidString)
                .execute()
                .value
            guard !links.isEmpty else { return [] }
            let ids = links.map { $0.relatedItemId.uuidString }
            let related: [KnowledgeItem] = try await supabase
                .from("knowledge_items")
                .select()
                .eq("is_published", value: true)
                .in("id", values: ids)
                .execute()
                .value
            return related
        } catch {
            return []
        }
    }
}
