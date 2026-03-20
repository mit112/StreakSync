//
//  AnalyticsComputerTests+Extended.swift
//  StreakSyncTests
//
//  Extended analytics tests: personal bests, achievements, weekly summaries, trends
//

@testable import StreakSync
import XCTest

extension AnalyticsComputerTests {
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
            makeResult(date: daysAgo(2), score: 2, completed: true)
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
            makeResult(date: sameDay)
        ]
        let bests = AnalyticsComputer.computePersonalBests(
            timeRange: .week, game: nil, games: [game], streaks: [], results: results
        )
        let dayBest = bests.first { $0.type == .mostGamesInDay }
        XCTAssertNotNil(dayBest)
        XCTAssertEqual(dayBest?.value, 3)
    }

    // MARK: - Achievement Fixtures

    func makeTieredAchievement(
        category: AchievementCategory = .streakMaster,
        currentValue: Int = 5,
        currentTier: AchievementTier? = .bronze,
        requirements: [TierRequirement]? = nil
    ) -> TieredAchievement {
        let reqs = requirements ?? [
            TierRequirement(tier: .bronze, threshold: 3),
            TierRequirement(tier: .silver, threshold: 7),
            TierRequirement(tier: .gold, threshold: 14)
        ]
        let progress = AchievementProgress(
            currentValue: currentValue,
            currentTier: currentTier,
            tierUnlockDates: currentTier != nil ? [currentTier!: Date()] : [:] // swiftlint:disable:this force_unwrapping
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
            makeTieredAchievement(category: .dailyDevotee, currentTier: nil)
        ]
        let result = AnalyticsComputer.computeAchievementAnalytics(tieredAchievements: achievements)
        XCTAssertEqual(result.totalUnlocked, 2)
        XCTAssertEqual(result.totalAvailable, 3)
    }

    func test_computeAchievementAnalytics_tierDistribution_correct() {
        let achievements = [
            makeTieredAchievement(category: .streakMaster, currentTier: .bronze),
            makeTieredAchievement(category: .perfectionist, currentTier: .bronze),
            makeTieredAchievement(category: .dailyDevotee, currentTier: .gold)
        ]
        let result = AnalyticsComputer.computeAchievementAnalytics(tieredAchievements: achievements)
        XCTAssertEqual(result.tierDistribution[.bronze], 2)
        XCTAssertEqual(result.tierDistribution[.gold], 1)
    }

    func test_computeAchievementAnalytics_nextActions_limitsToThree() {
        let achievements = (0..<5).map { i in
            makeTieredAchievement(
                category: AchievementCategory.activeCategories[i],
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
            makeTieredAchievement(category: .streakMaster, currentTier: nil)
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
            makeResult(date: daysAgo(1)),
            makeResult(date: daysAgo(2)),
            makeResult(date: daysAgo(10))
        ]
        let summaries = AnalyticsComputer.computeWeeklySummaries(
            timeRange: .month, games: [game], results: results, streaks: []
        )
        XCTAssertGreaterThanOrEqual(summaries.count, 1)
        let totalPlayed = summaries.reduce(0) { $0 + $1.totalGamesPlayed }
        XCTAssertEqual(totalPlayed, 3)
    }

    func test_computeWeeklySummaries_completionRate_calculatesCorrectly() {
        let game = makeGame()
        let results = [
            makeResult(date: daysAgo(1), completed: true),
            makeResult(date: daysAgo(2), completed: true),
            makeResult(date: daysAgo(3), completed: false)
        ]
        let summaries = AnalyticsComputer.computeWeeklySummaries(
            timeRange: .week, games: [game], results: results, streaks: []
        )
        guard !summaries.isEmpty else {
            XCTFail("Expected at least one weekly summary")
            return
        }
        let totalPlayed = summaries.reduce(0) { $0 + $1.totalGamesPlayed }
        let totalCompleted = summaries.reduce(0) { $0 + $1.totalGamesCompleted }
        let completionRate = totalPlayed > 0 ? Double(totalCompleted) / Double(totalPlayed) : 0
        XCTAssertEqual(completionRate, 2.0 / 3.0, accuracy: 0.001)
    }

    // MARK: - Inactive Streak Exclusion

    func test_computeOverview_inactiveStreaks_excludedFromCount() {
        let game = makeGame()
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
        let inactiveStreak = GameStreak(
            gameId: Self.testGameId,
            gameName: "TestWordle",
            currentStreak: 5,
            maxStreak: 10,
            totalGamesPlayed: 50,
            totalGamesCompleted: 45,
            lastPlayedDate: threeDaysAgo,
            streakStartDate: threeDaysAgo
        )
        let overview = AnalyticsComputer.computeOverview(
            timeRange: .week, game: nil, games: [game],
            streaks: [inactiveStreak], results: []
        )
        XCTAssertEqual(overview.totalActiveStreaks, 0)
    }

    // MARK: - computeGameTrendData Tests

    func test_computeGameTrendData_countsPerDay() {
        let results = [
            makeResult(date: daysAgo(1), completed: true),
            makeResult(date: daysAgo(1), completed: false),
            makeResult(date: daysAgo(3), completed: true)
        ]
        let trends = AnalyticsComputer.computeGameTrendData(
            for: Self.testGameId, in: .week, results: results
        )
        let dayAgo1 = Calendar.current.startOfDay(for: daysAgo(1))
        let point = trends.first { Calendar.current.isDate($0.date, inSameDayAs: dayAgo1) }
        XCTAssertNotNil(point)
        XCTAssertEqual(point?.gamesPlayed, 2)
        XCTAssertEqual(point?.gamesCompleted, 1)
    }

    func test_computeGameTrendData_emptyDay_returnsZeros() {
        let trends = AnalyticsComputer.computeGameTrendData(
            for: Self.testGameId, in: .week, results: []
        )
        XCTAssertGreaterThan(trends.count, 0)
        for point in trends {
            XCTAssertEqual(point.gamesPlayed, 0)
        }
    }

    func test_computeGameTrendData_onlyCountsMatchingGame() {
        let results = [
            makeResult(gameId: Self.testGameId, date: daysAgo(1)),
            makeResult(gameId: Self.testGameId2, gameName: "Other", date: daysAgo(1))
        ]
        let trends = AnalyticsComputer.computeGameTrendData(
            for: Self.testGameId, in: .week, results: results
        )
        let dayAgo1 = Calendar.current.startOfDay(for: daysAgo(1))
        let point = trends.first { Calendar.current.isDate($0.date, inSameDayAs: dayAgo1) }
        XCTAssertEqual(point?.gamesPlayed, 1)
    }

    // MARK: - higherIsBetter in computePersonalBests

    func test_computePersonalBests_bestScore_higherIsBetter_returnsHighest() {
        let game = makeGame(scoringModel: .higherIsBetter)
        let results = [
            makeResult(date: daysAgo(1), score: 50, maxAttempts: 100, completed: true),
            makeResult(date: daysAgo(2), score: 80, maxAttempts: 100, completed: true),
            makeResult(date: daysAgo(3), score: 30, maxAttempts: 100, completed: true)
        ]
        let bests = AnalyticsComputer.computePersonalBests(
            timeRange: .week, game: nil, games: [game], streaks: [], results: results
        )
        let scoreBest = bests.first { $0.type == .bestScore }
        XCTAssertNotNil(scoreBest)
        XCTAssertEqual(scoreBest?.value, 80)
    }

    // MARK: - Weekly Summary averageStreakLength

    func test_computeWeeklySummaries_averageStreakLength_variesByWeek() {
        let game = makeGame()
        let results = [
            makeResult(date: daysAgo(1)),
            makeResult(date: daysAgo(2)),
            makeResult(date: daysAgo(3)),
            makeResult(date: daysAgo(10))
        ]
        let summaries = AnalyticsComputer.computeWeeklySummaries(
            timeRange: .month, games: [game], results: results, streaks: []
        )
        guard summaries.count >= 2 else {
            XCTFail("Expected at least 2 weekly summaries")
            return
        }
        let streakLengths = Set(summaries.map { $0.averageStreakLength })
        XCTAssertGreaterThan(streakLengths.count, 1)
    }
}
