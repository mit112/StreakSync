//
//  PendingSaveStore.swift
//  StreakSync
//
//  Stores pending (failed-to-save) persistence keys in Keychain.
//  On retry, the current in-memory state is re-saved for each key.
//

import Foundation
import OSLog

struct PendingSaveItem: Codable, Sendable, Equatable {
    let key: String
    var retryCount: Int
    let enqueuedAt: Date
}

struct PendingSaveStore: Sendable {
    private static let keychainKey = "persistence_pending_saves"
    static let maxRetries = 3

    private static let logger = Logger(
        subsystem: "com.streaksync.app",
        category: "PendingSaveStore"
    )

    func loadPendingItems() -> [PendingSaveItem] {
        if let items = KeychainService.loadCodable(
            [PendingSaveItem].self,
            forKey: Self.keychainKey
        ) {
            return items
        }
        return []
    }

    func savePendingItems(_ items: [PendingSaveItem]) {
        if items.isEmpty {
            KeychainService.delete(forKey: Self.keychainKey)
        } else {
            _ = KeychainService.saveCodable(items, forKey: Self.keychainKey)
        }
    }

    func enqueue(key: String) {
        var items = loadPendingItems()

        // Don't duplicate — if the key is already queued, leave it
        if items.contains(where: { $0.key == key }) {
            Self.logger.debug("Key '\(key)' already in pending save queue")
            return
        }

        let item = PendingSaveItem(
            key: key,
            retryCount: 0,
            enqueuedAt: Date()
        )
        items.append(item)
        savePendingItems(items)
        Self.logger.info("Enqueued pending save for key '\(key)'")
    }

}
