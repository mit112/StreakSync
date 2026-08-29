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
    /// Lifetime-scoped. The capped result window unioned with the caller's
    /// `uniqueGamesEver`. Variety Player is the only consumer and is lifetime-scoped,
    /// so the union has to be folded in *before* the checker runs — Completionist
    /// reads Variety Player's tier in the same pass.
    let uniqueGameIds: Set<UUID>
    let uniqueDayCount: Int
    let consecutiveDaysPlayed: Int
    let minimalAttemptWins: Int
    let personalBestCount: Int
    let friendCount: Int

    static func build(
        from results: [GameResult],
        games: [Game],
        friendCount: Int = 0,
        lifetimeActiveDayCount: Int = 0,
        lifetimeUniqueGameIds: Set<UUID> = [],
        referenceDate: Date = Date()
    ) -> AchievementSnapshot {
        guard !results.isEmpty else {
            return AchievementSnapshot(
                totalGamesPlayed: 0,
                successCount: 0,
                uniqueGameIds: lifetimeUniqueGameIds,
                uniqueDayCount: 0,
                consecutiveDaysPlayed: 0,
                minimalAttemptWins: 0,
                personalBestCount: 0,
                friendCount: friendCount
            )
        }

        let calendar = Calendar.current
        let gameLookup = Dictionary(uniqueKeysWithValues: games.map { ($0.id, $0) })

        var uniqueGameIds = Set<UUID>()
        var uniqueDays = Set<Date>()
        var successCount = 0
        var minimalAttemptWins = 0

        // Single pass over all results
        for result in results {
            uniqueGameIds.insert(result.gameId)

            let day = calendar.startOfDay(for: result.date)
            uniqueDays.insert(day)

            if result.isSuccess {
                successCount += 1
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

        // Derive personal best count from results
        let personalBestCount = calculatePersonalBests(from: results, gameLookup: gameLookup)

        return AchievementSnapshot(
            totalGamesPlayed: results.count,
            successCount: successCount,
            uniqueGameIds: uniqueGameIds.union(lifetimeUniqueGameIds),
            // `uniqueDays` only sees the capped result window, so fall back to the caller's
            // monotonic lifetime count once pruning starts discarding older days.
            uniqueDayCount: max(uniqueDays.count, lifetimeActiveDayCount),
            consecutiveDaysPlayed: consecutiveDays,
            minimalAttemptWins: minimalAttemptWins,
            personalBestCount: personalBestCount,
            friendCount: friendCount
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

    /// Counts games where the user beat their previous best score.
    /// Respects `Game.scoringModel.isLowerBetter` for each game — lower is better
    /// for word games (Wordle), higher is better for score-based games (Spelling Bee).
    private static func calculatePersonalBests(
        from results: [GameResult],
        gameLookup: [UUID: Game]
    ) -> Int {
        let grouped = Dictionary(grouping: results) { $0.gameId }
        var totalBests = 0

        for (gameId, gameResults) in grouped {
            let isLowerBetter = gameLookup[gameId]?.scoringModel.isLowerBetter ?? true
            let sorted = gameResults.sorted { $0.date < $1.date }
            var bestScore: Int?

            for result in sorted {
                guard let score = result.score, result.isSuccess else { continue }
                if let previous = bestScore {
                    let isBetter = isLowerBetter ? score < previous : score > previous
                    if isBetter {
                        totalBests += 1
                        bestScore = score
                    }
                } else {
                    bestScore = score
                }
            }
        }

        return totalBests
    }

    private static func minimalAttempts(
        for gameId: UUID,
        gameLookup: [UUID: Game],
        defaultMax: Int
    ) -> Int? {
        guard gameLookup[gameId] != nil else { return nil }
        return defaultMax > 1 ? 1 : nil
    }
}

// MARK: - Achievement Metric

/// One table row per snapshot-driven achievement category.
///
/// The nine per-category checkers used to be near-identical 25-line copies of the same
/// find-index / read-old-tier / update / emit-unlock shape, and that duplication is what
/// let Completionist read a stale Variety Player tier. Adding a category is now one row
/// in `TieredAchievementChecker.snapshotMetrics`, evaluated in declaration order.
private struct AchievementMetric: Sendable {
    let category: AchievementCategory
    /// Unit shown in the unlock log line ("games", "active days", ...).
    let unit: String
    /// Receives the matched achievement as well as the snapshot, so a metric can floor
    /// itself at its own stored value instead of only reading the snapshot.
    let value: @Sendable (AchievementSnapshot, TieredAchievement) -> Int
}

// MARK: - Achievement Checker

struct TieredAchievementChecker {
    private let logger = Logger(subsystem: "com.streaksync.app", category: "AchievementChecker")

    /// Snapshot-driven categories, in evaluation order. Streak Master (extra predicate
    /// clause plus an early exit) and Completionist (value derived from the other rows'
    /// tiers) are deliberately not in this table — see `checkAllAchievements`.
    private static let snapshotMetrics: [AchievementMetric] = [
        AchievementMetric(category: .gameCollector, unit: "games") { snapshot, _ in
            snapshot.totalGamesPlayed
        },
        AchievementMetric(category: .perfectionist, unit: "perfect games") { snapshot, _ in
            snapshot.successCount
        },
        AchievementMetric(category: .dailyDevotee, unit: "consecutive days") { snapshot, _ in
            snapshot.consecutiveDaysPlayed
        },
        // `snapshot.uniqueGameIds` carries the union with the caller's lifetime
        // `uniqueGamesEver`. Floor it at the stored value too: a device restored from a
        // >500-result history can pull down an achievement whose true count predates
        // anything in the synced window, and Variety Player must never walk backwards.
        AchievementMetric(category: .varietyPlayer, unit: "different games") { snapshot, achievement in
            max(achievement.progress.currentValue, snapshot.uniqueGameIds.count)
        },
        AchievementMetric(category: .speedDemon, unit: "minimal-attempt wins") { snapshot, _ in
            snapshot.minimalAttemptWins
        },
        AchievementMetric(category: .marathonRunner, unit: "active days") { snapshot, _ in
            snapshot.uniqueDayCount
        },
        AchievementMetric(category: .personalBest, unit: "personal bests") { snapshot, _ in
            snapshot.personalBestCount
        },
        AchievementMetric(category: .socialPlayer, unit: "friends") { snapshot, _ in
            snapshot.friendCount
        }
    ]

    // MARK: - Check All Achievements

    /// Order is load-bearing: Completionist counts how many *other* categories sit at
    /// Gold or above, so every other category must already have been updated in this
    /// same pass before it runs.
    func checkAllAchievements(
        snapshot: AchievementSnapshot,
        streaks: [GameStreak],
        currentAchievements: inout [TieredAchievement]
    ) -> [AchievementUnlock] {
        var unlocks = checkStreakMaster(streaks: streaks, achievements: &currentAchievements)

        for metric in Self.snapshotMetrics {
            unlocks.append(contentsOf: applyProgress(
                to: &currentAchievements,
                name: metric.category.displayName,
                unit: metric.unit,
                matching: { $0.category == metric.category },
                value: { metric.value(snapshot, $0) }
            ))
        }

        // Completionist runs AFTER all others (depends on their tiers)
        unlocks.append(contentsOf: checkCompletionist(achievements: &currentAchievements))

        return unlocks
    }

    // MARK: - Streak Master

    /// Not table-driven: it matches the all-games row rather than any per-game row, and
    /// skips the update entirely when there is no streak yet.
    private func checkStreakMaster(
        streaks: [GameStreak],
        achievements: inout [TieredAchievement]
    ) -> [AchievementUnlock] {
        // Evaluate best streak across all games (deterministic)
        let bestStreak = streaks.map { max($0.currentStreak, $0.maxStreak) }.max() ?? 0
        guard bestStreak > 0 else { return [] }

        return applyProgress(
            to: &achievements,
            name: AchievementCategory.streakMaster.displayName,
            unit: "days",
            matching: {
                $0.category == .streakMaster && $0.requirements.first?.specificGameId == nil
            },
            value: { _ in bestStreak }
        )
    }

    // MARK: - Completionist (meta-achievement, runs after all others)

    /// Not table-driven: its value comes from the whole `achievements` array, read before
    /// the mutation so Completionist can never fold in its own tier.
    private func checkCompletionist(
        achievements: inout [TieredAchievement]
    ) -> [AchievementUnlock] {
        // Count categories (excluding completionist itself) at Gold or above
        let goldOrAboveCount = achievements.filter { achievement in
            achievement.category != .completionist &&
            !achievement.category.isRetired &&
            (achievement.progress.currentTier?.rawValue ?? 0) >= AchievementTier.gold.rawValue
        }.count

        return applyProgress(
            to: &achievements,
            name: AchievementCategory.completionist.displayName,
            unit: "categories at Gold+",
            matching: { $0.category == .completionist },
            value: { _ in goldOrAboveCount }
        )
    }

    // MARK: - Shared Progress Application

    /// The single place a tier is ever raised: find the achievement, apply the metric's
    /// value, and emit an unlock when that crossed into a new tier.
    private func applyProgress(
        to achievements: inout [TieredAchievement],
        name: String,
        unit: String,
        matching predicate: (TieredAchievement) -> Bool,
        value: (TieredAchievement) -> Int
    ) -> [AchievementUnlock] {
        guard let index = achievements.firstIndex(where: predicate) else { return [] }

        let oldTier = achievements[index].progress.currentTier
        // `value` is handed the matched achievement, not just the snapshot, so a metric
        // can floor itself at its own stored `progress.currentValue`.
        let newValue = value(achievements[index])
        achievements[index].updateProgress(value: newValue)

        guard let newTier = achievements[index].progress.currentTier, newTier != oldTier else {
            return []
        }

        let summary = "\(name) \(newTier.displayName) - \(newValue) \(unit)"
        logger.info("Unlocked \(summary, privacy: .public)")

        let unlock = AchievementUnlock(
            achievement: achievements[index],
            tier: newTier,
            timestamp: Date()
        )
        return [unlock]
    }
}

// MARK: - Achievement Unlock Model
struct AchievementUnlock {
    let achievement: TieredAchievement
    let tier: AchievementTier
    let timestamp: Date
}
