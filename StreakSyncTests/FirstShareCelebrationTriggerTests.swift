//
//  FirstShareCelebrationTriggerTests.swift
//  StreakSync
//
//  Verifies that AppState.addGameResult posts the appFirstShareCelebrationRequested
//  notification exactly once on the 0→1 transition.
//

import Foundation
@testable import StreakSync
import XCTest

/// Thread-safe recorder for the celebration notification.
///
/// `addObserver(forName:object:queue:using:)` declares its block
/// `NS_SWIFT_SENDABLE`, so the closure can neither capture the non-Sendable
/// `XCTestCase` nor mutate its `@MainActor` stored properties. The closure captures
/// this reference type by value instead; the `@MainActor` test bodies read the
/// recorded values back through the lock.
private final class CelebrationRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    private var lastGameName: String?

    var notificationCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    var capturedGameName: String? {
        lock.lock()
        defer { lock.unlock() }
        return lastGameName
    }

    func record(gameName: String?) {
        lock.lock()
        count += 1
        lastGameName = gameName
        lock.unlock()
    }
}

@MainActor
final class FirstShareCelebrationTriggerTests: XCTestCase {
    private var appState: AppState?
    private var observer: NSObjectProtocol?
    private var recorder = CelebrationRecorder()

    override func setUp() async throws {
        try await super.setUp()
        UserDefaults.standard.removeObject(forKey: AppConstants.Onboarding.hasSeenFirstShareCelebration)

        let recorder = CelebrationRecorder()
        self.recorder = recorder

        appState = AppState()

        // Capture `recorder` explicitly so `self` is never captured by the
        // @Sendable observer block.
        observer = NotificationCenter.default.addObserver(
            forName: .appFirstShareCelebrationRequested,
            object: nil,
            queue: .main
        ) { [recorder] note in
            recorder.record(gameName: note.userInfo?["gameName"] as? String)
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
        _ = appState?.addGameResult(result)
        XCTAssertEqual(recorder.notificationCount, 1)
        XCTAssertEqual(recorder.capturedGameName, "Wordle")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: AppConstants.Onboarding.hasSeenFirstShareCelebration))
    }

    func testSecondResultDoesNotPostCelebration() {
        _ = appState?.addGameResult(makeResult(gameName: "Wordle"))
        _ = appState?.addGameResult(makeResult(gameName: "Connections"))
        XCTAssertEqual(
            recorder.notificationCount, 1,
            "Should fire only on the 0→1 transition, not on subsequent adds"
        )
    }

    func testCelebrationDoesNotRepeatIfFlagAlreadySet() {
        UserDefaults.standard.set(true, forKey: AppConstants.Onboarding.hasSeenFirstShareCelebration)
        _ = appState?.addGameResult(makeResult())
        XCTAssertEqual(recorder.notificationCount, 0)
    }
}
