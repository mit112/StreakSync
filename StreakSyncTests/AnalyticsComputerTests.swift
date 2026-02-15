//
//  AnalyticsComputerTests.swift
//  StreakSyncTests
//
//  Unit tests for the pure analytics computation layer.
//

import XCTest
@testable import StreakSync

final class AnalyticsComputerTests: XCTestCase {

    // MARK: - Test Fixtures

    private static let testGameId = UUID()
    private static let testGameId2 = UUID()

    private func makeGame(id: UUID = AnalyticsComputerTests.testGameId, name: String = "TestWordle") -> Game {
        Game(
            id: id,
            name: name,
            displayName: name,
            url: URL(string: "https://example.com")!,
            category: .word,
            resultPattern: ".*",
            iconSystemName: "textformat.abc",
            backgroundColor: CodableColor(.green),
            isPopular: true,
            isCustom: false
        )
    }

    private func makeResult(
        gameId: UUID = AnalyticsComputerTests.testGameId,
        gameName: String = "TestWordle",
        date: Date = Date(),
        score: Int? = 3,
        maxAttempts: Int = 6,
        completed: Bool = true
    ) -> GameResult {
        GameResult(
            id: UUID(),
            gameId: gameId,
            gameName: gameName,
            date: date,
            score: score,
            maxAttempts: maxAttempts,
            completed: completed,
            sharedText: "Test result"
        )
    }

    private func makeStreak(
        gameId: UUID = AnalyticsComputerTests.testGameId,
        currentStreak: Int = 5,
        maxStreak: Int = 10,
        totalPlayed: Int = 50,
        totalCompleted: Int = 45
    ) -> GameStreak {
        GameStreak(
            gameId: gameId,
            gameName: "TestWordle",
            currentStreak: currentStreak,
            maxStreak: maxStreak,
            totalGamesPlayed: totalPlayed,
            totalGamesCompleted: totalCompleted,
            lastPlayedDate: Date(),
            streakStartDate: Date()
        )
    }

    /// Helper to create a date N days ago from a fixed reference
    private func daysAgo(_ n: Int, from ref: Date = Date()) -> Date {
        Calendar.current.date(byAdding: .day, value: -n, to: Calendar.current.startOfDay(for: ref))!
    }

    // MARK: - longestStreakInRange Tests

    func test_longestStreakInRange_emptyResults_returnsZero() {
        let result = AnalyticsComputer.longestStreakInRange(
            startDate: daysAgo(7), endDate: Date(), gameId: nil, results: []
        )
        XCTAssertEqual(result, 0)
    }

    func test_longestStreakInRange_singleDay_returnsOne() {
        let results = [makeResult(date: daysAgo(1))]
        let result = AnalyticsComputer.longestStreakInRange(
            startDate: daysAgo(7), endDate: Date(), gameId: nil, results: results
        )
        XCTAssertEqual(result, 1)
    }

    func test_longestStreakInRange_consecutiveDays_countsAll() {
        let results = (0..<5).map { makeResult(date: daysAgo($0)) }
        let result = AnalyticsComputer.longestStreakInRange(
            startDate: daysAgo(7), endDate: Date(), gameId: nil, results: results
        )
        XCTAssertEqual(result, 5)
    }

    func test_longestStreakInRange_gapInMiddle_returnsLongestRun() {
        // Days 0,1,2 (3-streak) then gap then days 4,5 (2-streak)
        let results = [0, 1, 2, 4, 5].map { makeResult(date: daysAgo($0)) }
        let result = AnalyticsComputer.longestStreakInRange(
            startDate: daysAgo(7), endDate: Date(), gameId: nil, results: results
        )
        XCTAssertEqual(result, 3)
    }

