//
//  TieredAchievementChecker.swift
//  StreakSync
//
//  Achievement progress tracking and checking system
//

import Foundation
import OSLog

// MARK: - Achievement Snapshot

/// Pre-computed metrics from a single O(n) pass over all results.
/// Replaces per-checker array scanning with O(1) field reads.
struct AchievementSnapshot {
    let totalGamesPlayed: Int
    let successCount: Int
    let uniqueGameIds: Set<UUID>
    let uniqueDayCount: Int
    let consecutiveDaysPlayed: Int
    let earlyBirdCount: Int
    let nightOwlCount: Int
    let minimalAttemptWins: Int
    let comebackCount: Int

    static func build(
        from results: [GameResult],
        games: [Game],
        referenceDate: Date = Date()
    ) -> AchievementSnapshot {
        guard !results.isEmpty else {
            return AchievementSnapshot(
                totalGamesPlayed: 0,
                successCount: 0,
                uniqueGameIds: [],
                uniqueDayCount: 0,
                consecutiveDaysPlayed: 0,
                earlyBirdCount: 0,
                nightOwlCount: 0,
                minimalAttemptWins: 0,
                comebackCount: 0
            )
        }

        let calendar = Calendar.current
        let gameLookup = Dictionary(uniqueKeysWithValues: games.map { ($0.id, $0) })

        var uniqueGameIds = Set<UUID>()
        var uniqueDays = Set<Date>()
        var daysByGame = [UUID: Set<Date>]()
        var successCount = 0
        var earlyBirdCount = 0
        var nightOwlCount = 0
        var minimalAttemptWins = 0

        // Single pass over all results
        for result in results {
            uniqueGameIds.insert(result.gameId)

            let day = calendar.startOfDay(for: result.date)
            uniqueDays.insert(day)
            daysByGame[result.gameId, default: []].insert(day)

            if result.isSuccess {
                successCount += 1
            }

            let hour = calendar.component(.hour, from: result.date)
            if hour >= 5 && hour < 9 {
                earlyBirdCount += 1
            } else if hour < 5 {
                nightOwlCount += 1
            }

            if let score = result.score, result.isSuccess,
               let minAttempts = minimalAttempts(
                   for: result.gameId, gameLookup: gameLookup, defaultMax: result.maxAttempts
               ),
               score == minAttempts {
                minimalAttemptWins += 1
            }
        }

        // Derive consecutive days from the deduplicated set
        let consecutiveDays = calculateConsecutiveDays(
            from: uniqueDays, calendar: calendar, referenceDate: referenceDate
        )

        // Derive comeback count from per-game day sets
        let comebackCount = calculateComebacks(from: daysByGame, calendar: calendar)

        return AchievementSnapshot(
            totalGamesPlayed: results.count,
            successCount: successCount,
            uniqueGameIds: uniqueGameIds,
            uniqueDayCount: uniqueDays.count,
            consecutiveDaysPlayed: consecutiveDays,
            earlyBirdCount: earlyBirdCount,
            nightOwlCount: nightOwlCount,
            minimalAttemptWins: minimalAttemptWins,
            comebackCount: comebackCount
        )
    }

    // MARK: - Private Helpers

    private static func calculateConsecutiveDays(
        from uniqueDays: Set<Date>,
        calendar: Calendar,
        referenceDate: Date
    ) -> Int {
        let sortedDays = uniqueDays.sorted()
        guard !sortedDays.isEmpty else { return 0 }

        var currentStreak = 1

        for i in 1..<sortedDays.count {
            let daysBetween = calendar.dateComponents(
                [.day], from: sortedDays[i - 1], to: sortedDays[i]
            ).day ?? 0

            if daysBetween == 1 {
                currentStreak += 1
            } else if daysBetween > 1 {
                currentStreak = 1
            }
        }

        // Check if streak continues to reference date
        if let lastDate = sortedDays.last {
            let daysFromLast = calendar.dateComponents(
                [.day], from: lastDate, to: calendar.startOfDay(for: referenceDate)
            ).day ?? 0

            if daysFromLast > 1 {
                return 0
            }
        }

        return currentStreak
    }

    private static func calculateComebacks(
        from daysByGame: [UUID: Set<Date>],
        calendar: Calendar
    ) -> Int {
        var totalComebacks = 0

        for (_, daySet) in daysByGame {
            let sortedDays = daySet.sorted()
            guard sortedDays.count > 1 else { continue }

            for i in 1..<sortedDays.count {
                let delta = calendar.dateComponents(
                    [.day], from: sortedDays[i - 1], to: sortedDays[i]
                ).day ?? 0
                if delta > 1 {
                    totalComebacks += 1
                }
            }
        }

        return totalComebacks
    }

    private static func minimalAttempts(
        for gameId: UUID,
        gameLookup: [UUID: Game],
        defaultMax: Int
    ) -> Int? {
        guard let game = gameLookup[gameId] else { return nil }
        let name = game.name.lowercased()
        switch name {
        case "wordle", "nerdle", "framed", "xordle", "kilordle", "primel", "rankdle":
            return 1
        case "quordle":
            return 1
        default:
            return defaultMax > 1 ? 1 : nil
        }
    }
}

