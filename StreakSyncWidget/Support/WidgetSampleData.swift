//
//  WidgetSampleData.swift
//  StreakSyncWidget
//
//  Placeholder content for the widget gallery and redacted placeholder pass
//

import Foundation

/// Content shown in the widget gallery and during WidgetKit's placeholder pass.
/// Built from the real catalog so icons and colors match what the user will get.
/// Never rendered over live data.
enum WidgetSampleData {
    private static let streaks = [14, 9, 6, 4, 2, 1]

    static let games: [WidgetGameEntry] = Game.allAvailableGames
        .prefix(streaks.count)
        .enumerated()
        .map { index, game in
            WidgetGameEntry(
                gameId: game.id,
                slug: game.name,
                displayName: game.displayName,
                iconSystemName: game.iconSystemName,
                colorHex: WidgetColorHex.hexString(from: game.backgroundColor),
                currentStreak: streaks[index],
                maxStreak: streaks[index] + 3,
                hasPlayedToday: index > 0 && index < 3,
                isAtRisk: index == 0
            )
        }

    static let snapshot: WidgetSnapshot = {
        let dayStart = Calendar.current.startOfDay(for: Date())
        return WidgetSnapshot(
            version: WidgetSnapshot.currentVersion,
            generatedAt: dayStart,
            dayStart: dayStart,
            totalActiveStreaks: games.count,
            longestCurrentStreak: streaks.first ?? 0,
            completedTodayCount: 2,
            atRiskCount: 1,
            games: games
        )
    }()

    static var firstGame: WidgetGameEntry? {
        games.first
    }
}
