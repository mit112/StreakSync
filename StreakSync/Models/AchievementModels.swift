//
//  AchievementModels.swift
//  StreakSync
//
//  Achievement-related data models
//

import Foundation
import SwiftUI

// MARK: - Achievement Model
struct Achievement: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let title: String
    let description: String
    let iconSystemName: String
    let requirement: AchievementRequirement
    let unlockedDate: Date?
    let gameSpecific: UUID? // nil for global achievements
    
    // MARK: - Designated Initializer
    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        iconSystemName: String,
        requirement: AchievementRequirement,
        unlockedDate: Date? = nil,
        gameSpecific: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.iconSystemName = iconSystemName
        self.requirement = requirement
        self.unlockedDate = unlockedDate
        self.gameSpecific = gameSpecific
    }
    
    // MARK: - Computed Properties
    var isUnlocked: Bool {
        unlockedDate != nil
    }
    
    var displayColor: Color {
        isUnlocked ? .yellow : Color(.systemGray2)
    }
    
    var localizedTitle: String {
        NSLocalizedString("achievement.\(title.lowercased().replacingOccurrences(of: " ", with: "_")).title",
                         comment: title)
    }
    
    var localizedDescription: String {
        NSLocalizedString("achievement.\(title.lowercased().replacingOccurrences(of: " ", with: "_")).description",
                         comment: description)
    }
    
    // MARK: - Factory Methods
    static func firstGame() -> Achievement {
        Achievement(
            title: "First Steps",
            description: "Complete your first game",
            iconSystemName: "star.fill",
            requirement: .firstGame
        )
    }
    
    static func weekWarrior() -> Achievement {
        Achievement(
            title: "Week Warrior",
            description: "Maintain a 7-day streak",
            iconSystemName: "flame.fill",
            requirement: .streakLength(7)
        )
    }
    
    static func dedication() -> Achievement {
        Achievement(
            title: "Dedication",
            description: "Play 50 games total",
            iconSystemName: "trophy.fill",
            requirement: .totalGames(50)
        )
    }
    
    static func multitasker() -> Achievement {
        Achievement(
            title: "Multi-tasker",
            description: "Play 3 different games in one day",
            iconSystemName: "gamecontroller.fill",
            requirement: .multipleGames(3)
        )
    }
}

// MARK: - Achievement Requirements
enum AchievementRequirement: Codable, Hashable, Sendable {
    case streakLength(Int)
    case totalGames(Int)
    case perfectWeek
    case perfectMonth
    case firstGame
    case multipleGames(Int) // Play X different games in one day
    case consecutiveDays(Int) // Play for X consecutive days
    case specificScore(Int) // Get a specific score
    
    var displayText: String {
        switch self {
        case .streakLength(let days):
            return String(format: NSLocalizedString("achievement.streak_length", comment: ""), days)
        case .totalGames(let count):
            return String(format: NSLocalizedString("achievement.total_games", comment: ""), count)
        case .perfectWeek:
            return NSLocalizedString("achievement.perfect_week", comment: "")
        case .perfectMonth:
            return NSLocalizedString("achievement.perfect_month", comment: "")
        case .firstGame:
            return NSLocalizedString("achievement.first_game", comment: "")
        case .multipleGames(let count):
            return String(format: NSLocalizedString("achievement.multiple_games", comment: ""), count)
        case .consecutiveDays(let days):
            return String(format: NSLocalizedString("achievement.consecutive_days", comment: ""), days)
        case .specificScore(let score):
            return String(format: NSLocalizedString("achievement.specific_score", comment: ""), score)
        }
    }
    
    var difficulty: AchievementDifficulty {
        switch self {
        case .firstGame:
            return .easy
        case .streakLength(let days):
            if days <= 3 { return .easy }
            if days <= 7 { return .medium }
            if days <= 30 { return .hard }
            return .legendary
        case .totalGames(let count):
            if count <= 10 { return .easy }
            if count <= 50 { return .medium }
            if count <= 100 { return .hard }
            return .legendary
        case .multipleGames(let count):
            return count <= 3 ? .medium : .hard
        case .perfectWeek, .consecutiveDays:
            return .hard
        case .perfectMonth:
            return .legendary
        case .specificScore:
            return .medium
        }
    }
}

// MARK: - Achievement Difficulty
enum AchievementDifficulty: String, CaseIterable, Sendable {
    case easy = "easy"
    case medium = "medium"
    case hard = "hard"
    case legendary = "legendary"
    
    var color: Color {
        switch self {
        case .easy: return .green
        case .medium: return .yellow
        case .hard: return .orange
        case .legendary: return .purple
        }
    }
    
    var iconSystemName: String {
        switch self {
        case .easy: return "star"
        case .medium: return "star.fill"
        case .hard: return "crown"
        case .legendary: return "crown.fill"
        }
    }
}
