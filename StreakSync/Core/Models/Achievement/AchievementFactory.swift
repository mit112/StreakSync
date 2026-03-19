//
//  AchievementFactory.swift
//  StreakSync
//
//  Factory methods for creating default tiered achievements
//

import Foundation

// MARK: - Achievement Factory
struct AchievementFactory {

    // MARK: - Streak Master Achievement
    static func createStreakMasterAchievement(for gameId: UUID? = nil) -> TieredAchievement {
        TieredAchievement(
            id: AchievementCategory.streakMaster.consistentID,
            category: .streakMaster,
            requirements: [
                TierRequirement(tier: .bronze, threshold: 3, specificGameId: gameId),
                TierRequirement(tier: .silver, threshold: 7, specificGameId: gameId),
                TierRequirement(tier: .gold, threshold: 14, specificGameId: gameId),
                TierRequirement(tier: .diamond, threshold: 30, specificGameId: gameId),
                TierRequirement(tier: .legendary, threshold: 60, specificGameId: gameId)
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
                TierRequirement(tier: .silver, threshold: 25),
                TierRequirement(tier: .gold, threshold: 50),
                TierRequirement(tier: .diamond, threshold: 100),
                TierRequirement(tier: .legendary, threshold: 250)
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
                TierRequirement(tier: .silver, threshold: 15),
                TierRequirement(tier: .gold, threshold: 30),
                TierRequirement(tier: .diamond, threshold: 75),
                TierRequirement(tier: .legendary, threshold: 150)
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
                TierRequirement(tier: .legendary, threshold: 60)
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
                TierRequirement(tier: .legendary, threshold: 16)
            ]
        )
    }

    // MARK: - Speed Demon Achievement
    static func createSpeedDemonAchievement() -> TieredAchievement {
        TieredAchievement(
            id: AchievementCategory.speedDemon.consistentID,
            category: .speedDemon,
            requirements: [
                TierRequirement(tier: .bronze, threshold: 1),
                TierRequirement(tier: .silver, threshold: 5),
                TierRequirement(tier: .gold, threshold: 10),
                TierRequirement(tier: .diamond, threshold: 25),
                TierRequirement(tier: .legendary, threshold: 50)
            ]
        )
    }

    // MARK: - Marathon Runner Achievement
    static func createMarathonRunnerAchievement() -> TieredAchievement {
        TieredAchievement(
            id: AchievementCategory.marathonRunner.consistentID,
            category: .marathonRunner,
            requirements: [
                TierRequirement(tier: .bronze, threshold: 7),
                TierRequirement(tier: .silver, threshold: 30),
                TierRequirement(tier: .gold, threshold: 60),
                TierRequirement(tier: .diamond, threshold: 120),
                TierRequirement(tier: .legendary, threshold: 365)
            ]
        )
    }

    // MARK: - Personal Best Achievement
    static func createPersonalBestAchievement() -> TieredAchievement {
        TieredAchievement(
            id: AchievementCategory.personalBest.consistentID,
            category: .personalBest,
            requirements: [
                TierRequirement(tier: .bronze, threshold: 1),
                TierRequirement(tier: .silver, threshold: 3),
                TierRequirement(tier: .gold, threshold: 5),
                TierRequirement(tier: .diamond, threshold: 10),
                TierRequirement(tier: .legendary, threshold: 20)
            ]
        )
    }

    // MARK: - Social Player Achievement
    static func createSocialPlayerAchievement() -> TieredAchievement {
        TieredAchievement(
            id: AchievementCategory.socialPlayer.consistentID,
            category: .socialPlayer,
            requirements: [
                TierRequirement(tier: .bronze, threshold: 1),
                TierRequirement(tier: .silver, threshold: 3),
                TierRequirement(tier: .gold, threshold: 5),
                TierRequirement(tier: .diamond, threshold: 10),
                TierRequirement(tier: .legendary, threshold: 15)
            ]
        )
    }

    // MARK: - Completionist Achievement (meta-achievement, 4 tiers)
    static func createCompletionistAchievement() -> TieredAchievement {
        TieredAchievement(
            id: AchievementCategory.completionist.consistentID,
            category: .completionist,
            requirements: [
                TierRequirement(tier: .bronze, threshold: 3),
                TierRequirement(tier: .silver, threshold: 5),
                TierRequirement(tier: .gold, threshold: 7),
                TierRequirement(tier: .diamond, threshold: 9)
            ]
        )
    }

    // MARK: - Retired Achievement Factories (kept for Codable backward compat in tests)

    static func createEarlyBirdAchievement() -> TieredAchievement {
        TieredAchievement(
            id: AchievementCategory.earlyBird.consistentID,
            category: .earlyBird,
            requirements: [
                TierRequirement(tier: .bronze, threshold: 1),
                TierRequirement(tier: .silver, threshold: 5),
                TierRequirement(tier: .gold, threshold: 10),
                TierRequirement(tier: .diamond, threshold: 20)
            ]
        )
    }

    static func createNightOwlAchievement() -> TieredAchievement {
        TieredAchievement(
            id: AchievementCategory.nightOwl.consistentID,
            category: .nightOwl,
            requirements: [
                TierRequirement(tier: .bronze, threshold: 1),
                TierRequirement(tier: .silver, threshold: 5),
                TierRequirement(tier: .gold, threshold: 10),
                TierRequirement(tier: .diamond, threshold: 20)
            ]
        )
    }

    static func createComebackChampionAchievement() -> TieredAchievement {
        TieredAchievement(
            id: AchievementCategory.comebackChampion.consistentID,
            category: .comebackChampion,
            requirements: [
                TierRequirement(tier: .bronze, threshold: 1),
                TierRequirement(tier: .silver, threshold: 7),
                TierRequirement(tier: .gold, threshold: 14),
                TierRequirement(tier: .diamond, threshold: 30)
            ]
        )
    }

    // MARK: - All Default Achievements (active categories only)
    static func createDefaultAchievements() -> [TieredAchievement] {
        [
            createStreakMasterAchievement(),
            createGameCollectorAchievement(),
            createPerfectionistAchievement(),
            createDailyDevoteeAchievement(),
            createVarietyPlayerAchievement(),
            createSpeedDemonAchievement(),
            createMarathonRunnerAchievement(),
            createPersonalBestAchievement(),
            createSocialPlayerAchievement(),
            createCompletionistAchievement()
        ]
    }
}
