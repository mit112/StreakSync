//
//  ReviewModeDurabilityTests.swift
//  StreakSync
//
//  Demo mode must not claim a durable write it never performed.
//

@testable import StreakSync
import XCTest

@MainActor
final class ReviewModeDurabilityTests: XCTestCase {
    /// Built per test rather than held in an implicitly unwrapped property — there is no
    /// shared setup worth the `!`.
    private func makeAppState() -> AppState {
        AppState(persistenceService: MockPersistenceService())
    }

    /// `NotificationCoordinator` releases a result from the App Group queue **only** when
    /// `saveGameResultsConfirmingDurability()` returns true. Demo mode persists nothing, so
    /// returning true acknowledged a write that never happened: a real result shared while
    /// demo data was on screen was dropped from the queue and gone at the next launch.
    /// That is precisely the clearing-before-persist loss the method's contract exists to
    /// prevent.
    func testReviewModeDoesNotClaimDurability() async {
        let appState = makeAppState()
        appState.reviewModeEnabled = true

        let durable = await appState.saveGameResultsConfirmingDurability()

        XCTAssertFalse(
            durable,
            "Demo mode writes nothing — claiming durability lets the caller drop the result from the queue"
        )
    }

    /// Null control. Without this, the assertion above would also pass against an
    /// implementation that reported failure unconditionally (or a broken mock), which would
    /// make it vacuous.
    func testNormalModeStillClaimsDurability() async {
        let appState = makeAppState()
        XCTAssertFalse(appState.reviewModeEnabled, "Precondition: not in demo mode")

        let durable = await appState.saveGameResultsConfirmingDurability()

        XCTAssertTrue(durable, "A real save must still confirm durability, or results would requeue forever")
    }

    /// Guest Mode is deliberately the opposite and must stay that way: a guest session's
    /// results are ephemeral by design, so acknowledging them is correct. Pinned so the
    /// demo-mode change above doesn't get copied down here by a future reader.
    func testGuestModeStillClaimsDurabilityOnPurpose() async {
        let appState = makeAppState()
        appState.isGuestMode = true

        let durable = await appState.saveGameResultsConfirmingDurability()

        XCTAssertTrue(durable, "Guest results are intentionally ephemeral; requeueing would resurrect a guest's data")
    }
}
