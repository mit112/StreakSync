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

    /// The lifetime active-days set is monotonic, so a demo day that reaches disk is
    /// permanent — it would count toward Marathon Runner forever.
    func testReviewModeDoesNotPersistActiveDays() async {
        let persistence = MockPersistenceService()
        let appState = AppState(persistenceService: persistence)
        appState.reviewModeEnabled = true

        appState._activeDaysEver = [Calendar.current.startOfDay(for: Date())]
        await appState.saveActiveDaysEver()

        XCTAssertNil(
            persistence.load(Set<Date>.self, forKey: AppState.activeDaysEverKey),
            "Demo mode must not write the lifetime active-days set"
        )
    }

    /// `loadPersistedData()` never touches the lazy lifetime caches, so without an explicit
    /// reset, demo days folded in during Review Mode (e.g. by a delete's reconcile) outlive
    /// it and get written by the next real result.
    func testExitingReviewModeDropsDemoLifetimeSets() async {
        let appState = makeAppState()
        await appState.activateReviewMode()
        appState.recordActiveDays(from: appState.recentResults)
        appState.recordUniqueGames(from: appState.recentResults)
        XCTAssertFalse(appState.activeDaysEver.isEmpty, "Precondition: demo days were folded in")

        await appState.exitReviewMode()

        XCTAssertTrue(appState.activeDaysEver.isEmpty, "Demo days must not survive exiting Review Mode")
        XCTAssertTrue(appState.uniqueGamesEver.isEmpty, "Demo games must not survive exiting Review Mode")
    }

    /// Tiers only ever rise, so demo progress left in the cache would be kept by the exit
    /// reload's recompute and then saved as the user's own.
    func testExitingReviewModeDropsDemoAchievementProgress() async {
        let appState = makeAppState()
        await appState.activateReviewMode()
        let demoTier = appState.tieredAchievements.first { $0.category == .streakMaster }?.progress.currentTier
        XCTAssertNotNil(demoTier, "Precondition: the 14-day demo streak earns a Streak Master tier")

        await appState.exitReviewMode()

        let realTier = appState.tieredAchievements.first { $0.category == .streakMaster }?.progress.currentTier
        XCTAssertNil(realTier, "Demo Streak Master progress survived exiting Review Mode")
    }
}
