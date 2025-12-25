//
//  NavigationCoordinator.swift
//  Navigation state management with TabView support
//
//  Enhanced to handle tab-based navigation with separate NavigationStacks
//

/*
 * NAVIGATIONCOORDINATOR - APP NAVIGATION TRAFFIC CONTROLLER
 * 
 * WHAT THIS FILE DOES:
 * This file is like a "traffic controller" for the app's navigation. It manages which tab is selected,
 * which screens are shown, and how users move between different parts of the app. Think of it as the
 * "GPS system" that knows where the user is and where they can go next. It keeps track of separate
 * navigation paths for each tab, so users don't lose their place when switching between tabs.
 * 
 * WHY IT EXISTS:
 * SwiftUI's navigation system can be complex, especially with tab-based apps. This file centralizes
 * all navigation logic in one place, making it easier to manage and debug. It also provides a clean
 * interface for other parts of the app to navigate programmatically (like when a notification
 * should take the user to a specific screen).
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This manages all navigation throughout the entire app
 * - Provides type-safe navigation with the Destination enum
 * - Maintains separate navigation stacks for each tab
 * - Handles sheet presentations and modal dialogs
 * - Supports deep linking and programmatic navigation
 * - Coordinates with the main tab view for seamless user experience
 * 
 * WHAT IT REFERENCES:
 * - SwiftUI: For NavigationPath and navigation components
 * - MainTab: Enum defining the four main tabs
 * - Destination: Enum defining all possible navigation destinations
 * - SheetDestination: Enum for modal presentations
 * - All data models: Game, GameStreak, TieredAchievement, etc.
 * 
 * WHAT REFERENCES IT:
 * - MainTabView: Uses this to manage tab selection and navigation
 * - All UI views: Use this to navigate to other screens
 * - AppContainer: Creates and manages the NavigationCoordinator
 * - Notification handlers: Use this for programmatic navigation
 * - Deep link handlers: Use this to navigate from URLs
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. NAVIGATION STATE MANAGEMENT:
 *    - The current approach uses separate paths for each tab - could be more sophisticated
 *    - Consider implementing navigation state persistence across app launches
 *    - Add navigation history tracking for better back button behavior
 *    - Implement navigation breadcrumbs for complex flows
 * 
 * 2. TYPE SAFETY IMPROVEMENTS:
 *    - The Destination enum is getting large - could be split into smaller enums
 *    - Consider using associated values more effectively
 *    - Add validation for navigation parameters
 *    - Implement navigation guards for restricted screens
 * 
 * 3. PERFORMANCE OPTIMIZATIONS:
 *    - The current implementation recreates navigation paths - could be optimized
 *    - Consider lazy loading of navigation destinations
 *    - Add navigation result caching
 *    - Implement navigation preloading for better performance
 * 
 * 4. USER EXPERIENCE IMPROVEMENTS:
 *    - Add navigation animations and transitions
 *    - Implement navigation gestures and shortcuts
 *    - Add support for navigation undo/redo
 *    - Consider adding navigation hints and guidance
 * 
 * 5. TESTING IMPROVEMENTS:
 *    - Add unit tests for all navigation methods
 *    - Test navigation state transitions
 *    - Add UI tests for navigation flows
 *    - Test deep linking and programmatic navigation
 * 
 * 6. ACCESSIBILITY IMPROVEMENTS:
 *    - Add accessibility labels for navigation actions
 *    - Implement VoiceOver navigation improvements
 *    - Add support for accessibility shortcuts
 *    - Consider different accessibility needs for navigation
 * 
 * 7. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for each navigation method
 *    - Document the navigation flow and relationships
 *    - Add examples of how to use each navigation method
 *    - Create navigation flow diagrams
 * 
 * 8. ERROR HANDLING:
 *    - Add error handling for navigation failures
 *    - Implement fallback navigation strategies
 *    - Add logging for navigation debugging
 *    - Handle edge cases in navigation state
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - @Published: Makes properties observable by SwiftUI
 * - @MainActor: Ensures all operations happen on the main thread
 * - NavigationPath: SwiftUI's way of managing navigation stacks
 * - ObservableObject: Makes this class work with SwiftUI's reactive system
 * - Enums with associated values: Allow passing data with navigation destinations
 * - Hashable: Required for using values in SwiftUI navigation
 * - Tab-based navigation: Common iOS pattern with separate navigation stacks
 * - Programmatic navigation: Code that can navigate without user interaction
 * - Deep linking: URLs that can navigate to specific screens in the app
 */

