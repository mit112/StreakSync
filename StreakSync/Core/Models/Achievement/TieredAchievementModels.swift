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
        let hex = String(format: "%012x", rawValue)
        let uuidString = "00000000-0000-0000-0000-\(hex)"
        guard let uuid = UUID(uuidString: uuidString) else {
            return UUID()
        }
        return uuid
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
    
    /// Generates a consistent UUID for this achievement category.
    /// This ensures the same category always gets the same ID, preventing duplicates.
    var consistentID: UUID {
        // Use fixed, deterministic UUIDs for each category to prevent duplicates
        // These UUIDs are hardcoded to ensure consistency across app launches
        let uuidString: String
        switch self {
        case .streakMaster:
            uuidString = "A1B2C3D4-E5F6-4789-A012-3456789ABCDE"
        case .gameCollector:
            uuidString = "B2C3D4E5-F6A7-4890-B123-456789ABCDEF"
        case .perfectionist:
            uuidString = "C3D4E5F6-A7B8-4901-C234-56789ABCDEF0"
        case .dailyDevotee:
            uuidString = "D4E5F6A7-B8C9-4012-D345-6789ABCDEF01"
        case .varietyPlayer:
            uuidString = "E5F6A7B8-C9D0-4123-E456-789ABCDEF012"
        case .speedDemon:
            uuidString = "F6A7B8C9-D0E1-4234-F567-89ABCDEF0123"
        case .earlyBird:
            uuidString = "A7B8C9D0-E1F2-4345-A678-9ABCDEF01234"
        case .nightOwl:
            uuidString = "B8C9D0E1-F2A3-4456-B789-ABCDEF012345"
        case .comebackChampion:
            uuidString = "C9D0E1F2-A3B4-4567-C89A-BCDEF0123456"
        case .marathonRunner:
            uuidString = "D0E1F2A3-B4C5-4678-D9AB-CDEF01234567"
        }
        return UUID(uuidString: uuidString) ?? UUID()
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
            let currentRaw = progress.currentTier?.rawValue ?? 0
            if value >= requirement.threshold && (progress.currentTier == nil || requirement.tier.rawValue > currentRaw) {
                // Unlock new tier
                progress.currentTier = requirement.tier
                if progress.tierUnlockDates[requirement.tier] == nil {
                    progress.tierUnlockDates[requirement.tier] = Date()
                }
            }
        }
    }
    
}
