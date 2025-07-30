//
//  DashboardViewModel.swift
//  StreakSync
//
//  Created by MiT on 7/29/25.
//

//
//  DashboardViewModel.swift
//  StreakSync
//
//  Business logic for the dashboard view
//

import SwiftUI
import OSLog

@MainActor
final class DashboardViewModel: ObservableObject {
    // MARK: - Dependencies
    private let appState: AppState
    private let themeManager: ThemeManager
    private let logger = Logger(subsystem: "com.streaksync.app", category: "DashboardViewModel")
    
    // MARK: - Published Properties
    @Published var searchText = ""
    @Published var showOnlyActive = false
    @Published var isRefreshing = false
    @AppStorage("userName") var userName: String = ""
    
    // MARK: - Initialization
    init(appState: AppState, themeManager: ThemeManager) {
        self.appState = appState
        self.themeManager = themeManager
    }
    
    // MARK: - Computed Properties
    
    var activeStreaksCount: Int {
        appState.streaks.filter { streak in
            guard let game = appState.games.first(where: { $0.id == streak.gameId }) else { return false }
            return game.isActiveToday
        }.count
    }
    
    var todaysCompletedCount: Int {
        appState.games.filter { $0.hasPlayedToday }.count
    }
    
    var totalGamesCount: Int {
        appState.games.count
    }
    
    var filteredGames: [Game] {
        let games = showOnlyActive ?
            appState.games.filter { $0.isActiveToday } :
            appState.games
        
        if searchText.isEmpty {
            return games.sorted { game1, game2 in
                // Sort by: today's completion, then active status, then name
                if game1.hasPlayedToday != game2.hasPlayedToday {
                    return game1.hasPlayedToday
                }
                if game1.isActiveToday != game2.isActiveToday {
                    return game1.isActiveToday
                }
                return game1.displayName < game2.displayName
            }
        } else {
            return games.filter { game in
                game.displayName.localizedCaseInsensitiveContains(searchText)
            }.sorted { $0.displayName < $1.displayName }
        }
    }
    
    var isLoadingGames: Bool {
        appState.games.isEmpty && !appState.isDataLoaded
    }
    
    var hasNoGames: Bool {
        appState.games.isEmpty && appState.isDataLoaded
    }
    
    // MARK: - Dynamic Content
    
    var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = userName.isEmpty ? "" : ", \(userName)"
        
        switch hour {
        case 5..<9:
            return "Rise and shine\(name)! ☀️"
        case 9..<12:
            return "Good morning\(name)! 🌤"
        case 12..<14:
            return "Lunch break\(name)? 🥗"
        case 14..<17:
            return "Afternoon hustle\(name)! 💪"
        case 17..<20:
            return "Evening vibes\(name)! 🌅"
        case 20..<23:
            return "Winding down\(name)? 🌙"
        default:
            return "Night owl mode\(name)! 🦉"
        }
    }
    
    var motivationalMessage: String {
        if activeStreaksCount == 0 {
            return "Ready to start your first streak? Let's go!"
        } else if todaysCompletedCount == activeStreaksCount && activeStreaksCount > 0 {
            return "Perfect day! All \(activeStreaksCount) streaks completed! 🎉"
        } else if todaysCompletedCount > 0 {
            return "Great progress! \(activeStreaksCount - todaysCompletedCount) more to go!"
        } else {
            let messages = [
                "Your streaks are waiting for you!",
                "Let's keep the momentum going!",
                "Every puzzle counts. You've got this!",
                "Small steps lead to big streaks!",
                "Consistency is your superpower!",
                "Time to add to your collection!",
                "Your future self will thank you!"
            ]
            return messages.randomElement() ?? "Keep those streaks alive!"
        }
    }
    
    var timeBasedGradientColors: [Color] {
        let colors = themeManager.currentTheme.colors
        let hexColors = themeManager.isDarkMode ? colors.gradientDark : colors.gradientLight
        return hexColors.map { Color(hex: $0) }
    }
    
    // MARK: - Actions
    
    func refreshData() async {
        logger.info("🔄 Refreshing dashboard data")
        isRefreshing = true
        
        await appState.refreshData()
        
        withAnimation {
            isRefreshing = false
        }
        
        logger.info("✅ Dashboard refresh complete")
    }
    
    func clearSearch() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            searchText = ""
        }
    }
    
    func toggleActiveFilter() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showOnlyActive.toggle()
        }
        HapticManager.shared.trigger(.toggleSwitch)
    }
    
    // MARK: - Game Actions
    
    func getStreak(for game: Game) -> GameStreak? {
        appState.getStreak(for: game)
    }
    
    func gameHasUpdate(game: Game) -> Bool {
        // Check if this game has been updated recently
        guard let lastResult = appState.recentResults
            .filter({ $0.gameId == game.id })
            .first else { return false }
        
        // Consider it "updated" if played within last hour
        let hourAgo = Date().addingTimeInterval(-3600)
        return lastResult.date > hourAgo
    }
}
