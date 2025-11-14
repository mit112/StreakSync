//
//  TieredAchievementModels.swift
//  StreakSync
//
//  Enhanced achievement system with tier progression
//

import Foundation
import SwiftUI

// MARK: - Achievement Tier
enum AchievementTier: Int, CaseIterable, Codable, Sendable {
    case bronze = 1
    case silver = 2
    case gold = 3
    case diamond = 4
    case master = 5
    case legendary = 6
    
    var id: UUID {
        // Create a consistent UUID based on the tier
        let uuidString = "00000000-0000-0000-0000-00000000000\(rawValue)"
        return UUID(uuidString: uuidString) ?? UUID()
    }
    
    var displayName: String {
        switch self {
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold: return "Gold"
        case .diamond: return "Diamond"
        case .master: return "Master"
        case .legendary: return "Legendary"
        }
    }
    
    var color: Color {
        switch self {
        case .bronze: return Color(red: 0.80, green: 0.50, blue: 0.20)
        case .silver: return Color(red: 0.75, green: 0.75, blue: 0.75)
        case .gold: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case .diamond: return Color(red: 0.73, green: 0.91, blue: 1.0)
        case .master: return Color(red: 0.58, green: 0.0, blue: 0.83)
        case .legendary: return Color(red: 1.0, green: 0.0, blue: 0.5)
        }
    }
    
    var iconSystemName: String {
        switch self {
        case .bronze, .silver, .gold:
            return "trophy.fill"
        case .diamond:
            return SFSymbolCompatibility.getSymbol("diamond.fill")
        case .master:
            return "star.fill"
        case .legendary:
            return "crown.fill"
        }
    }
    
    var glowIntensity: Double {
        switch self {
        case .bronze: return 0.2
        case .silver: return 0.3
        case .gold: return 0.4
        case .diamond: return 0.5
        case .master: return 0.6
        case .legendary: return 0.8
        }
    }
}

// MARK: - Achievement Category
enum AchievementCategory: String, CaseIterable, Codable, Sendable {
    case streakMaster = "streak_master"
    case gameCollector = "game_collector"
    case perfectionist = "perfectionist"
    case dailyDevotee = "daily_devotee"
    case varietyPlayer = "variety_player"
    case speedDemon = "speed_demon"
    case earlyBird = "early_bird"
    case nightOwl = "night_owl"
    case comebackChampion = "comeback_champion"
    case marathonRunner = "marathon_runner"
    
    var displayName: String {
        switch self {
        case .streakMaster: return "Streak Master"
        case .gameCollector: return "Game Collector"
        case .perfectionist: return "Perfectionist"
        case .dailyDevotee: return "Daily Devotee"
        case .varietyPlayer: return "Variety Player"
        case .speedDemon: return "Speed Demon"
        case .earlyBird: return "Early Bird"
        case .nightOwl: return "Night Owl"
        case .comebackChampion: return "Comeback Champion"
        case .marathonRunner: return "Marathon Runner"
        }
    }
    
    var baseIconSystemName: String {
        switch self {
        case .streakMaster: return "flame.fill"
        case .gameCollector: return "gamecontroller.fill"
        case .perfectionist: return "checkmark.seal.fill"
        case .dailyDevotee: return "calendar.badge.checkmark"
        case .varietyPlayer: return "square.grid.3x3.fill"
        case .speedDemon: return "bolt.fill"
        case .earlyBird: return "sunrise.fill"
        case .nightOwl: return "moon.stars.fill"
        case .comebackChampion: return "arrow.counterclockwise.circle.fill"
        case .marathonRunner: return "figure.run"
        }
    }
    
    var description: String {
        switch self {
        case .streakMaster: return "Maintain consecutive day streaks for individual games"
        case .gameCollector: return "Play games across all categories"
        case .perfectionist: return "Complete games successfully without failing"
        case .dailyDevotee: return "Play at least one game every day"
        case .varietyPlayer: return "Play many different games over time"
        case .speedDemon: return "Win games with minimal attempts"
        case .earlyBird: return "Play games in the early morning"
        case .nightOwl: return "Play games late at night"
        case .comebackChampion: return "Rebuild streaks after they break"
        case .marathonRunner: return "Stay active for extended periods"
        }
    }
}

// MARK: - Tier Requirement
struct TierRequirement: Codable, Hashable, Sendable {
    let tier: AchievementTier
    let threshold: Int
    let specificGameId: UUID?
    
