//
//  StreakQueryIntents.swift
//  StreakSyncWidget
//
//  Shortcuts and Siri intents over the published snapshot
//

import AppIntents
import Foundation

/// Opens a game's detail screen through the app's registered `streaksync://`
/// scheme. Deliberately a deep link rather than a direct navigation call: the
/// widget process cannot touch `NavigationCoordinator`, and the scheme route is
/// already wired end to end.
struct OpenGameStreakIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Game in StreakSync"
    static let description = IntentDescription("Jump straight to one game's streak.")
    static let openAppWhenRun = true

    @Parameter(title: "Game")
    var game: GameAppEntity

    init() {}

    init(game: GameAppEntity) {
        self.game = game
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$game) in StreakSync")
    }

    func perform() async throws -> some IntentResult & OpensIntent {
        WidgetLog.intents.info("Opening deep link for \(game.displayName, privacy: .public)")
        return .result(opensIntent: OpenURLIntent(WidgetDeepLink.game(id: game.id)))
    }
}

/// "What's my Wordle streak?" — answers from the App Group snapshot without
/// launching the app. Read-only on purpose: there is no companion "mark as
/// played" intent, because a synthesized `GameResult` fails `GameResult.isValid`
/// and would publish a fabricated score to friends' leaderboards.
struct GetGameStreakIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Game Streak"
    static let description = IntentDescription("Returns your current streak for a game.")
    static let openAppWhenRun = false

    @Parameter(title: "Game")
    var game: GameAppEntity

    init() {}

    init(game: GameAppEntity) {
        self.game = game
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Get my \(\.$game) streak")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        guard let snapshot = WidgetSnapshot.loadFromAppGroup()?.rolledForward(to: Date()) else {
            WidgetLog.intents.notice("Streak query with no published snapshot")
            return .result(
                value: 0,
                dialog: "Open StreakSync once so it can share your streaks."
            )
        }
        guard let state = snapshot.game(withID: game.id) else {
            return .result(
                value: 0,
                dialog: "You don't have a \(game.displayName) streak yet."
            )
        }
        let days = state.currentStreak
        let unit = days == 1 ? "day" : "days"
        return .result(
            value: days,
            dialog: "You're on a \(days) \(unit) \(game.displayName) streak."
        )
    }
}