    func test_longestStreakInRange_gameFilter_onlyCountsMatchingGame() {
        let gid1 = Self.testGameId
        let gid2 = Self.testGameId2
        let results = [
            makeResult(gameId: gid1, date: daysAgo(0)),
            makeResult(gameId: gid1, date: daysAgo(1)),
            makeResult(gameId: gid2, date: daysAgo(2)), // different game breaks gid1 streak
            makeResult(gameId: gid1, date: daysAgo(3)),
        ]
        let result = AnalyticsComputer.longestStreakInRange(
            startDate: daysAgo(7), endDate: Date(), gameId: gid1, results: results
        )
        XCTAssertEqual(result, 2) // days 0+1, not 0+1+3
    }

    func test_longestStreakInRange_outsideDateRange_excluded() {
        let results = [
            makeResult(date: daysAgo(2)), // inside range
            makeResult(date: daysAgo(10)), // outside range
        ]
        let result = AnalyticsComputer.longestStreakInRange(
            startDate: daysAgo(5), endDate: Date(), gameId: nil, results: results
        )
        XCTAssertEqual(result, 1) // only the one inside range
    }

    func test_longestStreakInRange_multipleResultsSameDay_countsAsOneDay() {
        let day = daysAgo(1)
        let results = [makeResult(date: day), makeResult(date: day), makeResult(date: day)]
        let result = AnalyticsComputer.longestStreakInRange(
            startDate: daysAgo(7), endDate: Date(), gameId: nil, results: results
        )
        XCTAssertEqual(result, 1)
    }

    // MARK: - computeOverview Tests

    func test_computeOverview_emptyData_returnsZeros() {
        let overview = AnalyticsComputer.computeOverview(
            timeRange: .week, game: nil, games: [], streaks: [], results: []
        )
        XCTAssertEqual(overview.totalActiveStreaks, 0)
        XCTAssertEqual(overview.longestCurrentStreak, 0)
        XCTAssertEqual(overview.totalGamesPlayed, 0)
        XCTAssertEqual(overview.averageCompletionRate, 0.0)
    }

    func test_computeOverview_withResults_countsCorrectly() {
        let game = makeGame()
        let results = [
            makeResult(date: daysAgo(1), completed: true),
            makeResult(date: daysAgo(2), completed: true),
            makeResult(date: daysAgo(3), completed: false),
        ]
        let streak = makeStreak(currentStreak: 3)
        let overview = AnalyticsComputer.computeOverview(
            timeRange: .week, game: nil, games: [game], streaks: [streak], results: results
        )
        XCTAssertEqual(overview.totalGamesPlayed, 3)
        XCTAssertEqual(overview.totalGamesCompleted, 2)
        XCTAssertEqual(overview.averageCompletionRate, 2.0 / 3.0, accuracy: 0.001)
    }

    func test_computeOverview_gameFilter_onlyCountsSpecificGame() {
        let game1 = makeGame(id: Self.testGameId, name: "Game1")
        let game2 = makeGame(id: Self.testGameId2, name: "Game2")
        let results = [
            makeResult(gameId: Self.testGameId, gameName: "Game1", date: daysAgo(1)),
            makeResult(gameId: Self.testGameId2, gameName: "Game2", date: daysAgo(1)),
            makeResult(gameId: Self.testGameId2, gameName: "Game2", date: daysAgo(2)),
        ]
        let overview = AnalyticsComputer.computeOverview(
            timeRange: .week, game: game1, games: [game1, game2], streaks: [], results: results
        )
        XCTAssertEqual(overview.totalGamesPlayed, 1)
    }

    func test_computeOverview_mostPlayedGame_identifiesCorrectly() {
        let game1 = makeGame(id: Self.testGameId, name: "Game1")
        let game2 = makeGame(id: Self.testGameId2, name: "Game2")
        let results = [
            makeResult(gameId: Self.testGameId, gameName: "Game1", date: daysAgo(1)),
            makeResult(gameId: Self.testGameId2, gameName: "Game2", date: daysAgo(1)),
            makeResult(gameId: Self.testGameId2, gameName: "Game2", date: daysAgo(2)),
        ]
        let overview = AnalyticsComputer.computeOverview(
            timeRange: .week, game: nil, games: [game1, game2], streaks: [], results: results
        )
        XCTAssertEqual(overview.mostPlayedGame?.id, Self.testGameId2)
    }

