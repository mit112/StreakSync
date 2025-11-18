import XCTest
@testable import StreakSync

@MainActor
final class SocialSettingsServiceTests: XCTestCase {
    func testShouldShareRespectsIncompleteToggle() {
        let service = SocialSettingsService.shared
        service.updateShareIncompleteGames(false)
        let score = DailyGameScore(
            id: "user|20250101|game",
            userId: "user",
            dateInt: 20250101,
            gameId: Game.wordle.id,
            gameName: Game.wordle.displayName,
            score: 3,
            maxAttempts: 6,
            completed: false
        )
        XCTAssertFalse(service.shouldShare(score: score, game: Game.wordle))
        service.updateShareIncompleteGames(true)
    }
    
    func testShouldShareRespectsScope() {
        let service = SocialSettingsService.shared
        service.updateScope(.privateScope, for: Game.wordle.id)
        let score = DailyGameScore(
            id: "user|20250101|game",
            userId: "user",
            dateInt: 20250101,
            gameId: Game.wordle.id,
            gameName: Game.wordle.displayName,
            score: 2,
            maxAttempts: 6,
            completed: true
        )
        XCTAssertFalse(service.shouldShare(score: score, game: Game.wordle))
        service.updateScope(.allFriends, for: Game.wordle.id)
    }
}