    init(tier: AchievementTier, threshold: Int, specificGameId: UUID? = nil) {
        self.tier = tier
        self.threshold = threshold
        self.specificGameId = specificGameId
    }
}

// MARK: - Achievement Progress
struct AchievementProgress: Codable, Hashable, Sendable {
    var currentValue: Int
    var currentTier: AchievementTier?
    var tierUnlockDates: [AchievementTier: Date]
    var lastUpdated: Date
    
    init(
        currentValue: Int = 0,
        currentTier: AchievementTier? = nil,
        tierUnlockDates: [AchievementTier: Date] = [:],
        lastUpdated: Date = Date()
    ) {
        self.currentValue = currentValue
        self.currentTier = currentTier
        self.tierUnlockDates = tierUnlockDates
        self.lastUpdated = lastUpdated
    }
    
    var nextTier: AchievementTier? {
        guard let current = currentTier else { return .bronze }
        return AchievementTier.allCases.first { $0.rawValue == current.rawValue + 1 }
    }
    
    func percentageToNextTier(requirements: [TierRequirement]) -> Double {
        guard let nextTier = nextTier else { return 1.0 }
        guard let nextRequirement = requirements.first(where: { $0.tier == nextTier }) else { return 0.0 }
        
        let previousThreshold: Int
        if let currentTier = currentTier,
           let currentRequirement = requirements.first(where: { $0.tier == currentTier }) {
            previousThreshold = currentRequirement.threshold
        } else {
            previousThreshold = 0
        }
        
        let range = nextRequirement.threshold - previousThreshold
        guard range > 0 else { return 0.0 } // Prevent division by zero
        
        let progress = currentValue - previousThreshold
        
        return min(1.0, max(0.0, Double(progress) / Double(range)))
    }
    
    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(currentValue)
        hasher.combine(currentTier)
        hasher.combine(lastUpdated)
        // Convert dictionary to sorted array for consistent hashing
        let sortedUnlocks = tierUnlockDates.sorted { $0.key.rawValue < $1.key.rawValue }
        for (tier, date) in sortedUnlocks {
            hasher.combine(tier)
            hasher.combine(date)
        }
    }
    
    // MARK: - Equatable
    static func == (lhs: AchievementProgress, rhs: AchievementProgress) -> Bool {
        lhs.currentValue == rhs.currentValue &&
        lhs.currentTier == rhs.currentTier &&
        lhs.tierUnlockDates == rhs.tierUnlockDates &&
        lhs.lastUpdated == rhs.lastUpdated
    }
}

// MARK: - Tiered Achievement
struct TieredAchievement: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let category: AchievementCategory
    let requirements: [TierRequirement]
    var progress: AchievementProgress
    
    init(
        id: UUID = UUID(),
        category: AchievementCategory,
        requirements: [TierRequirement],
        progress: AchievementProgress = AchievementProgress()
    ) {
        self.id = id
        self.category = category
        self.requirements = requirements.sorted { $0.tier.rawValue < $1.tier.rawValue }
        self.progress = progress
    }
    
    // MARK: - Computed Properties
    
    var displayName: String {
        category.displayName
    }
    
    var description: String {
        category.description
    }
    
    var iconSystemName: String {
        category.baseIconSystemName
    }
    
    var currentTierColor: Color {
        progress.currentTier?.color ?? Color(.systemGray3)
    }
    
    var isUnlocked: Bool {
        progress.currentTier != nil
    }
    
    var highestUnlockedTier: AchievementTier? {
        progress.currentTier
    }
    
    var nextTierRequirement: TierRequirement? {
        guard let nextTier = progress.nextTier else { return nil }
        return requirements.first { $0.tier == nextTier }
    }
    
    var progressDescription: String {
        if progress.currentTier != nil {
            if let next = nextTierRequirement {
                return "\(progress.currentValue)/\(next.threshold)"
            } else {
                return "\(progress.currentValue) (Max)"
            }
        } else if let next = nextTierRequirement {
            return "\(progress.currentValue)/\(next.threshold)"
        }
        return "Not started"
    }

    
    // MARK: - Progress Update
    
    mutating func updateProgress(value: Int) {
        progress.currentValue = value
        progress.lastUpdated = Date()
        
        // Check for tier unlocks
        for requirement in requirements.reversed() {
            if value >= requirement.threshold && (progress.currentTier == nil || requirement.tier.rawValue > progress.currentTier!.rawValue) {
                // Unlock new tier
                progress.currentTier = requirement.tier
                if progress.tierUnlockDates[requirement.tier] == nil {
                    progress.tierUnlockDates[requirement.tier] = Date()
                }
            }
        }
    }
    
    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(category)
        hasher.combine(requirements)
        hasher.combine(progress)
    }
    
    // MARK: - Equatable
    static func == (lhs: TieredAchievement, rhs: TieredAchievement) -> Bool {
        lhs.id == rhs.id &&
        lhs.category == rhs.category &&
        lhs.requirements == rhs.requirements &&
        lhs.progress == rhs.progress
    }
}

