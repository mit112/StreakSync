//
//  WidgetSnapshotTests.swift
//  StreakSyncTests
//
//  The App Group payload the widget renders, and its midnight roll-forward
//

@testable import StreakSync
import XCTest

@MainActor
final class WidgetSnapshotTests: XCTestCase {
    private func makeEntry(
        name: String, streak: Int, playedToday: Bool, atRisk: Bool
    ) -> WidgetGameEntry {
        WidgetGameEntry(
            gameId: UUID(), slug: name.lowercased(), displayName: name,
            iconSystemName: "star", colorHex: "#112233",
            currentStreak: streak, maxStreak: streak,
            hasPlayedToday: playedToday, isAtRisk: atRisk
        )
    }

    private func makeSnapshot(dayStart: Date, games: [WidgetGameEntry]) -> WidgetSnapshot {
        WidgetSnapshot(
            version: WidgetSnapshot.currentVersion,
            generatedAt: dayStart,
            dayStart: dayStart,
            totalActiveStreaks: games.filter { $0.currentStreak > 0 }.count,
            longestCurrentStreak: games.map(\.currentStreak).max() ?? 0,
            completedTodayCount: games.filter(\.hasPlayedToday).count,
            atRiskCount: games.filter(\.isAtRisk).count,
            games: games
        )
    }

    // MARK: - Roll forward

    /// The widget has to survive a day boundary the app never woke up for. A timeline
    /// entry scheduled for midnight is built from this, so if it didn't reset the
    /// widget would claim you'd already played today, all of the next day.
    func testRollingPastMidnightClearsPlayedTodayAndRearmsActiveStreaks() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: today))

        let snapshot = makeSnapshot(dayStart: today, games: [
            makeEntry(name: "Wordle", streak: 14, playedToday: true, atRisk: false),
            makeEntry(name: "Strands", streak: 0, playedToday: false, atRisk: false)
        ])

        let rolled = snapshot.rolledForward(to: tomorrow)

        XCTAssertEqual(rolled.dayStart, tomorrow)
        XCTAssertEqual(rolled.completedTodayCount, 0)
        XCTAssertFalse(rolled.games.allSatisfy(\.hasPlayedToday))
        XCTAssertTrue(try XCTUnwrap(rolled.games.first).isAtRisk, "an active streak is at risk again")
        XCTAssertFalse(
            try XCTUnwrap(rolled.games.last).isAtRisk,
            "a game with no streak has nothing to lose"
        )
        XCTAssertEqual(rolled.atRiskCount, 1)
        XCTAssertEqual(
            rolled.longestCurrentStreak, 14,
            "the streak itself is untouched — it is only at risk, not yet broken"
        )
    }

    /// Within the same day the snapshot must be returned verbatim, or every timeline
    /// refresh would wipe the checkmarks the user just earned.
    func testRollingWithinTheSameDayIsIdentity() {
        let today = Calendar.current.startOfDay(for: Date())
        let snapshot = makeSnapshot(dayStart: today, games: [
            makeEntry(name: "Wordle", streak: 3, playedToday: true, atRisk: false)
        ])
        XCTAssertEqual(snapshot.rolledForward(to: today.addingTimeInterval(3600)), snapshot)
    }

    func testEncodesAndDecodesThroughTheAppGroupPayload() throws {
        let snapshot = makeSnapshot(dayStart: Calendar.current.startOfDay(for: Date()), games: [
            makeEntry(name: "Connections", streak: 7, playedToday: false, atRisk: true)
        ])
        let data = try WidgetSnapshot.makeEncoder().encode(snapshot)
        XCTAssertEqual(try WidgetSnapshot.makeDecoder().decode(WidgetSnapshot.self, from: data), snapshot)
    }

    // MARK: - Building from AppState

    /// The small family shows exactly one game, so ordering is the whole feature: the
    /// game that needs attention has to come first, not merely the longest streak.
    func testBuildPutsAtRiskGamesAheadOfLongerUntouchedStreaks() throws {
        let app = AppState()
        let games = Array(app.games.prefix(2))
        XCTAssertEqual(games.count, 2, "needs two distinct games")
        let atRiskGame = games[0]
        let safeGame = games[1]

        app.setRecentResults([
            GameResult(
                id: UUID(), gameId: safeGame.id, gameName: safeGame.name,
                date: Date(), score: 3, maxAttempts: 6, completed: true,
                sharedText: "played today", parsedData: [:]
            )
        ])
        app.setStreaks([
            // Long streak, but not played today → at risk.
            GameStreak(
                gameId: atRiskGame.id, gameName: atRiskGame.name,
                currentStreak: 20, maxStreak: 20, totalGamesPlayed: 20,
                totalGamesCompleted: 20, lastPlayedDate: Date().addingTimeInterval(-86_400),
                streakStartDate: nil
            ),
            // Shorter streak, already played today → safe.
            GameStreak(
                gameId: safeGame.id, gameName: safeGame.name,
                currentStreak: 2, maxStreak: 2, totalGamesPlayed: 2,
                totalGamesCompleted: 2, lastPlayedDate: Date(), streakStartDate: nil
            )
        ])

        let snapshot = app.buildWidgetSnapshot()

        XCTAssertEqual(snapshot.games.count, 2, "games with no plays are left out entirely")
        let first = try XCTUnwrap(snapshot.games.first)
        XCTAssertEqual(first.gameId, atRiskGame.id, "at risk outranks the longer safe streak")
        XCTAssertTrue(first.isAtRisk)
        XCTAssertFalse(first.hasPlayedToday)

        let second = try XCTUnwrap(snapshot.games.last)
        XCTAssertTrue(second.hasPlayedToday)
        XCTAssertFalse(second.isAtRisk)

        XCTAssertEqual(snapshot.atRiskCount, 1)
        XCTAssertEqual(snapshot.completedTodayCount, 1)
        XCTAssertEqual(snapshot.longestCurrentStreak, 20)
        XCTAssertEqual(snapshot.version, WidgetSnapshot.currentVersion)
    }
}