// MARK: - Achievement Checker

struct TieredAchievementChecker {

    private let logger = Logger(subsystem: "com.streaksync.app", category: "AchievementChecker")

    // MARK: - Check All Achievements

    func checkAllAchievements(
        snapshot: AchievementSnapshot,
        streaks: [GameStreak],
        currentAchievements: inout [TieredAchievement]
    ) -> [AchievementUnlock] {
        var unlocks: [AchievementUnlock] = []

        unlocks.append(contentsOf: checkStreakMaster(streaks: streaks, achievements: &currentAchievements))
        unlocks.append(contentsOf: checkGameCollector(snapshot: snapshot, achievements: &currentAchievements))
        unlocks.append(contentsOf: checkPerfectionist(snapshot: snapshot, achievements: &currentAchievements))
        unlocks.append(contentsOf: checkDailyDevotee(snapshot: snapshot, achievements: &currentAchievements))
        unlocks.append(contentsOf: checkVarietyPlayer(snapshot: snapshot, achievements: &currentAchievements))
        unlocks.append(contentsOf: checkSpeedDemon(snapshot: snapshot, achievements: &currentAchievements))
        unlocks.append(contentsOf: checkTimeBasedAchievements(snapshot: snapshot, achievements: &currentAchievements))
        unlocks.append(contentsOf: checkComebackChampion(snapshot: snapshot, achievements: &currentAchievements))
        unlocks.append(contentsOf: checkMarathonRunner(snapshot: snapshot, achievements: &currentAchievements))

        return unlocks
    }

    // MARK: - Streak Master

    private func checkStreakMaster(
        streaks: [GameStreak],
        achievements: inout [TieredAchievement]
    ) -> [AchievementUnlock] {
        var unlocks: [AchievementUnlock] = []

        // Evaluate best streak across all games (deterministic)
        let bestStreak = streaks.map { max($0.currentStreak, $0.maxStreak) }.max() ?? 0
        guard bestStreak > 0 else { return unlocks }

        if let index = achievements.firstIndex(where: {
            $0.category == .streakMaster &&
            $0.requirements.first?.specificGameId == nil
        }) {
            let oldTier = achievements[index].progress.currentTier
            achievements[index].updateProgress(value: bestStreak)

            if let newTier = achievements[index].progress.currentTier,
               oldTier != newTier {
                unlocks.append(AchievementUnlock(
                    achievement: achievements[index],
                    tier: newTier,
                    timestamp: Date()
                ))
logger.info("Unlocked Streak Master \(newTier.displayName) - \(bestStreak) days")
            }
        }

        return unlocks
    }

    // MARK: - Game Collector

    private func checkGameCollector(
        snapshot: AchievementSnapshot,
        achievements: inout [TieredAchievement]
    ) -> [AchievementUnlock] {
        var unlocks: [AchievementUnlock] = []

        if let index = achievements.firstIndex(where: { $0.category == .gameCollector }) {
            let oldTier = achievements[index].progress.currentTier
            achievements[index].updateProgress(value: snapshot.totalGamesPlayed)

            if let newTier = achievements[index].progress.currentTier,
               oldTier != newTier {
                unlocks.append(AchievementUnlock(
                    achievement: achievements[index],
                    tier: newTier,
                    timestamp: Date()
                ))
logger.info("Unlocked Game Collector \(newTier.displayName) - \(snapshot.totalGamesPlayed) games")
            }
        }

        return unlocks
    }

    // MARK: - Perfectionist

    private func checkPerfectionist(
        snapshot: AchievementSnapshot,
        achievements: inout [TieredAchievement]
    ) -> [AchievementUnlock] {
        var unlocks: [AchievementUnlock] = []

        if let index = achievements.firstIndex(where: { $0.category == .perfectionist }) {
            let oldTier = achievements[index].progress.currentTier
            achievements[index].updateProgress(value: snapshot.successCount)

            if let newTier = achievements[index].progress.currentTier,
               oldTier != newTier {
                unlocks.append(AchievementUnlock(
                    achievement: achievements[index],
                    tier: newTier,
                    timestamp: Date()
                ))
logger.info("Unlocked Perfectionist \(newTier.displayName) - \(snapshot.successCount) perfect games")
            }
        }

        return unlocks
    }

    // MARK: - Daily Devotee

    private func checkDailyDevotee(
        snapshot: AchievementSnapshot,
        achievements: inout [TieredAchievement]
    ) -> [AchievementUnlock] {
        var unlocks: [AchievementUnlock] = []

        if let index = achievements.firstIndex(where: { $0.category == .dailyDevotee }) {
            let oldTier = achievements[index].progress.currentTier
            achievements[index].updateProgress(value: snapshot.consecutiveDaysPlayed)

            if let newTier = achievements[index].progress.currentTier,
               oldTier != newTier {
                unlocks.append(AchievementUnlock(
                    achievement: achievements[index],
                    tier: newTier,
                    timestamp: Date()
                ))
logger.info("Unlocked Daily Devotee \(newTier.displayName) - \(snapshot.consecutiveDaysPlayed) consecutive days")
            }
        }

        return unlocks
    }

