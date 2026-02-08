/*
 * Conversation Storage Service
 * Conversation record persistence service
 */

import Foundation

class ConversationStorage {
    static let shared = ConversationStorage()

    private let userDefaults = UserDefaults.standard
    private let conversationsKey = "savedConversations"
    private let maxConversations = 100 // Save up to 100 conversations

    private init() {}

    // MARK: - Save Conversation

    func saveConversation(_ record: ConversationRecord) {
        var conversations = loadAllConversations()

        // Add new conversation at the beginning
        conversations.insert(record, at: 0)

        // Keep only the most recent maxConversations
        if conversations.count > maxConversations {
            conversations = Array(conversations.prefix(maxConversations))
        }

        // Encode and save
        if let encoded = try? JSONEncoder().encode(conversations) {
            userDefaults.set(encoded, forKey: conversationsKey)
            print("💾 [Storage] Conversation saved: \(record.id), total: \(conversations.count)")
        } else {
            print("❌ [Storage] Failed to save conversation")
        }
    }

    // MARK: - Load Conversations

    func loadAllConversations() -> [ConversationRecord] {
        guard let data = userDefaults.data(forKey: conversationsKey),
              let conversations = try? JSONDecoder().decode([ConversationRecord].self, from: data) else {
            print("📂 [Storage] No conversation records or decoding failed")
            return []
        }

        print("📂 [Storage] Conversations loaded: \(conversations.count) records")
        return conversations
    }

    func loadConversations(limit: Int = 20, offset: Int = 0) -> [ConversationRecord] {
        let allConversations = loadAllConversations()
        let endIndex = min(offset + limit, allConversations.count)

        guard offset < allConversations.count else {
            return []
        }

        return Array(allConversations[offset..<endIndex])
    }

    // MARK: - Delete Conversation

    func deleteConversation(_ id: UUID) {
        var conversations = loadAllConversations()
        conversations.removeAll { $0.id == id }

        if let encoded = try? JSONEncoder().encode(conversations) {
            userDefaults.set(encoded, forKey: conversationsKey)
            print("🗑️ [Storage] Conversation deleted: \(id)")
        }
    }

    func deleteAllConversations() {
        userDefaults.removeObject(forKey: conversationsKey)
        print("🗑️ [Storage] All conversations cleared")
    }

    // MARK: - Get Conversation

    func getConversation(by id: UUID) -> ConversationRecord? {
        return loadAllConversations().first { $0.id == id }
    }
}
