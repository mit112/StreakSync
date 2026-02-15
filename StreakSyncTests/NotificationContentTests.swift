//
//  NotificationContentTests.swift
//  StreakSyncTests
//
//  Tests for notification content builder logic
//

import XCTest
@testable import StreakSync

@MainActor
final class NotificationContentTests: XCTestCase {
    
    private let scheduler = NotificationScheduler.shared
    
    // MARK: - Helper
    
    private func sampleGame(name: String) -> Game {
        Game(
            name: name.lowercased(),
            displayName: name,
            url: URL(string: "https://example.com")!,
            category: .word,
            resultPattern: "",
            iconSystemName: "square",
            backgroundColor: CodableColor(.blue),
            isPopular: false,
            isCustom: false
        )
    }
    
    // MARK: - buildStreakReminderContent Tests
    
    func testSingleGameContent() {
        let games = [sampleGame(name: "Wordle")]
        let content = scheduler.buildStreakReminderContent(games: games)
        
        XCTAssertEqual(content.title, "Streak Reminder")
        XCTAssertTrue(content.body.contains("Wordle"))
        XCTAssertEqual(content.categoryIdentifier, "STREAK_REMINDER")
        XCTAssertEqual(content.userInfo["gameId"] as? String, games[0].id.uuidString)
        XCTAssertEqual(content.userInfo["type"] as? String, "daily_streak_reminder")
    }
    
    func testTwoGamesContent() {
        let games = [sampleGame(name: "Wordle"), sampleGame(name: "Nerdle")]
        let content = scheduler.buildStreakReminderContent(games: games)
        
        XCTAssertEqual(content.title, "Streak Reminders")
        XCTAssertTrue(content.body.contains("Wordle"))
        XCTAssertTrue(content.body.contains("Nerdle"))
        XCTAssertEqual(content.userInfo["type"] as? String, "daily_streak_reminder")
    }
    
    func testThreeGamesContent() {
        let games = [
            sampleGame(name: "Wordle"),
            sampleGame(name: "Nerdle"),
            sampleGame(name: "Connections")
        ]
        let content = scheduler.buildStreakReminderContent(games: games)
        
        XCTAssertEqual(content.title, "Streak Reminders")
        XCTAssertTrue(content.body.contains("Wordle"))
        XCTAssertTrue(content.body.contains("Nerdle"))
        XCTAssertTrue(content.body.contains("Connections"))
    }
    
    func testMoreThanThreeGamesContent() {
        let games = [
            sampleGame(name: "Wordle"),
            sampleGame(name: "Nerdle"),
            sampleGame(name: "Connections"),
            sampleGame(name: "Strands")
        ]
        let content = scheduler.buildStreakReminderContent(games: games)
        
        XCTAssertEqual(content.title, "Streak Reminders")
        // First two game names should appear
        XCTAssertTrue(content.body.contains("Wordle"))
        XCTAssertTrue(content.body.contains("Nerdle"))
        // Should mention remaining count
        XCTAssertTrue(content.body.contains("2 other games"))
    }
    
    func testFiveGamesShowsCorrectRemaining() {
        let games = (1...5).map { sampleGame(name: "Game\($0)") }
        let content = scheduler.buildStreakReminderContent(games: games)
        
        XCTAssertTrue(content.body.contains("3 other games"))
    }
    
    func testEmptyGamesContent() {
        let content = scheduler.buildStreakReminderContent(games: [])
        
        XCTAssertEqual(content.title, "Streak Reminder")
        XCTAssertTrue(content.body.contains("No streaks at risk"))
        XCTAssertEqual(content.userInfo["type"] as? String, "daily_streak_reminder")
    }
    
    func testContentHasSoundSet() {
        let games = [sampleGame(name: "Wordle")]
        let content = scheduler.buildStreakReminderContent(games: games)
        
        XCTAssertNotNil(content.sound)
    }
    
    func testContentCategoryIsStreakReminder() {
        let games = [sampleGame(name: "Wordle")]
        let content = scheduler.buildStreakReminderContent(games: games)
        
        XCTAssertEqual(content.categoryIdentifier, NotificationCategory.streakReminder.identifier)
    }
    
    func testSingleGameIncludesGameIdInUserInfo() {
        let games = [sampleGame(name: "Wordle")]
        let content = scheduler.buildStreakReminderContent(games: games)
        
        XCTAssertNotNil(content.userInfo["gameId"])
        XCTAssertEqual(content.userInfo["gameId"] as? String, games[0].id.uuidString)
    }
    
    func testMultipleGamesOmitsGameIdFromUserInfo() {
        let games = [sampleGame(name: "Wordle"), sampleGame(name: "Nerdle")]
        let content = scheduler.buildStreakReminderContent(games: games)
        
        // Multi-game reminders should not include a single gameId
        XCTAssertNil(content.userInfo["gameId"])
    }
    
    func testFourGamesShowsSingularOtherGame() {
        let games = [
            sampleGame(name: "Wordle"),
            sampleGame(name: "Nerdle"),
            sampleGame(name: "Connections")
        ]
        // With exactly 3 games, they should all be listed (count <= 3 path)
        let content = scheduler.buildStreakReminderContent(games: games)
        XCTAssertFalse(content.body.contains("other game"))
        
        // With 4 games, remaining = 2 → "2 other games" (plural)
        let fourGames = games + [sampleGame(name: "Strands")]
        let content4 = scheduler.buildStreakReminderContent(games: fourGames)
        XCTAssertTrue(content4.body.contains("other games"))
    }
    
    // MARK: - NotificationCategory Tests
    
    func testNotificationCategoryIdentifiers() {
        XCTAssertEqual(NotificationCategory.streakReminder.identifier, "STREAK_REMINDER")
        XCTAssertEqual(NotificationCategory.achievementUnlocked.identifier, "ACHIEVEMENT_UNLOCKED")
        XCTAssertEqual(NotificationCategory.resultImported.identifier, "RESULT_IMPORTED")
    }
    
    // MARK: - NotificationAction Tests
    
    func testNotificationActionIdentifiers() {
        XCTAssertEqual(NotificationAction.openGame.identifier, "OPEN_GAME")
        XCTAssertEqual(NotificationAction.snooze1Day.identifier, "SNOOZE_1_DAY")
        XCTAssertEqual(NotificationAction.snooze3Days.identifier, "SNOOZE_3_DAYS")
        XCTAssertEqual(NotificationAction.markPlayed.identifier, "MARK_PLAYED")
        XCTAssertEqual(NotificationAction.viewAchievement.identifier, "VIEW_ACHIEVEMENT")
    }
}