import SwiftUI
import Observation

// MARK: - Main Tab Enum
enum MainTab: Int, CaseIterable {
    case home = 0
    case awards = 1
    case friends = 2
    case settings = 3
    
    var title: String {
        switch self {
        case .home: return "Home"
        case .awards: return "Awards"
        case .friends: return "Friends"
        case .settings: return "Settings"
        }
    }
    
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .awards: return "trophy.fill"
        case .friends: return "person.2.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - Navigation Coordinator
@MainActor
final class NavigationCoordinator: ObservableObject {
    // MARK: - Tab Management
    @Published var selectedTab: MainTab = .home
    
    // MARK: - Individual Tab Navigation Paths
    @Published var homePath = NavigationPath()
    @Published var awardsPath = NavigationPath()
    @Published var friendsPath = NavigationPath()
    @Published var settingsPath = NavigationPath()
    
    // MARK: - Sheet Presentation
    @Published var presentedSheet: SheetDestination?
    
    // MARK: - Deep Link State
    /// Join code received from deep link - FriendManagementView will consume this
    @Published var pendingJoinCode: String?
    /// Triggers presentation of the friend management sheet with join code
    @Published var shouldShowJoinSheet: Bool = false
    
    // MARK: - Legacy path (for migration)
    @Published var path = NavigationPath()
    
    // MARK: - Get current path (not as Binding)
    var currentNavigationPath: NavigationPath {
        switch selectedTab {
        case .home: return homePath
        case .awards: return awardsPath
        case .friends: return friendsPath
        case .settings: return settingsPath
        }
    }
    
    enum Destination: Hashable {
        case gameDetail(Game)
        case streakHistory(GameStreak)
        case allStreaks
        case achievements
        case settings
        case gameManagement
        case tieredAchievementDetail(TieredAchievement)
        case analyticsDashboard
        case streakTrendsDetail(timeRange: AnalyticsTimeRange, game: Game?)
        
        func hash(into hasher: inout Hasher) {
            switch self {
            case .gameDetail(let game):
                hasher.combine("gameDetail")
                hasher.combine(game.id)
            case .streakHistory(let streak):
                hasher.combine("streakHistory")
                hasher.combine(streak.id)
            case .allStreaks:
                hasher.combine("allStreaks")
            case .achievements:
                hasher.combine("achievements")
            case .settings:
                hasher.combine("settings")
            case .gameManagement:
                hasher.combine("gameManagement")
            case .tieredAchievementDetail(let achievement):
                hasher.combine("tieredAchievementDetail")
                hasher.combine(achievement.id)
            case .analyticsDashboard:
                hasher.combine("analyticsDashboard")
            case .streakTrendsDetail(let timeRange, let game):
                hasher.combine("streakTrendsDetail")
                hasher.combine(timeRange.rawValue)
                hasher.combine(game?.id)
            }
        }
        
        static func == (lhs: Destination, rhs: Destination) -> Bool {
            switch (lhs, rhs) {
            case (.gameDetail(let lhsGame), .gameDetail(let rhsGame)):
                return lhsGame.id == rhsGame.id
            case (.streakHistory(let lhsStreak), .streakHistory(let rhsStreak)):
                return lhsStreak.id == rhsStreak.id
            case (.allStreaks, .allStreaks):
                return true
            case (.achievements, .achievements):
                return true
            case (.settings, .settings):
                return true
            case (.gameManagement, .gameManagement):
                return true
            case (.tieredAchievementDetail(let lhsAchievement), .tieredAchievementDetail(let rhsAchievement)):
                return lhsAchievement.id == rhsAchievement.id
            case (.analyticsDashboard, .analyticsDashboard):
                return true
            case (.streakTrendsDetail(let lhsTimeRange, let lhsGame), .streakTrendsDetail(let rhsTimeRange, let rhsGame)):
                return lhsTimeRange == rhsTimeRange && lhsGame?.id == rhsGame?.id
            default:
                return false
            }
        }
    }
    
    enum SheetDestination: Identifiable {
        case addCustomGame
        case gameResult(GameResult)
        // Legacy achievement detail removed in favor of tiered only
        case tieredAchievementDetail(TieredAchievement)
        
