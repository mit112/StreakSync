//
//  NavigationCoordinator.swift
//  Navigation state management using iOS 16+ NavigationStack
//
//  Handles all app navigation and modal presentations
//

import SwiftUI
import Observation

// MARK: - Navigation Coordinator
@MainActor
final class NavigationCoordinator: ObservableObject {
    @Published var path = NavigationPath()
    @Published var presentedSheet: SheetDestination?

    
    enum Destination: Hashable {
        case gameDetail(Game)
        case streakHistory(GameStreak)
        case allStreaks
        case achievements
        case settings
        
        // Custom Hashable implementation for performance
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
            }
        }
        
        // Equatable conformance (automatic synthesis now works)
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
            default:
                return false
            }
        }
    }
    
    enum SheetDestination: Identifiable {
        case addCustomGame
        case gameResult(GameResult)
        case achievementDetail(Achievement)
        
        var id: String {
            switch self {
            case .addCustomGame: return "addCustomGame"
            case .gameResult(let result): return "gameResult-\(result.id)"
            case .achievementDetail(let achievement): return "achievement-\(achievement.id)"
            }
        }
    }
    
    // Navigation actions
    func navigateTo(_ destination: Destination) {
        path.append(destination)
    }
    
    func presentSheet(_ sheet: SheetDestination) {
        presentedSheet = sheet
    }
    
    func dismissSheet() {
        presentedSheet = nil
    }
    
    func popToRoot() {
        path.removeLast(path.count)
    }
}