    // MARK: - Consistency Tests

    func test_computeStreakConsistency_emptyResults_returnsZero() {
        let consistency = AnalyticsComputer.computeStreakConsistency(
            timeRange: .week, game: nil, results: []
        )
        XCTAssertEqual(consistency, 0.0)
    }

    func test_computeStreakConsistency_allDaysActive_returnsOne() {
        let results = (0..<7).map { makeResult(date: daysAgo($0)) }
        let consistency = AnalyticsComputer.computeStreakConsistency(
            timeRange: .week, game: nil, results: results
        )
        XCTAssertEqual(consistency, 1.0, accuracy: 0.001)
    }

    func test_computeConsistencyDays_partialWeek_returnsCorrectCounts() {
        let results = [
            makeResult(date: daysAgo(0)),
            makeResult(date: daysAgo(2)),
            makeResult(date: daysAgo(4)),
        ]
        let (active, total) = AnalyticsComputer.computeConsistencyDays(
            timeRange: .week, game: nil, results: results
        )
        XCTAssertEqual(active, 3)
        XCTAssertEqual(total, 7)
    }

    // MARK: - Score Tests

    func test_computeAverageScore_emptyResults_returnsZero() {
        let avg = AnalyticsComputer.computeAverageScore(
            for: Self.testGameId, in: .week, results: []
        )
        XCTAssertEqual(avg, 0.0)
    }

    func test_computeAverageScore_calculatesCorrectly() {
        let results = [
            makeResult(date: daysAgo(1), score: 2, completed: true),
            makeResult(date: daysAgo(2), score: 4, completed: true),
            makeResult(date: daysAgo(3), score: 6, completed: true),
        ]
        let avg = AnalyticsComputer.computeAverageScore(
            for: Self.testGameId, in: .week, results: results
        )
        XCTAssertEqual(avg, 4.0, accuracy: 0.001)
    }

    func test_computePersonalBest_returnsLowestScore() {
        let results = [
            makeResult(date: daysAgo(1), score: 4, completed: true),
            makeResult(date: daysAgo(2), score: 2, completed: true),
            makeResult(date: daysAgo(3), score: 5, completed: true),
        ]
        let best = AnalyticsComputer.computePersonalBest(
            for: Self.testGameId, results: results
        )
        XCTAssertEqual(best, 2)
    }

    func test_computePersonalBest_ignoresIncomplete() {
        let results = [
            makeResult(date: daysAgo(1), score: nil, completed: false),
            makeResult(date: daysAgo(2), score: 3, completed: true),
        ]
        let best = AnalyticsComputer.computePersonalBest(
            for: Self.testGameId, results: results
        )
        XCTAssertEqual(best, 3)
    }

    // MARK: - computeStreakTrends Tests

    func test_computeStreakTrends_emptyResults_returnsTrendPointsWithZeros() {
        let trends = AnalyticsComputer.computeStreakTrends(
            timeRange: .week, results: []
        )
        // Should still return one point per day in the range
        XCTAssertGreaterThan(trends.count, 0)
        for point in trends {
            XCTAssertEqual(point.gamesPlayed, 0)
            XCTAssertEqual(point.totalActiveStreaks, 0)
        }
    }

    func test_computeStreakTrends_withActivity_tracksGamesPlayed() {
        let results = [
            makeResult(date: daysAgo(1)),
            makeResult(date: daysAgo(1)),
            makeResult(date: daysAgo(3)),
        ]
        let trends = AnalyticsComputer.computeStreakTrends(
            timeRange: .week, results: results
        )
        // Find the point for 1 day ago — should have 2 games played
        let dayAgo1 = Calendar.current.startOfDay(for: daysAgo(1))
        let point = trends.first { Calendar.current.isDate($0.date, inSameDayAs: dayAgo1) }
        XCTAssertNotNil(point)
        XCTAssertEqual(point?.gamesPlayed, 2)
    }

