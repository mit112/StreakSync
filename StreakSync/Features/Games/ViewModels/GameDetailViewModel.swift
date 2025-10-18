//
//  GameDetailViewModel.swift
//  Game detail business logic with auto-refresh support
//

/*
 * GAMEDETAILVIEWMODEL - GAME DETAIL BUSINESS LOGIC AND DATA MANAGEMENT
 * 
 * WHAT THIS FILE DOES:
 * This file provides the business logic and data management for individual game detail views.
 * It's like a "game detail controller" that manages the data, state, and interactions
 * for showing detailed information about a specific game. Think of it as the "game detail
 * brain" that processes game data, manages real-time updates, and provides computed
 * properties for the game detail UI to display.
 * 
 * WHY IT EXISTS:
 * Game detail views need to handle complex logic like loading game data, managing
 * real-time updates, computing statistics, and coordinating with the app state.
 * Instead of putting all this logic directly in the view, this ViewModel separates
 * the business logic from the UI, making the code more organized, testable, and maintainable.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This provides the core logic for individual game detail experiences
 * - Manages game-specific data loading and updates
 * - Handles real-time updates when new results are added
 * - Computes game statistics and achievement progress
 * - Coordinates with AppState for data access
 * - Provides reactive updates to the game detail UI
 * - Manages game-specific state and interactions
 * 
 * WHAT IT REFERENCES:
 * - AppState: For accessing game data and streaks
 * - SwiftUI: For @Published properties and reactive updates
 * - OSLog: For logging and debugging
 * - NotificationCenter: For real-time updates
 * - Game: For game data and information
 * - GameStreak: For streak data and calculations
 * - GameResult: For game result data
 * - TieredAchievement: For achievement data
 * 
 * WHAT REFERENCES IT:
 * - Game detail views: Use this for business logic and data management
 * - Navigation system: Creates this ViewModel for game detail navigation
 * - AppContainer: Provides AppState dependency
 * - Various game detail components: Use this for data and interactions
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. STATE MANAGEMENT IMPROVEMENTS:
 *    - The current state management is good but could be more sophisticated
 *    - Consider adding more game detail-specific state properties
 *    - Add support for game detail customization and preferences
 *    - Implement smart game detail recommendations
 * 
 * 2. REAL-TIME UPDATES IMPROVEMENTS:
 *    - The current real-time updates are good but could be more efficient
 *    - Consider adding more sophisticated update mechanisms
 *    - Add support for selective updates based on relevance
 *    - Implement smart update batching and optimization
 * 
 * 3. PERFORMANCE OPTIMIZATIONS:
 *    - The current implementation could be optimized
 *    - Consider implementing efficient data loading and caching
 *    - Add support for data preloading and background updates
 *    - Implement smart data management
 * 
 * 4. USER EXPERIENCE IMPROVEMENTS:
 *    - The current game detail could be more user-friendly
 *    - Add support for game detail customization and preferences
 *    - Implement smart game detail recommendations
 *    - Add support for game detail tutorials and guidance
 * 
 * 5. TESTING IMPROVEMENTS:
 *    - Add comprehensive unit tests for game detail logic
 *    - Test different game detail scenarios and edge cases
 *    - Add UI tests for game detail interactions
 *    - Test real-time update functionality
 * 
 * 6. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for game detail features
 *    - Document the different game detail options and usage patterns
 *    - Add examples of how to use different game detail features
 *    - Create game detail usage guidelines
 * 
 * 7. EXTENSIBILITY IMPROVEMENTS:
 *    - Make it easier to add new game detail features
 *    - Add support for custom game detail configurations
 *    - Implement game detail plugins
 *    - Add support for third-party game detail integrations
 * 
 * 8. MONITORING AND OBSERVABILITY:
 *    - Add detailed logging for game detail interactions
 *    - Implement metrics for game detail usage and effectiveness
 *    - Add support for game detail debugging
 *    - Monitor game detail performance and reliability
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - ViewModels: Separate business logic from UI components
 * - MVVM pattern: Model-View-ViewModel architecture for clean separation
 * - Reactive programming: Using @Published properties for automatic UI updates
 * - Real-time updates: Keeping data synchronized across the app
 * - User experience: Making sure game details are informative and engaging
 * - Performance: Making sure data loading and updates are efficient
 * - Testing: Ensuring game detail logic works correctly
 * - Code organization: Keeping related functionality together
 * - Dependency injection: Providing dependencies through initialization
 * - State management: Managing data and user interactions
 */