        var id: String {
            switch self {
            case .addCustomGame:
                return "addCustomGame"
            case .gameResult(let result):
                return "gameResult-\(result.id)"
            case .tieredAchievementDetail(let achievement):
                return "tieredAchievement-\(achievement.id)"
            }
        }
    }
    
    // MARK: - Navigation Actions
    
    /// Navigate to a destination in the current tab (no redundant main-thread hop under @MainActor)
    func navigateTo(_ destination: Destination) {
        switch selectedTab {
        case .home:
            if !homePath.isEmpty {
                let pathString = String(describing: homePath)
                if pathString.contains(String(describing: destination)) { return }
            }
            homePath.append(destination)
            
        case .awards:
            if !awardsPath.isEmpty {
                let pathString = String(describing: awardsPath)
                if pathString.contains(String(describing: destination)) { return }
            }
            awardsPath.append(destination)
            
        case .friends:
            if !friendsPath.isEmpty {
                let pathString = String(describing: friendsPath)
                if pathString.contains(String(describing: destination)) { return }
            }
            friendsPath.append(destination)
            
        case .settings:
            if !settingsPath.isEmpty {
                let pathString = String(describing: settingsPath)
                if pathString.contains(String(describing: destination)) { return }
            }
            settingsPath.append(destination)
        }
    }
    
    /// Switch to a specific tab
    func switchToTab(_ tab: MainTab) {
        selectedTab = tab
    }
    
    /// Switch to tab and navigate
    func switchToTabAndNavigate(_ tab: MainTab, destination: Destination) {
        selectedTab = tab
        // Small delay to ensure tab switch completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.navigateTo(destination)
        }
    }
    
    /// Present a sheet
    func presentSheet(_ sheet: SheetDestination) {
        presentedSheet = sheet
    }
    
    /// Dismiss the current sheet
    func dismissSheet() {
        presentedSheet = nil
    }
    
    /// Pop to root of current tab
    func popToRoot() {
        switch selectedTab {
        case .home:
            homePath.removeLast(homePath.count)
        case .awards:
            awardsPath.removeLast(awardsPath.count)
        case .friends:
            friendsPath.removeLast(friendsPath.count)
        case .settings:
            settingsPath.removeLast(settingsPath.count)
        }
    }
    
    /// Pop to root of specific tab
    func popToRoot(in tab: MainTab) {
        switch tab {
        case .home:
            homePath.removeLast(homePath.count)
        case .awards:
            awardsPath.removeLast(awardsPath.count)
        case .friends:
            friendsPath.removeLast(friendsPath.count)
        case .settings:
            settingsPath.removeLast(settingsPath.count)
        }
    }
    
    /// Reset all navigation
    func resetAllNavigation() {
        homePath = NavigationPath()
        awardsPath = NavigationPath()
        friendsPath = NavigationPath()
        settingsPath = NavigationPath()
        selectedTab = .home
        presentedSheet = nil
    }
    
    // MARK: - Notification Navigation Methods
    
    /// Navigate to a specific game
    func navigateToGame(gameId: UUID) {
        // Find the game by ID from AppState
        // We need to access the games from AppState to find the specific game
        // For now, we'll navigate to the home tab and post a notification for the UI to handle
        switchToTab(.home)
        
        // Post a notification to navigate to the specific game
        NotificationCenter.default.post(
            name: Notification.Name("NavigateToGame"),
            object: ["gameId": gameId]
        )
    }
    
    /// Navigate to achievements with optional highlight
    func navigateToAchievements(highlightId: UUID? = nil) {
        switchToTab(.awards)
        // The achievements view can handle highlighting based on the highlightId
    }
    
    /// Handle join group deep link - navigates to Friends tab and shows join sheet
    func handleJoinGroupDeepLink(code: String) {
        pendingJoinCode = code
        switchToTab(.friends)
        // Slight delay to ensure tab switch completes before showing sheet
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.shouldShowJoinSheet = true
        }
    }
    
    /// Setup notification observers for deep links
    func setupDeepLinkObservers() {
        NotificationCenter.default.addObserver(
            forName: .joinGroupRequested,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let userInfo = notification.object as? [String: String],
                  let code = userInfo["code"] else { return }
            Task { @MainActor in
                self?.handleJoinGroupDeepLink(code: code)
            }
        }
    }
}
