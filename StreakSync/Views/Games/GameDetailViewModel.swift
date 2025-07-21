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
    @Published private(set) var gameAchievements: [Achievement] = []
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
        // Clean up observers
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
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
            self?.loadGameData()
        }
        notificationObservers.append(resultObserver)
        
        // Listen for data updates
        let dataObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("GameDataUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadGameData()
        }
        notificationObservers.append(dataObserver)
        
        // Also listen for app becoming active
        let activeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Delay slightly to ensure data is loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.loadGameData()
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
                self.loadGameData()
            }
        }
        notificationObservers.append(refreshObserver)
    }
    
    private func loadGameData() {
        guard let appState = appState else { return }
        
        // Load streak
        if let streak = appState.streaks.first(where: { $0.gameId == gameId }) {
            currentStreak = streak
        }
        
        // Load recent results for this game
        recentResults = appState.recentResults
            .filter { $0.gameId == gameId }
            .sorted { $0.date > $1.date }
        
        // Load game-specific achievements
        gameAchievements = appState.achievements
            .filter { achievement in
                achievement.gameSpecific == gameId || achievement.gameSpecific == nil
            }
        
        logger.debug("Loaded data for game: \(self.currentStreak.gameName)")
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