    func test_computeStreakTrends_gameFilter_onlyCountsMatchingGame() {
        let results = [
            makeResult(gameId: Self.testGameId, date: daysAgo(1)),
            makeResult(gameId: Self.testGameId2, gameName: "Other", date: daysAgo(1)),
        ]
        let game = makeGame()
        let trends = AnalyticsComputer.computeStreakTrends(
            timeRange: .week, game: game, results: results
        )
        let dayAgo1 = Calendar.current.startOfDay(for: daysAgo(1))
        let point = trends.first { Calendar.current.isDate($0.date, inSameDayAs: dayAgo1) }
        XCTAssertEqual(point?.gamesPlayed, 1)
    }

    // MARK: - computePersonalBests Tests

    func test_computePersonalBests_emptyResults_returnsEmpty() {
        let bests = AnalyticsComputer.computePersonalBests(
            timeRange: .week, game: nil, games: [], streaks: [], results: []
        )
        XCTAssertTrue(bests.isEmpty)
    }

    func test_computePersonalBests_longestStreak_detected() {
        let game = makeGame()
        let results = (0..<4).map { makeResult(date: daysAgo($0)) }
        let bests = AnalyticsComputer.computePersonalBests(
            timeRange: .week, game: nil, games: [game], streaks: [], results: results
        )
        let streakBest = bests.first { $0.type == .longestStreak }
        XCTAssertNotNil(streakBest)
        XCTAssertEqual(streakBest?.value, 4)
    }

    func test_computePersonalBests_bestScore_detected() {
        let game = makeGame()
        let results = [
            makeResult(date: daysAgo(1), score: 4, completed: true),
            makeResult(date: daysAgo(2), score: 2, completed: true),
        ]
        let bests = AnalyticsComputer.computePersonalBests(
            timeRange: .week, game: nil, games: [game], streaks: [], results: results
        )
        let scoreBest = bests.first { $0.type == .bestScore }
        XCTAssertNotNil(scoreBest)
        XCTAssertEqual(scoreBest?.value, 2)
    }

    func test_computePersonalBests_mostGamesInDay_requiresMultiple() {
        let game = makeGame()
        let sameDay = daysAgo(1)
        let results = [
            makeResult(date: sameDay),
            makeResult(date: sameDay),
            makeResult(date: sameDay),
        ]
        let bests = AnalyticsComputer.computePersonalBests(
            timeRange: .week, game: nil, games: [game], streaks: [], results: results
        )
        let dayBest = bests.first { $0.type == .mostGamesInDay }
        XCTAssertNotNil(dayBest)
        XCTAssertEqual(dayBest?.value, 3)
    }

    // MARK: - Achievement Fixtures

    private func makeTieredAchievement(
        category: AchievementCategory = .streakMaster,
        currentValue: Int = 5,
        currentTier: AchievementTier? = .bronze,
        requirements: [TierRequirement]? = nil
    ) -> TieredAchievement {
        let reqs = requirements ?? [
            TierRequirement(tier: .bronze, threshold: 3),
            TierRequirement(tier: .silver, threshold: 7),
            TierRequirement(tier: .gold, threshold: 14),
        ]
        let progress = AchievementProgress(
            currentValue: currentValue,
            currentTier: currentTier,
            tierUnlockDates: currentTier != nil ? [currentTier!: Date()] : [:]
        )
        return TieredAchievement(category: category, requirements: reqs, progress: progress)
    }

    // MARK: - computeAchievementAnalytics Tests

    func test_computeAchievementAnalytics_nilInput_returnsDefaults() {
        let result = AnalyticsComputer.computeAchievementAnalytics(tieredAchievements: nil)
        XCTAssertEqual(result.totalUnlocked, 0)
        XCTAssertEqual(result.totalAvailable, 0)
    }