import SwiftUI
import OSLog

@MainActor
final class GameDetailViewModel: ObservableObject {
    let gameId: UUID
    @Published private(set) var currentStreak: GameStreak
    @Published private(set) var recentResults: [GameResult] = []
    @Published private(set) var gameAchievements: [TieredAchievement] = []
    @Published var showingShareError = false
    
    private weak var appState: AppState?
    private let logger = Logger(subsystem: "com.streaksync.app", category: "GameDetailViewModel")
    
    // Add notification observers
    private var notificationObservers: [NSObjectProtocol] = []
    
    init(gameId: UUID) {
        self.gameId = gameId
        // Initialize with empty streak - will be updated in setup
        self.currentStreak = GameStreak(
            gameId: gameId,
            gameName: "Loading",
            currentStreak: 0,
            maxStreak: 0,
            totalGamesPlayed: 0,
            totalGamesCompleted: 0,
            lastPlayedDate: nil,
            streakStartDate: nil
        )
    }
    
    deinit {
        // Note: notificationObservers cleanup happens automatically
        // Cannot access mutable state in deinit under strict concurrency
    }
    
    func setup(with appState: AppState) {
        self.appState = appState
        loadGameData()
        
        // Listen for game result additions
        let resultObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("GameResultAdded"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.loadGameData()
            }
        }

        notificationObservers.append(resultObserver)
        
        // Listen for data updates
        let dataObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("GameDataUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.loadGameData()
            }
        }
        notificationObservers.append(dataObserver)
        
        // Also listen for app becoming active
        let activeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                // Skip expensive reload if navigating from notification
                if appState.isNavigatingFromNotification {
                    return
                }
                
                // Delay slightly to ensure data is loaded
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    Task { @MainActor in
                        self.loadGameData()
                    }
                }
            }
        }
        notificationObservers.append(activeObserver)
        
        // CRITICAL: Also observe RefreshGameData
        let refreshObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("RefreshGameData"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let refreshGame = notification.object as? Game,
               refreshGame.id == self.gameId {
                self.logger.info("🔄 Force refreshing game detail view")
                Task { @MainActor in
                    self.loadGameData()
                }
            }
        }
        notificationObservers.append(refreshObserver)
    }
    
    private func loadGameData() {
        guard let appState = appState else { return }
        
        // Get the actual game name for logging
        let gameName = appState.games.first(where: { $0.id == gameId })?.displayName ?? "Unknown"
        
        // Load streak
        if let streak = appState.streaks.first(where: { $0.gameId == gameId }) {
            currentStreak = streak
        } else {
            // Create a default streak for games that don't have one yet
            currentStreak = GameStreak(
                gameId: gameId,
                gameName: gameName,
                currentStreak: 0,
                maxStreak: 0,
                totalGamesPlayed: 0,
                totalGamesCompleted: 0,
                lastPlayedDate: nil,
                streakStartDate: nil
            )
        }
        
        // Load recent results for this game
        recentResults = appState.recentResults
            .filter { $0.gameId == gameId }
            .sorted { $0.date > $1.date }
        
        // Load game-specific tiered achievements if any are scoped by specificGameId
        gameAchievements = appState.tieredAchievements
            .filter { ta in
                ta.requirements.contains(where: { $0.specificGameId == nil || $0.specificGameId == gameId })
            }
        
        logger.info("🎮 Loaded data for game: \(gameName)")
    }
    
    func refreshData() async {
        if let appState = appState {
            await appState.refreshData()
        }
        loadGameData()
    }
    
    func shareGameStats() {
        let stats = """
        📊 My \(currentStreak.gameName) Stats
        
        Current Streak: \(currentStreak.currentStreak) days 🔥
        Best Streak: \(currentStreak.maxStreak) days 🏆
        Success Rate: \(currentStreak.completionPercentage)
        Total Games: \(currentStreak.totalGamesPlayed)
        
        Tracked with StreakSync!
        """
        
        // Share implementation
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let rootViewController = windowScene.windows.first?.rootViewController else {
            showingShareError = true
            return
        }
        
        let activityController = UIActivityViewController(
            activityItems: [stats],
            applicationActivities: nil
        )
        
        if let popover = activityController.popoverPresentationController {
            popover.sourceView = rootViewController.view
            popover.sourceRect = CGRect(
                x: rootViewController.view.bounds.midX,
                y: rootViewController.view.bounds.midY,
                width: 0,
                height: 0
            )
        }
        
        rootViewController.present(activityController, animated: true)
    }
}
