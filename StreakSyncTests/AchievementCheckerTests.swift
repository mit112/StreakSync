import XCTest
@testable import StreakSync

final class AchievementCheckerTests: XCTestCase {
    func testStreakMasterUnlocks() throws {
        let app = AppState()
        var ach = AchievementFactory.createStreakMasterAchievement()
        var tiered = [ach]
        let streaks = [GameStreak.empty(for: app.games.first!)]
        var s = streaks[0]
        s.currentStreak = 7
        let checker = TieredAchievementChecker()
        let result = GameResult(id: UUID(), gameId: app.games.first!.id, gameName: app.games.first!.name, score: 1, maxAttempts: 6, completed: true, date: Date(), sharedText: "", parsedData: [:])
        var current = tiered
        let _ = checker.checkAllAchievements(for: result, allResults: [result], streaks: [s], games: app.games, currentAchievements: &current)
        XCTAssertEqual(current[0].progress.currentTier, .silver)
    }
    
    func testDailyDevoteeCountsConsecutiveDays() throws {
        let app = AppState()
        var ach = AchievementFactory.createDailyDevoteeAchievement()
        var tiered = [ach]
        let checker = TieredAchievementChecker()
        let gid = app.games.first!.id
        let now = Date()
        let cal = Calendar.current
        let r0 = GameResult(id: UUID(), gameId: gid, gameName: "Test", score: 1, maxAttempts: 6, completed: true, date: now, sharedText: "", parsedData: [:])
        let r1 = GameResult(id: UUID(), gameId: gid, gameName: "Test", score: 1, maxAttempts: 6, completed: true, date: cal.date(byAdding: .day, value: -1, to: now)!, sharedText: "", parsedData: [:])
        var current = tiered
        let _ = checker.checkAllAchievements(for: r0, allResults: [r1, r0], streaks: [], games: app.games, currentAchievements: &current)
        XCTAssertNotNil(current.first!.progress.currentTier)
    }
}