// MARK: - Achievement Factory
struct AchievementFactory {
    
    // MARK: - Streak Master Achievement (fixed naming)
    static func createStreakMasterAchievement(for gameId: UUID? = nil) -> TieredAchievement {
        TieredAchievement(
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
        // Dynamic, sensible tiers based on catalog size (all-time unique games)
        let total = max(1, Game.allAvailableGames.count)
        
        // Candidate thresholds scaled for progression
        let candidates: [(AchievementTier, Int)] = [
            (.bronze, min(3, total)),
            (.silver, min(5, total)),
            (.gold,   min(8, total)),
            (.diamond,min(12, total)),
            (.master, min(15, total)),
            (.legendary, total) // All available games
        ]
        
        // Keep strictly increasing thresholds (avoid duplicates for small catalogs)
        var requirements: [TierRequirement] = []
        var lastThreshold = 0
        for (tier, threshold) in candidates {
            guard threshold > lastThreshold else { continue }
            requirements.append(TierRequirement(tier: tier, threshold: threshold))
            lastThreshold = threshold
            if threshold >= total { break } // stop once we've covered full catalog
        }
        
        return TieredAchievement(
            category: .varietyPlayer,
            requirements: requirements
        )
    }
    
    // MARK: - Speed Demon Achievement
    static func createSpeedDemonAchievement() -> TieredAchievement {
        TieredAchievement(
            category: .speedDemon,
            requirements: [
                TierRequirement(tier: .bronze, threshold: 1),    // Win in ≤3 attempts once
                TierRequirement(tier: .silver, threshold: 5),    // Win in ≤3 attempts 5 times
                TierRequirement(tier: .gold, threshold: 10),     // Win in ≤3 attempts 10 times
                TierRequirement(tier: .diamond, threshold: 20),  // Win in ≤3 attempts 20 times
                TierRequirement(tier: .master, threshold: 50),   // Win in ≤3 attempts 50 times
                TierRequirement(tier: .legendary, threshold: 100) // Win in ≤3 attempts 100 times
            ]
        )
    }
    
    // MARK: - Early Bird Achievement
    static func createEarlyBirdAchievement() -> TieredAchievement {
        TieredAchievement(
            category: .earlyBird,
            requirements: [
                TierRequirement(tier: .bronze, threshold: 1),   // Count plays between 05:00–08:59 (occurrence count tiers)
                TierRequirement(tier: .silver, threshold: 5),   // Same band; tiers reflect total occurrences
                TierRequirement(tier: .gold, threshold: 10),    // Same band; tiers reflect total occurrences
                TierRequirement(tier: .diamond, threshold: 20)  // Same band; tiers reflect total occurrences
            ]
        )
    }
    
    // MARK: - Night Owl Achievement
    static func createNightOwlAchievement() -> TieredAchievement {
        TieredAchievement(
            category: .nightOwl,
            requirements: [
                TierRequirement(tier: .bronze, threshold: 1),   // Count plays between 00:00–04:59 (occurrence count tiers)
                TierRequirement(tier: .silver, threshold: 5),   // Same band; tiers reflect total occurrences
                TierRequirement(tier: .gold, threshold: 10),    // Same band; tiers reflect total occurrences
                TierRequirement(tier: .diamond, threshold: 20)  // Same band; tiers reflect total occurrences
            ]
        )
    }
    
    // MARK: - Comeback Champion Achievement
    static func createComebackChampionAchievement() -> TieredAchievement {
        TieredAchievement(
            category: .comebackChampion,
            requirements: [
                TierRequirement(tier: .bronze, threshold: 1),   // Start new streak
                TierRequirement(tier: .silver, threshold: 7),   // 7-day comeback
                TierRequirement(tier: .gold, threshold: 14),    // 14-day comeback
                TierRequirement(tier: .diamond, threshold: 30)  // 30-day comeback
            ]
        )
    }
    
    // MARK: - Marathon Runner Achievement
    static func createMarathonRunnerAchievement() -> TieredAchievement {
        TieredAchievement(
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
