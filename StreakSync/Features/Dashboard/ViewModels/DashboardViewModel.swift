//
//  DashboardViewModel.swift
//  StreakSync
//
//  Business logic for the dashboard view
//  FIXED: Updated to use new StreakSyncColors system
//

import SwiftUI
import OSLog

@MainActor
final class DashboardViewModel: ObservableObject {
    // MARK: - Dependencies
    private let appState: AppState
    private let logger = Logger(subsystem: "com.streaksync.app", category: "DashboardViewModel")
    
    // MARK: - Published Properties
    @Published var searchText = ""
    @Published var showOnlyActive = false
    @Published var isRefreshing = false
    @AppStorage("userName") var userName: String = ""
    
    // MARK: - Initialization
    init(appState: AppState) {
        self.appState = appState
    }
    
    // MARK: - Computed Properties
    
    var longestCurrentStreak: Int {
        appState.streaks.map(\.currentStreak).max() ?? 0
    }
    
    var activeStreaksCount: Int {
        appState.streaks.filter { $0.isActive }.count
    }
    
    var totalGamesCount: Int {
        appState.games.count
    }
    
    var filteredGames: [Game] {
        let games = showOnlyActive ?
            appState.games.filter { game in
                // Use streak data to determine if game is active
                guard let streak = appState.getStreak(for: game) else { return false }
                guard let lastPlayed = streak.lastPlayedDate else { return false }
                let daysSinceLastPlayed = Calendar.current.dateComponents([.day], from: lastPlayed, to: Date()).day ?? 0
                return daysSinceLastPlayed < 7
            } :
            appState.games
        
        if searchText.isEmpty {
            return games.sorted { game1, game2 in
                // Sort by: today's completion, then active status, then name
                let game1PlayedToday = hasPlayedToday(game1)
                let game2PlayedToday = hasPlayedToday(game2)
                let game1Active = isActiveToday(game1)
                let game2Active = isActiveToday(game2)
                
                if game1PlayedToday != game2PlayedToday {
                    return game1PlayedToday
                }
                if game1Active != game2Active {
                    return game1Active
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
    
    // (Removed greeting text; no longer used in header)
    
    var motivationalMessage: String {
        if activeStreaksCount == 0 {
            return "Ready to start your first streak? Let's go!"
        } else if longestCurrentStreak > 0 {
            return "Amazing! Your longest streak is \(longestCurrentStreak) days! 🔥"
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
    
    // MARK: - Time-Based Gradient Colors
    /// Returns gradient colors based on time of day
    func timeBasedGradientColors(for colorScheme: ColorScheme) -> [Color] {
        let hour = Calendar.current.component(.hour, from: Date())
        
        // Morning (5-12): Tangerine to Apricot
        // Afternoon (12-17): Coral Pink to Vanilla
        // Evening (17-21): Apricot to Tea Green
        // Night (21-5): Deep gradients
        
        switch hour {
        case 5..<12:
            // Morning - warm sunrise colors
            return [
                colorScheme == .dark ? PaletteColor.secondary.darkVariant : PaletteColor.secondary.color,
                colorScheme == .dark ? PaletteColor.primary.darkVariant : PaletteColor.primary.color,
                colorScheme == .dark ? PaletteColor.textSecondary.darkVariant : PaletteColor.textSecondary.color
            ]
        case 12..<17:
            // Afternoon - vibrant day colors
            return [
                colorScheme == .dark ? PaletteColor.primary.darkVariant : PaletteColor.primary.color,
                colorScheme == .dark ? PaletteColor.secondary.darkVariant : PaletteColor.secondary.color,
                colorScheme == .dark ? PaletteColor.background.darkVariant : PaletteColor.background.color
            ]
        case 17..<21:
            // Evening - sunset colors
            return [
                colorScheme == .dark ? PaletteColor.textSecondary.darkVariant : PaletteColor.textSecondary.color,
                colorScheme == .dark ? PaletteColor.background.darkVariant : PaletteColor.background.color,
                colorScheme == .dark ? PaletteColor.primary.darkVariant : PaletteColor.primary.color
            ]
        default:
            // Night - full spectrum but darker
            return colorScheme == .dark ?
                PaletteColor.allCases.map { $0.darkVariant } :
                [
                    PaletteColor.primary.color,
                    PaletteColor.secondary.color,
                    PaletteColor.background.color
                ]
        }
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
    
    // MARK: - Helper Methods for Game Status
    
    private func hasPlayedToday(_ game: Game) -> Bool {
        guard let streak = appState.getStreak(for: game),
              let lastPlayed = streak.lastPlayedDate else { return false }
        return Calendar.current.isDateInToday(lastPlayed)
    }
    
    private func isActiveToday(_ game: Game) -> Bool {
        guard let streak = appState.getStreak(for: game),
              let lastPlayed = streak.lastPlayedDate else { return false }
        let daysSinceLastPlayed = Calendar.current.dateComponents([.day], from: lastPlayed, to: Date()).day ?? 0
        return daysSinceLastPlayed < 7
    }
}

// MARK: - PaletteColor Extension
extension PaletteColor {
    /// Helper to get the appropriate color variant based on color scheme
    func color(for colorScheme: ColorScheme = .light) -> Color {
        colorScheme == .dark ? self.darkVariant : self.color
    }
}
