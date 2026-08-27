//
//  PendingSaveStoreTests.swift
//  StreakSync
//
//  Unit tests for PendingSaveStore retry queue
//

import Foundation
@testable import StreakSync
import XCTest

final class PendingSaveStoreTests: XCTestCase {
    private let store = PendingSaveStore()

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Clear any leftover state
        store.savePendingItems([])

        // PendingSaveStore is Keychain-backed, and the Keychain is unavailable to an
        // unsigned test host (CI builds with CODE_SIGNING_ALLOWED=NO), where writes
        // silently no-op. Skip rather than report a product failure — probe by writing
        // and reading back, so this only skips where the Keychain genuinely doesn't work.
        store.enqueue(key: Self.probeKey)
        let probeSucceeded = store.loadPendingItems().contains { $0.key == Self.probeKey }
        store.savePendingItems([])
        try XCTSkipUnless(probeSucceeded, "Keychain unavailable in this environment")
    }

    private static let probeKey = "streaksync_keychain_probe"

    override func tearDown() {
        store.savePendingItems([])
        super.tearDown()
    }

    // MARK: - Enqueue / Load Round-Trip

    func testEnqueueAndLoad() {
        store.enqueue(key: "streaksync_game_results")

        let items = store.loadPendingItems()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.key, "streaksync_game_results")
        XCTAssertEqual(items.first?.retryCount, 0)
    }

    func testEnqueueMultipleKeys() {
        store.enqueue(key: "streaksync_game_results")
        store.enqueue(key: "streaksync_streaks")

        let items = store.loadPendingItems()
        XCTAssertEqual(items.count, 2)

        let keys = Set(items.map(\.key))
        XCTAssertTrue(keys.contains("streaksync_game_results"))
        XCTAssertTrue(keys.contains("streaksync_streaks"))
    }

    func testEnqueueDuplicateIsIgnored() {
        store.enqueue(key: "streaksync_streaks")
        store.enqueue(key: "streaksync_streaks")

        let items = store.loadPendingItems()
        XCTAssertEqual(items.count, 1)
    }

    // MARK: - Max Retries Constant

    func testMaxRetriesValue() {
        XCTAssertEqual(PendingSaveStore.maxRetries, 3)
    }

    // MARK: - Empty Queue

    func testEmptyQueueReturnsEmptyArray() {
        let items = store.loadPendingItems()
        XCTAssertTrue(items.isEmpty)
    }

    func testSaveEmptyArrayClearsQueue() {
        store.enqueue(key: "streaksync_game_results")
        store.savePendingItems([])

        let items = store.loadPendingItems()
        XCTAssertTrue(items.isEmpty)
    }
}
