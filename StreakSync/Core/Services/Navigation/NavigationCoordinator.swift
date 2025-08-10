//
//  NavigationCoordinator.swift
//  Navigation state management with TabView support
//
//  Enhanced to handle tab-based navigation with separate NavigationStacks
//

import SwiftUI
import Observation

// MARK: - Main Tab Enum
enum MainTab: Int, CaseIterable {
    case home = 0
    case stats = 1
    case awards = 2
    case settings = 3
    
    var title: String {
        switch self {
        case .home: return "Home"
        case .stats: return "Stats"
        case .awards: return "Awards"
        case .settings: return "Settings"
        }
    }
    
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .stats: return "chart.line.uptrend.xyaxis"
        case .awards: return "trophy.fill"
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
    @Published var statsPath = NavigationPath()
    @Published var awardsPath = NavigationPath()
    @Published var settingsPath = NavigationPath()
    
    // MARK: - Sheet Presentation
    @Published var presentedSheet: SheetDestination?
    
    // MARK: - Legacy path (for migration)
    @Published var path = NavigationPath()
    
    // MARK: - Get current path (not as Binding)
    var currentNavigationPath: NavigationPath {
        switch selectedTab {
        case .home: return homePath
        case .stats: return statsPath
        case .awards: return awardsPath
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
            default:
                return false
            }
        }
    }
    
    enum SheetDestination: Identifiable {
        case addCustomGame
        case gameResult(GameResult)
        case achievementDetail(Achievement)
        case tieredAchievementDetail(TieredAchievement)
        
        var id: String {
            switch self {
            case .addCustomGame:
                return "addCustomGame"
            case .gameResult(let result):
                return "gameResult-\(result.id)"
            case .achievementDetail(let achievement):
                return "achievement-\(achievement.id)"
            case .tieredAchievementDetail(let achievement):
                return "tieredAchievement-\(achievement.id)"
            }
        }
    }
    
    // MARK: - Navigation Actions
    
    /// Navigate to a destination in the current tab
    // In NavigationCoordinator.swift, update the navigateTo function:

    /// Navigate to a destination in the current tab
    func navigateTo(_ destination: Destination) {
        // Ensure we're on the main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch self.selectedTab {
            case .home:
                // Check if we're not already navigating to the same destination
                if !self.homePath.isEmpty {
                    // Get the last element safely
                    let pathString = String(describing: self.homePath)
                    if pathString.contains(String(describing: destination)) {
                        return // Already navigating to this destination
                    }
                }
                self.homePath.append(destination)
                
            case .stats:
                if !self.statsPath.isEmpty {
                    let pathString = String(describing: self.statsPath)
                    if pathString.contains(String(describing: destination)) {
                        return
                    }
                }
                self.statsPath.append(destination)
                
            case .awards:
                if !self.awardsPath.isEmpty {
                    let pathString = String(describing: self.awardsPath)
                    if pathString.contains(String(describing: destination)) {
                        return
                    }
                }
                self.awardsPath.append(destination)
                
            case .settings:
                if !self.settingsPath.isEmpty {
                    let pathString = String(describing: self.settingsPath)
                    if pathString.contains(String(describing: destination)) {
                        return
                    }
                }
                self.settingsPath.append(destination)
            }
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
        case .stats:
            statsPath.removeLast(statsPath.count)
        case .awards:
            awardsPath.removeLast(awardsPath.count)
        case .settings:
            settingsPath.removeLast(settingsPath.count)
        }
    }
    
    /// Pop to root of specific tab
    func popToRoot(in tab: MainTab) {
        switch tab {
        case .home:
            homePath.removeLast(homePath.count)
        case .stats:
            statsPath.removeLast(statsPath.count)
        case .awards:
            awardsPath.removeLast(awardsPath.count)
        case .settings:
            settingsPath.removeLast(settingsPath.count)
        }
    }
    
    /// Reset all navigation
    func resetAllNavigation() {
        homePath = NavigationPath()
        statsPath = NavigationPath()
        awardsPath = NavigationPath()
        settingsPath = NavigationPath()
        selectedTab = .home
        presentedSheet = nil
    }
}
