//
//  AchievementFactory.swift
//  StreakSync
//
//  Factory methods for creating default tiered achievements
//

import Foundation

// MARK: - Achievement Factory
struct AchievementFactory {

    // MARK: - Streak Master Achievement (fixed naming)
    static func createStreakMasterAchievement(for gameId: UUID? = nil) -> TieredAchievement {
        TieredAchievement(
            id: AchievementCategory.streakMaster.consistentID,
            category: .streakMaster,
            requirements: [
                TierRequirement(tier: .bronze, threshold: 3, specificGameId: gameId),
                TierRequirement(tier: .silver, threshold: 7, specificGameId: gameId),
                TierRequirement(tier: .gold, threshold: 14, specificGameId: gameId),
                TierRequirement(tier: .diamond, threshold: 30, specificGameId: gameId),
                TierRequirement(tier: .master, threshold: 60, specificGameId: gameId),
                TierRequirement(tier: .legendary, threshold: 100, specificGameId: gameId)
            ]
        )
    }

    // MARK: - Game Collector Achievement
    static func createGameCollectorAchievement() -> TieredAchievement {
        TieredAchievement(
            id: AchievementCategory.gameCollector.consistentID,
            category: .gameCollector,
            requirements: [
                TierRequirement(tier: .bronze, threshold: 10),
                TierRequirement(tier: .silver, threshold: 50),
                TierRequirement(tier: .gold, threshold: 100),
                TierRequirement(tier: .diamond, threshold: 250),
                TierRequirement(tier: .master, threshold: 500),
                TierRequirement(tier: .legendary, threshold: 1000)
            ]
        )
    }

    // MARK: - Perfectionist Achievement
    static func createPerfectionistAchievement() -> TieredAchievement {
        TieredAchievement(
            id: AchievementCategory.perfectionist.consistentID,
            category: .perfectionist,
            requirements: [
                TierRequirement(tier: .bronze, threshold: 5),
                TierRequirement(tier: .silver, threshold: 25),
                TierRequirement(tier: .gold, threshold: 50),
                TierRequirement(tier: .diamond, threshold: 100),
                TierRequirement(tier: .master, threshold: 250),
                TierRequirement(tier: .legendary, threshold: 500)
            ]
        )
    }

    // MARK: - Daily Devotee Achievement
    static func createDailyDevoteeAchievement() -> TieredAchievement {
        TieredAchievement(
            id: AchievementCategory.dailyDevotee.consistentID,
            category: .dailyDevotee,
            requirements: [
                TierRequirement(tier: .bronze, threshold: 3),
                TierRequirement(tier: .silver, threshold: 7),
                TierRequirement(tier: .gold, threshold: 14),
                TierRequirement(tier: .diamond, threshold: 30),
                TierRequirement(tier: .master, threshold: 60)
            ]
        )
    }

    // MARK: - Variety Player Achievement
    static func createVarietyPlayerAchievement() -> TieredAchievement {
        TieredAchievement(
            id: AchievementCategory.varietyPlayer.consistentID,
            category: .varietyPlayer,
            requirements: [
                TierRequirement(tier: .bronze, threshold: 3),
                TierRequirement(tier: .silver, threshold: 5),
                TierRequirement(tier: .gold, threshold: 8),
                TierRequirement(tier: .diamond, threshold: 12),
                TierRequirement(tier: .master, threshold: 15),
                TierRequirement(tier: .legendary, threshold: 20)
            ]
        )
    }

    // MARK: - Speed Demon Achievement
    static func createSpeedDemonAchievement() -> TieredAchievement {
        TieredAchievement(
            id: AchievementCategory.speedDemon.consistentID,
            category: .speedDemon,
            requirements: [
                TierRequirement(tier: .bronze, threshold: 1),    // Win in minimum attempts once
                TierRequirement(tier: .silver, threshold: 5),    // Win in minimum attempts 5 times
                TierRequirement(tier: .gold, threshold: 10),     // Win in minimum attempts 10 times
                TierRequirement(tier: .diamond, threshold: 20),  // Win in minimum attempts 20 times
                TierRequirement(tier: .master, threshold: 50),   // Win in minimum attempts 50 times
                TierRequirement(tier: .legendary, threshold: 100) // Win in minimum attempts 100 times
            ]
        )
    }

    // MARK: - Early Bird Achievement
    static func createEarlyBirdAchievement() -> TieredAchievement {
        TieredAchievement(
            id: AchievementCategory.earlyBird.consistentID,
            category: .earlyBird,
            requirements: [
                TierRequirement(tier: .bronze, threshold: 1),   // Count plays between 05:00-08:59
                TierRequirement(tier: .silver, threshold: 5),   // Same band; tiers reflect total occurrences
                TierRequirement(tier: .gold, threshold: 10),    // Same band; tiers reflect total occurrences
                TierRequirement(tier: .diamond, threshold: 20)  // Same band; tiers reflect total occurrences
            ]
        )
    }

    // MARK: - Night Owl Achievement
    static func createNightOwlAchievement() -> TieredAchievement {
        TieredAchievement(
            id: AchievementCategory.nightOwl.consistentID,
            category: .nightOwl,
            requirements: [
                TierRequirement(tier: .bronze, threshold: 1),   // Count plays between 00:00-04:59
                TierRequirement(tier: .silver, threshold: 5),   // Same band; tiers reflect total occurrences
                TierRequirement(tier: .gold, threshold: 10),    // Same band; tiers reflect total occurrences
                TierRequirement(tier: .diamond, threshold: 20)  // Same band; tiers reflect total occurrences
            ]
        )
    }

    // MARK: - Comeback Champion Achievement
    static func createComebackChampionAchievement() -> TieredAchievement {
        TieredAchievement(
            id: AchievementCategory.comebackChampion.consistentID,
            category: .comebackChampion,
            requirements: [
                TierRequirement(tier: .bronze, threshold: 1),   // 1 comeback
                TierRequirement(tier: .silver, threshold: 7),   // 7 total comebacks
                TierRequirement(tier: .gold, threshold: 14),    // 14 total comebacks
                TierRequirement(tier: .diamond, threshold: 30)  // 30 total comebacks
            ]
        )
    }

    // MARK: - Marathon Runner Achievement
    static func createMarathonRunnerAchievement() -> TieredAchievement {
        TieredAchievement(
            id: AchievementCategory.marathonRunner.consistentID,
            category: .marathonRunner,
            requirements: [
                TierRequirement(tier: .bronze, threshold: 10),
                TierRequirement(tier: .silver, threshold: 30),
                TierRequirement(tier: .gold, threshold: 60),
                TierRequirement(tier: .diamond, threshold: 100),
                TierRequirement(tier: .master, threshold: 365)
            ]
        )
    }

    // MARK: - All Default Achievements
    static func createDefaultAchievements() -> [TieredAchievement] {
        [
            createStreakMasterAchievement(),
            createGameCollectorAchievement(),
            createPerfectionistAchievement(),
            createDailyDevoteeAchievement(),
            createVarietyPlayerAchievement(),
            createSpeedDemonAchievement(),
            createEarlyBirdAchievement(),
            createNightOwlAchievement(),
            createComebackChampionAchievement(),
            createMarathonRunnerAchievement()
        ]
    }
}
