//
//  WidgetSnapshot.swift
//  StreakSync
//
//  Compact per-game state the app publishes to the App Group for the widget
//

import Foundation

/// One game's row in the widget snapshot.
struct WidgetGameEntry: Codable, Hashable, Sendable, Identifiable {
    let gameId: UUID
    /// `Game.name` — the lowercase slug, e.g. "minicrossword".
    let slug: String
    let displayName: String
    let iconSystemName: String
    /// Pre-flattened "#RRGGBB". CodableColor is deliberately not shared.
    let colorHex: String
    let currentStreak: Int
    let maxStreak: Int
    let hasPlayedToday: Bool
    let isAtRisk: Bool

    var id: UUID { gameId }
}

/// The compact state the widget renders, published by the app to the App Group.
///
/// A widget process cannot read the app's private container, and the App Group holds
/// only a transient share-inbox queue that is drained on ingest — so none of the real
/// state (streaks, results, favourites) is reachable without publishing it here.
struct WidgetSnapshot: Codable, Hashable, Sendable {
    static let currentVersion = 1

    let version: Int
    let generatedAt: Date
    /// Start of the local day this snapshot describes.
    let dayStart: Date
    let totalActiveStreaks: Int
    let longestCurrentStreak: Int
    let completedTodayCount: Int
    let atRiskCount: Int
    /// At-risk first, then by descending current streak. Capped at 12.
    let games: [WidgetGameEntry]
}

extension WidgetSnapshot {
    static let appGroupIdentifier = "group.com.mitsheth.StreakSync"
    static let appGroupKey = "widgetSnapshot"

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Reads the published snapshot. Returns nil when the app has never written one
    /// (every existing install, until it launches once on the new build), when the
    /// App Group is unavailable, or when the payload is a version this binary
    /// cannot read.
    static func loadFromAppGroup() -> WidgetSnapshot? {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: appGroupKey),
              let snapshot = try? makeDecoder().decode(WidgetSnapshot.self, from: data),
              snapshot.version == currentVersion else {
            return nil
        }
        return snapshot
    }

    /// A copy rolled forward to `date`: once the calendar passes `dayStart`,
    /// nothing has been played today and every active streak is at risk again.
    /// Lets one timeline stay correct past midnight without the app relaunching.
    func rolledForward(to date: Date, calendar: Calendar = .current) -> WidgetSnapshot {
        guard !calendar.isDate(date, inSameDayAs: dayStart) else { return self }
        let rolled = games.map { entry in
            WidgetGameEntry(
                gameId: entry.gameId, slug: entry.slug, displayName: entry.displayName,
                iconSystemName: entry.iconSystemName, colorHex: entry.colorHex,
                currentStreak: entry.currentStreak, maxStreak: entry.maxStreak,
                hasPlayedToday: false, isAtRisk: entry.currentStreak > 0
            )
        }
        return WidgetSnapshot(
            version: version, generatedAt: generatedAt,
            dayStart: calendar.startOfDay(for: date),
            totalActiveStreaks: totalActiveStreaks,
            longestCurrentStreak: longestCurrentStreak,
            completedTodayCount: 0,
            atRiskCount: rolled.filter(\.isAtRisk).count,
            games: rolled
        )
    }
}
