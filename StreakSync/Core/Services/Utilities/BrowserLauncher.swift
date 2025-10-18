//
//  BrowserLauncher.swift
//  StreakSync
//
//  Simplified smart launcher - native app first, browser fallback
//

/*
 * BROWSERLAUNCHER - SMART GAME LAUNCHING AND URL HANDLING
 * 
 * WHAT THIS FILE DOES:
 * This file is the "smart launcher" that helps users open games in the best possible way.
 * It's like a "smart assistant" that tries to open games in their native apps first (if
 * installed), and falls back to opening them in the browser if the app isn't available.
 * Think of it as the "game launcher" that makes sure users can always access their games,
 * whether they have the official app installed or not.
 * 
 * WHY IT EXISTS:
 * Different games have different ways of being accessed - some have native apps, some are
 * web-only, and some have both. This launcher handles all these cases intelligently,
 * providing the best user experience by trying the native app first (which is usually
 * faster and more integrated) and falling back to the web version when needed.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This enables users to easily access and play their games
 * - Provides smart fallback from native apps to web versions
 * - Handles different game types and launch strategies
 * - Manages URL schemes and deep linking
 * - Provides browser selection when needed
 * - Ensures users can always access their games
 * - Integrates with the app's navigation and user experience
 * 
 * WHAT IT REFERENCES:
 * - Game: The game being launched
 * - GameLaunchOption: Configuration for how to launch each game
 * - UIApplication: For opening URLs and checking app availability
 * - SwiftUI: For UI state management and browser selection
 * - UIKit: For system integration and URL handling
 * 
 * WHAT REFERENCES IT:
 * - GameDetailView: Uses this to launch games when users tap "Play Game"
 * - Dashboard: Can use this to launch games from game cards
 * - AppContainer: Creates and manages the BrowserLauncher
 * - Various game-related views: Use this to provide game access
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. LAUNCH STRATEGY IMPROVEMENTS:
 *    - The current launch logic is basic - could be more sophisticated
 *    - Consider adding user preferences for launch behavior
 *    - Add support for custom launch strategies per game
 *    - Implement smart caching of app availability
 * 
 * 2. USER EXPERIENCE IMPROVEMENTS:
 *    - The current fallback could be more seamless
 *    - Add support for in-app browser for better integration
 *    - Implement smart suggestions for app installation
 *    - Add support for custom browser preferences
 * 
 * 3. PERFORMANCE OPTIMIZATIONS:
 *    - The current app availability checking could be optimized
 *    - Consider caching app availability results
 *    - Add support for background app availability checking
 *    - Implement efficient URL scheme validation
 * 
 * 4. ERROR HANDLING:
 *    - The current error handling is basic - could be more robust
 *    - Add support for network error handling
 *    - Implement fallback strategies for failed launches
 *    - Add user-friendly error messages
 * 
 * 5. TESTING IMPROVEMENTS:
 *    - Add comprehensive unit tests for launch logic
 *    - Test different game types and launch scenarios
 *    - Add integration tests with real apps and URLs
 *    - Test error handling and edge cases
 * 
 * 6. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for each game's launch strategy
 *    - Document the URL schemes and deep linking
 *    - Add examples of how to add new games
 *    - Create launch flow diagrams
 * 
 * 7. EXTENSIBILITY IMPROVEMENTS:
 *    - Make it easier to add new games and launch strategies
 *    - Add support for custom launch options
 *    - Implement plugin system for game launchers
 *    - Add support for third-party game integrations
 * 
 * 8. ANALYTICS INTEGRATION:
 *    - Add analytics for launch success rates
 *    - Track user preferences for app vs web usage
 *    - Monitor launch performance and user experience
 *    - Add A/B testing support for launch strategies
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - URL schemes: Custom URLs that can open specific apps
 * - Deep linking: URLs that can navigate to specific parts of an app
 * - App availability: Checking if a specific app is installed on the device
 * - Fallback strategies: What to do when the preferred option isn't available
 * - UIApplication: The system component that manages app launching
 * - URL handling: Working with web addresses and custom URLs
 * - Smart defaults: Choosing the best option automatically
 * - User experience: Making sure the app is easy and pleasant to use
 * - System integration: Working with the iOS system and other apps
 * - Error handling: What to do when something goes wrong
 */

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
            
        // LinkedIn Games - use web URL (more reliable than deep links)
        case "linkedinqueens", "linkedintango", "linkedincrossclimb", "linkedinpinpoint", "linkedinzip", "linkedinminisudoku":
            return GameLaunchOption(
                appURLScheme: nil, // No deep link - use web URL
                appStoreURL: URL(string: "https://apps.apple.com/app/linkedin/id288429040"),
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
