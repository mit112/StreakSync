//
//  BrowserLauncher.swift
//  StreakSync
//
//  Simplified smart launcher - native app first, browser fallback
//

import SwiftUI
import UIKit

// MARK: - Game Launch Options (Internal Use Only)
struct GameLaunchOption {
    let appURLScheme: String?
    let appStoreURL: URL?
    let webURL: URL
    
    static func options(for game: Game) -> GameLaunchOption {
        switch game.name.lowercased() {
        // NYT Games (Wordle, Connections, Spelling Bee, Mini all use same app)
        case "wordle", "connections", "spelling bee", "mini":
            return GameLaunchOption(
                appURLScheme: "nytimes://games/wordle", // Default to wordle path
                appStoreURL: URL(string: "https://apps.apple.com/app/nyt-games-word-games-sudoku/id307569751"),
                webURL: game.url
            )
            
        case "quordle":
            return GameLaunchOption(
                appURLScheme: "quordle://",
                appStoreURL: URL(string: "https://apps.apple.com/app/quordle/id1622764742"),
                webURL: game.url
            )
            
        default:
            // Generic web games - no app
            return GameLaunchOption(
                appURLScheme: nil,
                appStoreURL: nil,
                webURL: game.url
            )
        }
    }
}

@MainActor
final class BrowserLauncher: ObservableObject {
    static let shared = BrowserLauncher()
    
    @Published var showingBrowserSelection = false
    @Published var urlToOpen: URL?
    
    /// Open any URL smartly
    func openURL(_ url: URL) {
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            urlToOpen = url
            showingBrowserSelection = true
        }
    }

    /// Launch a game (tries native app, then web fallback)
    func launchGame(_ game: Game) {
        let options = GameLaunchOption.options(for: game)
        if let appScheme = options.appURLScheme,
           let appURL = URL(string: appScheme),
           UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL)
        } else {
            openURL(options.webURL)
        }
    }
}
