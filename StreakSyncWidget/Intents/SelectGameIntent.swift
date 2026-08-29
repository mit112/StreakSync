//
//  SelectGameIntent.swift
//  StreakSyncWidget
//
//  Widget configuration: which game the single-game widget pins
//

import AppIntents
import WidgetKit

/// Backs the single-game widget's edit sheet. Hidden from the Shortcuts library
/// because on its own it does nothing — it only carries a choice.
struct SelectGameIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Select Game"
    static let description = IntentDescription("Choose which game's streak this widget pins.")
    static let isDiscoverable = false

    /// Optional so a freshly added widget renders something useful before the
    /// user has edited it — the provider falls back to the most urgent game.
    @Parameter(title: "Game")
    var game: GameAppEntity?

    init() {}

    init(game: GameAppEntity?) {
        self.game = game
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Show my \(\.$game) streak")
    }
}
