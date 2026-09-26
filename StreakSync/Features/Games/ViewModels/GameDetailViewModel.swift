//
//  GameDetailViewModel.swift
//  StreakSync
//
//  Game detail business logic with auto-refresh support
//

import OSLog
import SwiftUI

@MainActor
final class GameDetailViewModel: ObservableObject {
    let gameId: UUID
    @Published private(set) var currentStreak: GameStreak
    @Published private(set) var recentResults: [GameResult] = []
    
    private weak var appState: AppState?
    private let logger = Logger(subsystem: "com.streaksync.app", category: "GameDetailViewModel")
    
    // Block-based observers must be removed manually. nonisolated(unsafe) mirrors
    // AppState.dayChangeObserver so deinit (nonisolated) can tear them down;
    // NotificationCenter.removeObserver is thread-safe.
    nonisolated(unsafe) private var notificationObservers: [NSObjectProtocol] = []
    
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
        // Block-based observers are NOT removed automatically; a fresh VM is created
        // per game-detail navigation, so failing to remove them leaks one registration
        // each visit.
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
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
        
        logger.info("Loaded data for game: \(gameName)")
    }
    
    func refreshData() async {
        if let appState = appState {
            await appState.refreshData()
        }
        loadGameData()
    }
}