    // MARK: - Variety Player

    private func checkVarietyPlayer(
        snapshot: AchievementSnapshot,
        achievements: inout [TieredAchievement]
    ) -> [AchievementUnlock] {
        var unlocks: [AchievementUnlock] = []

        if let index = achievements.firstIndex(where: { $0.category == .varietyPlayer }) {
            let oldTier = achievements[index].progress.currentTier
            // AppState call sites handle monotonic union with uniqueGamesEver
            achievements[index].updateProgress(value: snapshot.uniqueGameIds.count)

            if let newTier = achievements[index].progress.currentTier,
               oldTier != newTier {
                unlocks.append(AchievementUnlock(
                    achievement: achievements[index],
                    tier: newTier,
                    timestamp: Date()
                ))
logger.info("Unlocked Variety Player \(newTier.displayName) - \(snapshot.uniqueGameIds.count) different games")
            }
        }

        return unlocks
    }

    // MARK: - Speed Demon

    private func checkSpeedDemon(
        snapshot: AchievementSnapshot,
        achievements: inout [TieredAchievement]
    ) -> [AchievementUnlock] {
        var unlocks: [AchievementUnlock] = []

        if let index = achievements.firstIndex(where: { $0.category == .speedDemon }) {
            let oldTier = achievements[index].progress.currentTier
            achievements[index].updateProgress(value: snapshot.minimalAttemptWins)

            if let newTier = achievements[index].progress.currentTier,
               oldTier != newTier {
                unlocks.append(AchievementUnlock(
                    achievement: achievements[index],
                    tier: newTier,
                    timestamp: Date()
                ))
logger.info("Unlocked Speed Demon \(newTier.displayName) - minimal-attempt wins: \(snapshot.minimalAttemptWins)")
            }
        }

        return unlocks
    }

    // MARK: - Time-Based Achievements

    private func checkTimeBasedAchievements(
        snapshot: AchievementSnapshot,
        achievements: inout [TieredAchievement]
    ) -> [AchievementUnlock] {
        var unlocks: [AchievementUnlock] = []

        if let index = achievements.firstIndex(where: { $0.category == .earlyBird }) {
            let oldTier = achievements[index].progress.currentTier
            achievements[index].updateProgress(value: snapshot.earlyBirdCount)

            if let newTier = achievements[index].progress.currentTier,
               oldTier != newTier {
                unlocks.append(AchievementUnlock(
                    achievement: achievements[index],
                    tier: newTier,
                    timestamp: Date()
                ))
            }
        }

        if let index = achievements.firstIndex(where: { $0.category == .nightOwl }) {
            let oldTier = achievements[index].progress.currentTier
            achievements[index].updateProgress(value: snapshot.nightOwlCount)

            if let newTier = achievements[index].progress.currentTier,
               oldTier != newTier {
                unlocks.append(AchievementUnlock(
                    achievement: achievements[index],
                    tier: newTier,
                    timestamp: Date()
                ))
            }
        }

        return unlocks
    }

    // MARK: - Comeback Champion

    private func checkComebackChampion(
        snapshot: AchievementSnapshot,
        achievements: inout [TieredAchievement]
    ) -> [AchievementUnlock] {
        var unlocks: [AchievementUnlock] = []

        if let index = achievements.firstIndex(where: { $0.category == .comebackChampion }) {
            let oldTier = achievements[index].progress.currentTier
            // Monotonic guard: never decrease on partial histories
            let newValue = max(achievements[index].progress.currentValue, snapshot.comebackCount)
            achievements[index].updateProgress(value: newValue)

            if let newTier = achievements[index].progress.currentTier,
               oldTier != newTier {
                unlocks.append(AchievementUnlock(
                    achievement: achievements[index],
                    tier: newTier,
                    timestamp: Date()
                ))
            }
        }

        return unlocks
    }

    // MARK: - Marathon Runner

    private func checkMarathonRunner(
        snapshot: AchievementSnapshot,
        achievements: inout [TieredAchievement]
    ) -> [AchievementUnlock] {
        var unlocks: [AchievementUnlock] = []

        if let index = achievements.firstIndex(where: { $0.category == .marathonRunner }) {
            let oldTier = achievements[index].progress.currentTier
            achievements[index].updateProgress(value: snapshot.uniqueDayCount)

            if let newTier = achievements[index].progress.currentTier,
               oldTier != newTier {
                unlocks.append(AchievementUnlock(
                    achievement: achievements[index],
                    tier: newTier,
                    timestamp: Date()
                ))
logger.info("Unlocked Marathon Runner \(newTier.displayName) - \(snapshot.uniqueDayCount) active days")
            }
        }

        return unlocks
    }
}

// MARK: - Achievement Unlock Model
struct AchievementUnlock {
    let achievement: TieredAchievement
    let tier: AchievementTier
    let timestamp: Date
}
