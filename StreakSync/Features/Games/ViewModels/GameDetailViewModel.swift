//
//  GameDetailViewModel.swift
//  Game detail business logic with auto-refresh support
//

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
        
        // Listen for data updates
        let dataObserver = NotificationCenter.default.addObserver(
            forName: .appGameDataUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.loadGameData()
            }
        }
        notificationObservers.append(dataObserver)
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
