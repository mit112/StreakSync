//
//  WidgetSnapshot+Display.swift
//  StreakSyncWidget
//
//  Presentation helpers over the shared snapshot contract
//

import SwiftUI

extension WidgetGameEntry {
    /// Per-game tint decoded from the snapshot's pre-flattened hex. Falls back to
    /// the streak tint so a malformed hex never renders as an invisible chip.
    var tint: Color {
        WidgetColorHex.color(colorHex) ?? WidgetTint.streak
    }

    var statusSymbolName: String {
        if hasPlayedToday {
            return "checkmark.circle.fill"
        }
        return isAtRisk ? "exclamationmark.triangle.fill" : "circle.dashed"
    }

    var statusTint: Color {
        if hasPlayedToday {
            return WidgetTint.success
        }
        return isAtRisk ? WidgetTint.atRisk : .secondary
    }

    var statusText: String {
        if hasPlayedToday {
            return "Played today"
        }
        return isAtRisk ? "Streak at risk" : "Not played yet"
    }

    var streakText: String {
        "\(currentStreak)"
    }

    var streakSummary: String {
        currentStreak == 1 ? "1 day streak" : "\(currentStreak) day streak"
    }

    /// Full sentence for VoiceOver, so the streak number is never announced bare.
    var accessibilityDescription: String {
        "\(displayName), \(streakSummary). \(statusText)."
    }
}

extension WidgetSnapshot {
    /// The game the small family leads with: the first at-risk streak, else the
    /// longest running one. `games` already arrives in that order, but deriving it
    /// here keeps the view correct if that ordering contract ever loosens.
    var mostUrgentGame: WidgetGameEntry? {
        games.first(where: \.isAtRisk) ?? games.max { $0.currentStreak < $1.currentStreak }
    }

    func game(withID gameId: UUID) -> WidgetGameEntry? {
        games.first { $0.gameId == gameId }
    }

    func topGames(limit: Int) -> [WidgetGameEntry] {
        Array(games.prefix(limit))
    }

    var longestStreakSummary: String {
        longestCurrentStreak == 1 ? "1 day streak" : "\(longestCurrentStreak) day streak"
    }

    var atRiskSummary: String {
        switch atRiskCount {
        case 0: return "Nothing at risk"
        case 1: return "1 game at risk"
        default: return "\(atRiskCount) games at risk"
        }
    }

    var completedTodaySummary: String {
        completedTodayCount == 1 ? "1 played today" : "\(completedTodayCount) played today"
    }
}
