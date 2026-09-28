//
//  SocialSettingsServiceTests.swift
//  StreakSyncTests
//
//  Social sharing scope persistence tests
//

@testable import StreakSync
import XCTest

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

    // MARK: - Score Sharing screen bindings

    func testSharesGameSubscriptMapsToScope() {
        var settings = SocialPrivacySettings.default
        XCTAssertTrue(settings[sharesGame: Game.wordle.id], "A game with no saved scope is shared")

        settings[sharesGame: Game.wordle.id] = false
        XCTAssertEqual(settings.perGameScopes[Game.wordle.id], .privateScope)

        settings[sharesGame: Game.wordle.id] = true
        XCTAssertEqual(settings.perGameScopes[Game.wordle.id], .allFriends)
    }

    /// The screen writes through `settings` directly rather than the update methods, so the
    /// write must still reach UserDefaults.
    func testWritingSettingsDirectlyPersists() throws {
        service.settings[sharesGame: Game.wordle.id] = false

        let data = try XCTUnwrap(UserDefaults.standard.data(forKey: "social_privacy_settings"))
        let stored = try JSONDecoder().decode(SocialPrivacySettings.self, from: data)
        XCTAssertEqual(stored.perGameScopes[Game.wordle.id], .privateScope)
    }
}
