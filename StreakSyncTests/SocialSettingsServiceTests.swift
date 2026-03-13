//
//  SocialSettingsServiceTests.swift
//  StreakSyncTests
//

import XCTest
@testable import StreakSync

@MainActor
final class SocialSettingsServiceTests: XCTestCase {
    private var service: SocialSettingsService { SocialSettingsService.shared }

    override func setUp() async throws {
        // Reset to defaults before each test to prevent cross-test contamination
        service.updateShareIncompleteGames(true)
        service.updateHideZeroPointScores(false)
        service.updateScope(.allFriends, for: Game.wordle.id)
    }

    func testShouldShareRespectsIncompleteToggle() {
        service.updateShareIncompleteGames(false)
        let score = DailyGameScore(
            id: "user|20250101|game",
            userId: "user",
            dateInt: 20250101,
            gameId: Game.wordle.id,
            gameName: Game.wordle.displayName,
            score: 3,
            maxAttempts: 6,
            completed: false,
            currentStreak: nil
        )
        XCTAssertFalse(service.shouldShare(score: score, game: Game.wordle))
    }

    func testShouldShareRespectsScope() {
        service.updateScope(.privateScope, for: Game.wordle.id)
        let score = DailyGameScore(
            id: "user|20250101|game",
            userId: "user",
            dateInt: 20250101,
            gameId: Game.wordle.id,
            gameName: Game.wordle.displayName,
            score: 2,
            maxAttempts: 6,
            completed: true,
            currentStreak: nil
        )
        XCTAssertFalse(service.shouldShare(score: score, game: Game.wordle))
    }
}