    func test_computeAchievementAnalytics_emptyArray_returnsDefaults() {
        let result = AnalyticsComputer.computeAchievementAnalytics(tieredAchievements: [])
        XCTAssertEqual(result.totalUnlocked, 0)
        XCTAssertEqual(result.totalAvailable, 0)
    }

    func test_computeAchievementAnalytics_countsUnlockedCorrectly() {
        let achievements = [
            makeTieredAchievement(category: .streakMaster, currentTier: .bronze),
            makeTieredAchievement(category: .perfectionist, currentTier: .silver),
            makeTieredAchievement(category: .dailyDevotee, currentTier: nil),
        ]
        let result = AnalyticsComputer.computeAchievementAnalytics(tieredAchievements: achievements)
        XCTAssertEqual(result.totalUnlocked, 2)
        XCTAssertEqual(result.totalAvailable, 3)
    }

    func test_computeAchievementAnalytics_tierDistribution_correct() {
        let achievements = [
            makeTieredAchievement(category: .streakMaster, currentTier: .bronze),
            makeTieredAchievement(category: .perfectionist, currentTier: .bronze),
            makeTieredAchievement(category: .dailyDevotee, currentTier: .gold),
        ]
        let result = AnalyticsComputer.computeAchievementAnalytics(tieredAchievements: achievements)
        XCTAssertEqual(result.tierDistribution[.bronze], 2)
        XCTAssertEqual(result.tierDistribution[.gold], 1)
    }

    func test_computeAchievementAnalytics_nextActions_limitsToThree() {
        let achievements = (0..<5).map { i in
            makeTieredAchievement(
                category: AchievementCategory.allCases[i],
                currentValue: i,
                currentTier: .bronze
            )
        }
        let result = AnalyticsComputer.computeAchievementAnalytics(tieredAchievements: achievements)
        XCTAssertLessThanOrEqual(result.nextActions.count, 3)
    }

    func test_computeAchievementAnalytics_categoryProgress_correct() {
        let achievements = [
            makeTieredAchievement(category: .streakMaster, currentTier: .bronze),
            makeTieredAchievement(category: .streakMaster, currentTier: nil),
        ]
        let result = AnalyticsComputer.computeAchievementAnalytics(tieredAchievements: achievements)
        XCTAssertEqual(result.categoryProgress[.streakMaster] ?? 0, 0.5, accuracy: 0.001)
    }

    // MARK: - computeWeeklySummaries Tests

    func test_computeWeeklySummaries_emptyResults_returnsEmpty() {
        let summaries = AnalyticsComputer.computeWeeklySummaries(
            timeRange: .month, games: [], results: [], streaks: []
        )
        XCTAssertTrue(summaries.isEmpty)
    }

    func test_computeWeeklySummaries_groupsByWeek() {
        let game = makeGame()
        let results = [
            makeResult(date: daysAgo(1)),  // this week
            makeResult(date: daysAgo(2)),  // this week
            makeResult(date: daysAgo(10)), // last week
        ]
        let summaries = AnalyticsComputer.computeWeeklySummaries(
            timeRange: .month, games: [game], results: results, streaks: []
        )
        // Should have at least 2 week groups
        XCTAssertGreaterThanOrEqual(summaries.count, 1)
        // Total across all weeks should be 3
        let totalPlayed = summaries.reduce(0) { $0 + $1.totalGamesPlayed }
        XCTAssertEqual(totalPlayed, 3)
    }

    func test_computeWeeklySummaries_completionRate_calculatesCorrectly() {
        let game = makeGame()
        let results = [
            makeResult(date: daysAgo(1), completed: true),
            makeResult(date: daysAgo(2), completed: true),
            makeResult(date: daysAgo(3), completed: false),
        ]
        let summaries = AnalyticsComputer.computeWeeklySummaries(
            timeRange: .week, games: [game], results: results, streaks: []
        )
        guard let summary = summaries.first else {
            XCTFail("Expected at least one weekly summary")
            return
        }
        XCTAssertEqual(summary.completionRate, 2.0 / 3.0, accuracy: 0.001)
    }
}
