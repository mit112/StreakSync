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
    
    /// Metal→gem ladder (DESIGN_AUDIT §3-B): on-brand, WCAG-safe, with desaturated
    /// dark variants so the top tiers stop neon-glowing on near-black.
    var color: Color {
        switch self {
        case .bronze: return Color(lightHex: "B0783C", darkHex: "C79A66")
        case .silver: return Color(lightHex: "8E99A3", darkHex: "AEB6BE")
        case .gold: return Color(lightHex: "C9A227", darkHex: "D8B84E")
        case .diamond: return Color(lightHex: "3EAEC9", darkHex: "6FC6DB")
        case .master: return Color(lightHex: "3B5BDB", darkHex: "6E86E8")
        case .legendary: return Color(lightHex: "0CA678", darkHex: "2FBF93")
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
        case .master: return 0.4
        case .legendary: return 0.4
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
    case personalBest = "personal_best"
    case socialPlayer = "social_player"
    case completionist = "completionist"
    
    /// Categories that reward anti-patterns (clock-watching, streak failure).
    /// Kept in enum for Codable backward compatibility; hidden from UI and checker.
    var isRetired: Bool {
        switch self {
        case .earlyBird, .nightOwl, .comebackChampion: return true
        default: return false
        }
    }

    /// All non-retired categories, in declaration order.
    static let activeCategories: [AchievementCategory] = allCases.filter { !$0.isRetired }

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
        case .personalBest: return "Personal Best"
        case .socialPlayer: return "Social Player"
        case .completionist: return "Completionist"
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
        case .personalBest: return "chart.line.uptrend.xyaxis"
        case .socialPlayer: return "person.2.fill"
        case .completionist: return "checkmark.seal.fill"
        }
    }

    var description: String {
        switch self {
        case .streakMaster: return "Maintain consecutive day streaks for individual games"
        case .gameCollector: return "Log more and more game results — every play counts"
        case .perfectionist: return "Complete games successfully without failing"
        case .dailyDevotee: return "Play at least one game every day"
        case .varietyPlayer: return "Try different games — each new title counts"
        case .speedDemon: return "Win games with minimal attempts"
        case .earlyBird: return "Play games in the early morning"
        case .nightOwl: return "Play games late at night"
        case .comebackChampion: return "Rebuild streaks after they break"
        case .marathonRunner: return "Stay active for extended periods"
        case .personalBest: return "Beat your own high scores across games"
        case .socialPlayer: return "Build your friends network"
        case .completionist: return "Earn Gold or higher in multiple categories"
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
        case .personalBest:
            uuidString = "E1F2A3B4-C5D6-4789-EABC-DEF012345678"
        case .socialPlayer:
            uuidString = "F2A3B4C5-D6E7-4890-FBCD-EF0123456789"
        case .completionist:
            uuidString = "A3B4C5D6-E7F8-4901-ACDE-F01234567890"
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

    /// Returns the next tier that actually has a requirement defined.
    /// Fixes the bug where skipping `.master` in requirements caused Diamond
    /// to appear as the max tier (nextTier returned `.master` but no
    /// requirement existed for it).
    func nextTier(in requirements: [TierRequirement]) -> AchievementTier? {
        guard let current = currentTier else {
            return requirements.first?.tier
        }
        return requirements.first { $0.tier.rawValue > current.rawValue }?.tier
    }

    func percentageToNextTier(requirements: [TierRequirement]) -> Double {
        guard let nextTier = nextTier(in: requirements) else { return 1.0 }
        guard let nextRequirement = requirements.first(where: { $0.tier == nextTier }) else { return 0.0 }
        guard nextRequirement.threshold > 0 else { return 0.0 }
        return min(1.0, max(0.0, Double(currentValue) / Double(nextRequirement.threshold)))
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
        guard let nextTier = progress.nextTier(in: requirements) else { return nil }
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

        // Capture the tier held BEFORE this update once. Re-reading currentTier inside the
        // loop (after mutating it) meant crossing several tiers in a single update only
        // stamped the highest tier's unlock date; the lower newly-crossed tiers were skipped.
        let previousTier = progress.currentTier
        let previousRaw = previousTier?.rawValue ?? 0
        for requirement in requirements.reversed() {
            if value >= requirement.threshold && (previousTier == nil || requirement.tier.rawValue > previousRaw) {
                // Raise to the highest newly-crossed tier (reversed → highest first).
                if requirement.tier.rawValue > (progress.currentTier?.rawValue ?? 0) {
                    progress.currentTier = requirement.tier
                }
                // Stamp each newly-crossed tier's unlock date (once).
                if progress.tierUnlockDates[requirement.tier] == nil {
                    progress.tierUnlockDates[requirement.tier] = Date()
                }
            }
        }
    }
}
