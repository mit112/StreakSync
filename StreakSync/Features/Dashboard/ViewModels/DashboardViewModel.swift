//
//  DashboardViewModel.swift
//  StreakSync
//
//  Business logic for the dashboard view
//  FIXED: Updated to use new StreakSyncColors system
//

/*
 * DASHBOARDVIEWMODEL - DASHBOARD BUSINESS LOGIC AND DATA MANAGEMENT
 * 
 * WHAT THIS FILE DOES:
 * This file provides the business logic and data management for the main dashboard view.
 * It's like a "dashboard controller" that manages the data, filtering, and user interactions
 * for the home screen. Think of it as the "dashboard brain" that processes user input,
 * filters games, and provides computed properties for the dashboard UI to display.
 * 
 * WHY IT EXISTS:
 * The dashboard needs to handle complex logic like filtering games, managing search,
 * computing statistics, and coordinating with the app state. Instead of putting all
 * this logic directly in the view, this ViewModel separates the business logic from
 * the UI, making the code more organized, testable, and maintainable.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This provides the core logic for the main dashboard experience
 * - Manages game filtering and search functionality
 * - Computes dashboard statistics and metrics
 * - Handles user preferences and settings
 * - Coordinates with AppState for data access
 * - Provides reactive updates to the dashboard UI
 * - Manages dashboard-specific state and interactions
 * 
 * WHAT IT REFERENCES:
 * - AppState: For accessing game data and streaks
 * - SwiftUI: For @Published properties and reactive updates
 * - OSLog: For logging and debugging
 * - AppStorage: For persisting user preferences
 * - Game: For game data and filtering
 * - GameStreak: For streak data and calculations
 * 
 * WHAT REFERENCES IT:
 * - Dashboard views: Use this for business logic and data management
 * - MainTabView: Creates and manages this ViewModel
 * - AppContainer: Provides AppState dependency
 * - Various dashboard components: Use this for data and interactions
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. STATE MANAGEMENT IMPROVEMENTS:
 *    - The current state management is good but could be more sophisticated
 *    - Consider adding more dashboard-specific state properties
 *    - Add support for dashboard customization and preferences
 *    - Implement smart dashboard recommendations
 * 
 * 2. FILTERING IMPROVEMENTS:
 *    - The current filtering is basic - could be more sophisticated
 *    - Consider adding more filter options and combinations
 *    - Add support for saved filter presets
 *    - Implement smart filtering based on user behavior
 * 
 * 3. PERFORMANCE OPTIMIZATIONS:
 *    - The current implementation could be optimized
 *    - Consider implementing efficient filtering and search
 *    - Add support for data caching and reuse
 *    - Implement smart data management
 * 
 * 4. USER EXPERIENCE IMPROVEMENTS:
 *    - The current dashboard could be more user-friendly
 *    - Add support for dashboard customization and preferences
 *    - Implement smart dashboard recommendations
 *    - Add support for dashboard tutorials and guidance
 * 
 * 5. TESTING IMPROVEMENTS:
 *    - Add comprehensive unit tests for dashboard logic
 *    - Test different filtering scenarios and edge cases
 *    - Add UI tests for dashboard interactions
 *    - Test performance with large datasets
 * 
 * 6. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for dashboard features
 *    - Document the different filtering options and usage patterns
 *    - Add examples of how to use different dashboard features
 *    - Create dashboard usage guidelines
 * 
 * 7. EXTENSIBILITY IMPROVEMENTS:
 *    - Make it easier to add new dashboard features
 *    - Add support for custom dashboard configurations
 *    - Implement dashboard plugins
 *    - Add support for third-party dashboard integrations
 * 
 * 8. MONITORING AND OBSERVABILITY:
 *    - Add detailed logging for dashboard interactions
 *    - Implement metrics for dashboard usage and effectiveness
 *    - Add support for dashboard debugging
 *    - Monitor dashboard performance and reliability
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - ViewModels: Separate business logic from UI components
 * - MVVM pattern: Model-View-ViewModel architecture for clean separation
 * - Reactive programming: Using @Published properties for automatic UI updates
 * - Data filtering: Processing and organizing data for display
 * - User experience: Making sure the dashboard is intuitive and helpful
 * - Performance: Making sure filtering and search are efficient
 * - Testing: Ensuring dashboard logic works correctly
 * - Code organization: Keeping related functionality together
 * - Dependency injection: Providing dependencies through initialization
 * - State management: Managing data and user interactions
 */

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
                // A game is active if it has an active streak (played within 1 day AND has streak > 0)
                return streak.isActive
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
        guard let streak = appState.getStreak(for: game) else { return false }
        return streak.isActive
    }
}

// MARK: - PaletteColor Extension
extension PaletteColor {
    /// Helper to get the appropriate color variant based on color scheme
    func color(for colorScheme: ColorScheme = .light) -> Color {
        colorScheme == .dark ? self.darkVariant : self.color
    }
}
