//
//  AppState+Widget.swift
//  StreakSync
//
//  Publishes the widget's App Group snapshot and asks WidgetKit to reload
//

import Foundation
import UIKit
import WidgetKit

extension AppState {
    /// Publishes the compact state the widget renders into the App Group, then asks
    /// WidgetKit to reload.
    ///
    /// A widget process cannot read the app's private container, and the App Group
    /// otherwise holds only the Share Extension's inbox queue, which is drained on
    /// ingest — so this write is the only way a widget learns anything at all.
    ///
    /// Called from the three places the underlying state can change: a new result, a
    /// wholesale result-set change (sync merge, import, restore, delete), and the day
    /// rolling over. Reloading here rather than polling is what keeps the widget fresh
    /// within a second of a share without burning the system's refresh budget.
    func publishWidgetSnapshot() {
        // Guest results live only in memory and review-mode data is fabricated;
        // neither should escape into a surface that outlives the session.
        guard !isGuestMode, !reviewModeEnabled else { return }
        guard let defaults = UserDefaults(suiteName: WidgetSnapshot.appGroupIdentifier) else {
            logger.error("Widget snapshot skipped — App Group unavailable")
            return
        }
        let snapshot = buildWidgetSnapshot()
        do {
            let data = try WidgetSnapshot.makeEncoder().encode(snapshot)
            defaults.set(data, forKey: WidgetSnapshot.appGroupKey)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            logger.error("Widget snapshot encode failed: \(error.localizedDescription)")
        }
    }

    /// Builds the snapshot from current state.
    ///
    /// `isAtRisk` comes straight from `getGamesAtRisk()` and `hasPlayedToday` uses that
    /// function's own predicate, so the widget can never disagree with the reminder the
    /// scheduler sends. Note that predicate requires a *completed* result: a failed
    /// attempt does not clear a game's risk, in the widget or in the notification.
    func buildWidgetSnapshot() -> WidgetSnapshot {
        let calendar = Calendar.current
        let now = Date()
        let atRiskIds = Set(getGamesAtRisk().map(\.id))

        var entries: [WidgetGameEntry] = []
        for game in games {
            guard let streak = streaks.first(where: { $0.gameId == game.id }),
                  streak.totalGamesPlayed > 0 else {
                continue
            }
            let playedToday = recentResults.contains { result in
                result.gameId == game.id
                    && calendar.isDate(result.date, inSameDayAs: now)
                    && result.completed
            }
            entries.append(
                WidgetGameEntry(
                    gameId: game.id,
                    slug: game.name,
                    displayName: game.displayName,
                    iconSystemName: game.iconSystemName,
                    colorHex: Self.hexString(for: game.backgroundColor),
                    currentStreak: streak.currentStreak,
                    maxStreak: streak.maxStreak,
                    hasPlayedToday: playedToday,
                    isAtRisk: atRiskIds.contains(game.id)
                )
            )
        }

        // At-risk first so the small family always shows the game that needs attention,
        // then longest streak, then a stable name tiebreak.
        entries.sort { lhs, rhs in
            if lhs.isAtRisk != rhs.isAtRisk { return lhs.isAtRisk }
            if lhs.currentStreak != rhs.currentStreak { return lhs.currentStreak > rhs.currentStreak }
            return lhs.displayName < rhs.displayName
        }

        return WidgetSnapshot(
            version: WidgetSnapshot.currentVersion,
            generatedAt: now,
            dayStart: calendar.startOfDay(for: now),
            totalActiveStreaks: entries.filter { $0.currentStreak > 0 }.count,
            longestCurrentStreak: entries.map(\.currentStreak).max() ?? 0,
            completedTodayCount: entries.filter(\.hasPlayedToday).count,
            atRiskCount: atRiskIds.count,
            games: Array(entries.prefix(12))
        )
    }

    /// Flattens a `CodableColor` to "#RRGGBB". The widget target deliberately doesn't
    /// share `CodableColor` — a stored enum case that resolves at render time would
    /// drift the moment either side gained a case.
    private static func hexString(for color: CodableColor) -> String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard color.uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return "#8E8E93" // systemGray, matching CodableColor's own fallback posture
        }
        let clamp = { (value: CGFloat) in Int((max(0, min(1, value)) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", clamp(red), clamp(green), clamp(blue))
    }
}
