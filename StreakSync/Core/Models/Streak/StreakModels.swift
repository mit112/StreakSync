//
//  StreakModels.swift
//  StreakSync
//
//  Streak-related data models
//

import Foundation
import SwiftUI

// MARK: - Streak Status Enum
enum StreakStatus: String, CaseIterable, Sendable {
    case active = "active"
    case inactive = "inactive"
    case broken = "broken"
    
    var color: Color {
        switch self {
        case .active: return .green
        case .inactive: return .orange
        case .broken: return .red
        }
    }
    
    var iconSystemName: String {
        switch self {
        case .active: return "flame.fill"
        case .inactive: return "flame"
        case .broken: return "xmark.circle"
        }
    }
    
    var localizedTitle: String {
        switch self {
        case .active: return NSLocalizedString("streak.active", comment: "Active")
        case .inactive: return NSLocalizedString("streak.inactive", comment: "Inactive")
        case .broken: return NSLocalizedString("streak.broken", comment: "Broken")
        }
    }
}

// MARK: - Game Streak Model
struct GameStreak: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let gameId: UUID
    let gameName: String
    let currentStreak: Int
    let maxStreak: Int
    let totalGamesPlayed: Int
    let totalGamesCompleted: Int
    let lastPlayedDate: Date?
    let streakStartDate: Date?
    
    // MARK: - Designated Initializer with Validation
    init(
        id: UUID = UUID(),
        gameId: UUID,
        gameName: String,
        currentStreak: Int,
        maxStreak: Int,
        totalGamesPlayed: Int,
        totalGamesCompleted: Int,
        lastPlayedDate: Date?,
        streakStartDate: Date?
    ) {
        // Input validation
        precondition(currentStreak >= 0, "Current streak cannot be negative")
        precondition(maxStreak >= 0, "Max streak cannot be negative")
        precondition(totalGamesPlayed >= 0, "Total games played cannot be negative")
        precondition(totalGamesCompleted >= 0, "Total games completed cannot be negative")
        precondition(totalGamesCompleted <= totalGamesPlayed, "Completed games cannot exceed total games")
        precondition(!gameName.isEmpty, "Game name cannot be empty")
        
        self.id = id
        self.gameId = gameId
        self.gameName = gameName
        self.currentStreak = currentStreak
        self.maxStreak = max(maxStreak, currentStreak) // Ensure max is always >= current
        self.totalGamesPlayed = totalGamesPlayed
        self.totalGamesCompleted = totalGamesCompleted
        self.lastPlayedDate = lastPlayedDate
        self.streakStartDate = streakStartDate
    }
    
    
    
    // MARK: - Computed Properties
    var completionRate: Double {
        guard totalGamesPlayed > 0 else { return 0.0 }
        return Double(totalGamesCompleted) / Double(totalGamesPlayed)
    }
    
    var completionPercentage: String {
        String(format: "%.1f%%", completionRate * 100)
    }
    
    var isActive: Bool {
        guard let lastPlayed = lastPlayedDate else { return false }
        return GameDateHelper.isGameResultActive(lastPlayed)
    }
    var successRate: Double {
        guard totalGamesPlayed > 0 else { return 0.0 }
        return Double(totalGamesCompleted) / Double(totalGamesPlayed)
    }
    
    var streakStatus: StreakStatus {
        if currentStreak == 0 { return .broken }
        if isActive { return .active }
        return .inactive
    }
    
    var displayText: String {
        if currentStreak == 0 {
            return NSLocalizedString("streak.no_streak", comment: "No streak")
        } else if currentStreak == 1 {
            return NSLocalizedString("streak.days_singular", comment: "1 day")
        } else {
            return String(format: NSLocalizedString("streak.days_plural", comment: "%d days"), currentStreak)
        }
    }
    
    var lastPlayedText: String {
        guard let lastPlayed = lastPlayedDate else {
            return NSLocalizedString("game.never_played", comment: "Never played")
        }
        return GameDateHelper.getGamePlayedDescription(lastPlayed)
    }
    
    // MARK: - Factory Method
    static func empty(for game: Game) -> GameStreak {
        GameStreak(
            gameId: game.id,
            gameName: game.name,
            currentStreak: 0,
            maxStreak: 0,
            totalGamesPlayed: 0,
            totalGamesCompleted: 0,
            lastPlayedDate: nil,
            streakStartDate: nil
        )
    }
}
