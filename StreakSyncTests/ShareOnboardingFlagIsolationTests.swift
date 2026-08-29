//
//  ShareOnboardingFlagIsolationTests.swift
//  StreakSyncTests
//
//  Tests that the share-discovery sheet and the first-share celebration own separate flags.
//

@testable import StreakSync
import XCTest

/// `Features/Onboarding` has two independent one-shot surfaces: the `ShareDiscoverySheet`
/// (gated on `hasSeenShareOnboarding`, written by ImprovedDashboardView's sheet `onDismiss`)
/// and the `FirstShareCelebrationOverlay` (gated on `hasSeenFirstShareCelebration`, written by
/// `AppState.addGameResult`). Seeing one must never consume the other. The pure gate maths is
/// already covered by ShareDiscoveryGateTests; this file covers the two flags' wiring.
/// Thread-safe counter for the celebration notification.
///
/// `addObserver(forName:object:queue:using:)` declares its block `NS_SWIFT_SENDABLE`,
/// so it can neither capture the non-Sendable `XCTestCase` nor mutate its `@MainActor`
/// stored properties. The closure captures this reference type by value instead.
private final class CelebrationCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func increment() {
        lock.lock()
        value += 1
        lock.unlock()
    }

    func reset() {
        lock.lock()
        value = 0
        lock.unlock()
    }
}

@MainActor
final class ShareOnboardingFlagIsolationTests: XCTestCase {
    private var observer: (any NSObjectProtocol)?
    private let celebrationCounter = CelebrationCounter()

    override func setUp() async throws {
        try await super.setUp()
        clearOnboardingFlags()
        celebrationCounter.reset()
        observer = NotificationCenter.default.addObserver(
            forName: .appFirstShareCelebrationRequested,
            object: nil,
            queue: nil
        ) { [celebrationCounter] _ in
            celebrationCounter.increment()
        }
    }

    override func tearDown() async throws {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        clearOnboardingFlags()
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func clearOnboardingFlags() {
        UserDefaults.standard.removeObject(forKey: AppConstants.Onboarding.hasSeenShareOnboarding)
        UserDefaults.standard.removeObject(forKey: AppConstants.Onboarding.hasSeenFirstShareCelebration)
    }

    private func makeAppState() -> AppState {
        let appState = AppState(persistenceService: MockPersistenceService())
        appState._tieredAchievements = AchievementFactory.createDefaultAchievements()
        return appState
    }

    private func makeWordleResult() -> GameResult {
        GameResult(
            gameId: Game.wordle.id,
            gameName: Game.Names.wordle,
            date: Date(),
            score: 3,
            maxAttempts: 6,
            completed: true,
            sharedText: "Wordle 1,234 3/6",
            parsedData: ["puzzleNumber": "1234"]
        )
    }

    private func makeConnectionsResult() -> GameResult {
        GameResult(
            gameId: Game.connections.id,
            gameName: Game.Names.connections,
            date: Date(),
            score: 4,
            maxAttempts: 4,
            completed: true,
            sharedText: "Connections Puzzle #500",
            parsedData: ["puzzleNumber": "500"]
        )
    }

    // MARK: - Key identity

    func testTheTwoOnboardingSurfacesUseDistinctDefaultsKeys() {
        XCTAssertEqual(AppConstants.Onboarding.hasSeenShareOnboarding, "hasSeenShareOnboarding")
        XCTAssertEqual(AppConstants.Onboarding.hasSeenFirstShareCelebration, "hasSeenFirstShareCelebration")
        XCTAssertNotEqual(
            AppConstants.Onboarding.hasSeenShareOnboarding,
            AppConstants.Onboarding.hasSeenFirstShareCelebration
        )
    }

    // MARK: - Flag isolation

    func testDismissingTheTeachingSheetDoesNotSuppressTheCelebration() {
        UserDefaults.standard.set(true, forKey: AppConstants.Onboarding.hasSeenShareOnboarding)
        let appState = makeAppState()

        XCTAssertTrue(appState.addGameResult(makeWordleResult()))

        XCTAssertEqual(celebrationCounter.count, 1)
    }

    func testFiringTheCelebrationDoesNotMarkTheTeachingSheetAsSeen() {
        let appState = makeAppState()

        XCTAssertTrue(appState.addGameResult(makeWordleResult()))

        XCTAssertEqual(celebrationCounter.count, 1)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: AppConstants.Onboarding.hasSeenShareOnboarding))
        XCTAssertTrue(UserDefaults.standard.bool(forKey: AppConstants.Onboarding.hasSeenFirstShareCelebration))
    }

    // MARK: - Guest Mode

    func testGuestModeSuppressesTheCelebrationWithoutBurningTheFlag() {
        let appState = makeAppState()
        appState.isGuestMode = true

        XCTAssertTrue(appState.addGameResult(makeWordleResult()))

        XCTAssertEqual(celebrationCounter.count, 0)
        XCTAssertFalse(
            UserDefaults.standard.bool(forKey: AppConstants.Onboarding.hasSeenFirstShareCelebration),
            "A guest must still get the celebration once they sign in and log a real result"
        )
    }

    func testCelebrationStillFiresAfterLeavingGuestMode() {
        let appState = makeAppState()
        appState.isGuestMode = true
        XCTAssertTrue(appState.addGameResult(makeWordleResult()))
        XCTAssertEqual(celebrationCounter.count, 0)

        appState.clearForGuestMode()
        appState.isGuestMode = false

        XCTAssertTrue(appState.addGameResult(makeConnectionsResult()))
        XCTAssertEqual(celebrationCounter.count, 1)
    }

    // MARK: - Restored history

    func testCelebrationDoesNotFireForAUserWhoseHistoryWasRestored() {
        let appState = makeAppState()
        // Results loaded from persistence/sync at launch, not through addGameResult.
        appState.setRecentResults([makeWordleResult()])

        XCTAssertTrue(appState.addGameResult(makeConnectionsResult()))

        XCTAssertEqual(celebrationCounter.count, 0)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: AppConstants.Onboarding.hasSeenFirstShareCelebration))
    }

    // MARK: - Teaching-sheet round trip

    func testTeachingSheetGateFlipsOnceTheDismissalFlagIsPersisted() {
        let appState = makeAppState()

        let beforeDismissal = ShareDiscoveryGate.shouldShowOnboarding(
            resultsCount: appState.recentResults.count,
            hasSeen: UserDefaults.standard.bool(forKey: AppConstants.Onboarding.hasSeenShareOnboarding)
        )
        XCTAssertTrue(beforeDismissal)

        // Exactly what ImprovedDashboardView writes in the sheet's onDismiss.
        UserDefaults.standard.set(true, forKey: AppConstants.Onboarding.hasSeenShareOnboarding)

        let afterDismissal = ShareDiscoveryGate.shouldShowOnboarding(
            resultsCount: appState.recentResults.count,
            hasSeen: UserDefaults.standard.bool(forKey: AppConstants.Onboarding.hasSeenShareOnboarding)
        )
        XCTAssertFalse(afterDismissal)
    }
}
