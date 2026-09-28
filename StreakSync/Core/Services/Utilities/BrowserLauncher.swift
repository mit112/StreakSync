//
//  BrowserLauncher.swift
//  StreakSync
//
//  Opens a game's web page
//

import UIKit

@MainActor
enum BrowserLauncher {
    /// Opens the game's web URL.
    ///
    /// Native-app deep links (`nytimes://`, `quordle://`) used to be tried first, but
    /// `canOpenURL` only answers for schemes declared under `LSApplicationQueriesSchemes`,
    /// which Info.plist has never listed — so every launch already fell through to this.
    static func launchGame(_ game: Game) {
        UIApplication.shared.open(game.url)
    }
}
