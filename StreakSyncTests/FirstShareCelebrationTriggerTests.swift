//
//  FirstShareCelebrationTriggerTests.swift
//  StreakSync
//
//  Verifies that AppState.addGameResult posts the appFirstShareCelebrationRequested
//  notification exactly once on the 0→1 transition.
//

import XCTest
@testable import StreakSync

@MainActor
final class FirstShareCelebrationTriggerTests: XCTestCase {

    private var appState: AppState!
    private var observer: NSObjectProtocol?
    private var notificationCount: Int = 0
    private var capturedGameName: String?

    override func setUp() async throws {
        try await super.setUp()
        UserDefaults.standard.removeObject(forKey: AppConstants.Onboarding.hasSeenFirstShareCelebration)
        notificationCount = 0
        capturedGameName = nil

        appState = AppState()

        observer = NotificationCenter.default.addObserver(
            forName: .appFirstShareCelebrationRequested,
            object: nil,
            queue: .main
        ) { [weak self] note in
            self?.notificationCount += 1
            self?.capturedGameName = note.userInfo?["gameName"] as? String
        }
    }

    override func tearDown() async throws {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        UserDefaults.standard.removeObject(forKey: AppConstants.Onboarding.hasSeenFirstShareCelebration)
        appState = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func makeResult(gameName: String = "Wordle", id: UUID = UUID()) -> GameResult {
        GameResult(
            gameId: id,
            gameName: gameName,
            date: Date(),
            score: 3,
            maxAttempts: 6,
            completed: true,
            sharedText: "Wordle 1,234 3/6",
            parsedData: ["puzzleNumber": "1234"]
        )
    }

    // MARK: - Tests

    func testFirstResultPostsCelebrationNotification() {
        let result = makeResult(gameName: "Wordle")
        _ = appState.addGameResult(result)
        XCTAssertEqual(notificationCount, 1)
        XCTAssertEqual(capturedGameName, "Wordle")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: AppConstants.Onboarding.hasSeenFirstShareCelebration))
    }

    func testSecondResultDoesNotPostCelebration() {
        _ = appState.addGameResult(makeResult(gameName: "Wordle"))
        _ = appState.addGameResult(makeResult(gameName: "Connections"))
        XCTAssertEqual(notificationCount, 1, "Should fire only on the 0→1 transition, not on subsequent adds")
    }

    func testCelebrationDoesNotRepeatIfFlagAlreadySet() {
        UserDefaults.standard.set(true, forKey: AppConstants.Onboarding.hasSeenFirstShareCelebration)
        _ = appState.addGameResult(makeResult())
        XCTAssertEqual(notificationCount, 0)
    }
}
