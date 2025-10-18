//
//  TieredAchievementsViewModel.swift
//  StreakSync
//
//  View model for tiered achievements grid
//

/*
 * TIEREDACHIEVEMENTSVIEWMODEL - ACHIEVEMENT DISPLAY AND INTERACTION LOGIC
 * 
 * WHAT THIS FILE DOES:
 * This file provides the business logic and data management for the tiered achievements
 * display interface. It's like a "achievement display controller" that manages how
 * achievements are shown, filtered, and organized for the user. Think of it as the
 * "achievement presentation brain" that processes achievement data and provides
 * computed properties for the achievement UI to display.
 * 
 * WHY IT EXISTS:
 * The achievements interface needs to handle complex logic like filtering by category,
 * computing statistics, and managing user interactions. Instead of putting all this
 * logic directly in the view, this ViewModel separates the business logic from the
 * UI, making the code more organized, testable, and maintainable.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This provides the core logic for the achievements display experience
 * - Manages achievement filtering and categorization
 * - Computes achievement statistics and progress metrics
 * - Handles user interactions with achievement categories
 * - Coordinates with AppState for achievement data access
 * - Provides reactive updates to the achievement UI
 * - Manages achievement-specific state and interactions
 * 
 * WHAT IT REFERENCES:
 * - AppState: For accessing achievement data and progress
 * - SwiftUI: For @Published properties and reactive updates
 * - AchievementCategory: For categorizing and filtering achievements
 * - TieredAchievement: For achievement data and progress information
 * 
 * WHAT REFERENCES IT:
 * - Achievement views: Use this for business logic and data management
 * - TieredAchievementsGridView: Uses this for achievement display logic
 * - AppContainer: Provides AppState dependency
 * - Various achievement components: Use this for data and interactions
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. STATE MANAGEMENT IMPROVEMENTS:
 *    - The current state management is good but could be more sophisticated
 *    - Consider adding more achievement-specific state properties
 *    - Add support for achievement customization and preferences
 *    - Implement smart achievement recommendations
 * 
 * 2. FILTERING IMPROVEMENTS:
 *    - The current filtering is basic - could be more sophisticated
 *    - Consider adding more filter options and combinations
 *    - Add support for saved filter presets
 *    - Implement smart filtering based on user behavior
 * 
 * 3. PERFORMANCE OPTIMIZATIONS:
 *    - The current implementation could be optimized
 *    - Consider implementing efficient filtering and computation
 *    - Add support for data caching and reuse
 *    - Implement smart data management
 * 
 * 4. USER EXPERIENCE IMPROVEMENTS:
 *    - The current achievement display could be more user-friendly
 *    - Add support for achievement customization and preferences
 *    - Implement smart achievement recommendations
 *    - Add support for achievement tutorials and guidance
 * 
 * 5. TESTING IMPROVEMENTS:
 *    - Add comprehensive unit tests for achievement logic
 *    - Test different filtering scenarios and edge cases
 *    - Add UI tests for achievement interactions
 *    - Test performance with large achievement datasets
 * 
 * 6. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for achievement features
 *    - Document the different filtering options and usage patterns
 *    - Add examples of how to use different achievement features
 *    - Create achievement usage guidelines
 * 
 * 7. EXTENSIBILITY IMPROVEMENTS:
 *    - Make it easier to add new achievement features
 *    - Add support for custom achievement configurations
 *    - Implement achievement plugins
 *    - Add support for third-party achievement integrations
 * 
 * 8. MONITORING AND OBSERVABILITY:
 *    - Add detailed logging for achievement interactions
 *    - Implement metrics for achievement usage and effectiveness
 *    - Add support for achievement debugging
 *    - Monitor achievement performance and reliability
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - ViewModels: Separate business logic from UI components
 * - MVVM pattern: Model-View-ViewModel architecture for clean separation
 * - Reactive programming: Using @Published properties for automatic UI updates
 * - Data filtering: Processing and organizing data for display
 * - User experience: Making sure the achievement interface is intuitive and helpful
 * - Performance: Making sure filtering and computation are efficient
 * - Testing: Ensuring achievement logic works correctly
 * - Code organization: Keeping related functionality together
 * - Dependency injection: Providing dependencies through initialization
 * - State management: Managing data and user interactions
 */

import SwiftUI

@MainActor
final class TieredAchievementsViewModel: ObservableObject {
    @Published var selectedCategory: AchievementCategory?
    @Published var hasAppeared = false
    
    internal let appState: AppState
    
    init(appState: AppState) {
        self.appState = appState
    }
    
    // MARK: - Grouped Achievements
    var groupedAchievements: [(category: AchievementCategory, achievements: [TieredAchievement])] {
        Dictionary(grouping: appState.tieredAchievements) { $0.category }
            .map { (category: $0.key, achievements: $0.value) }
            .sorted { $0.category.displayName < $1.category.displayName }
    }
    
    // MARK: - Filtered Achievements
    var filteredAchievements: [TieredAchievement] {
        if let category = selectedCategory {
            return appState.tieredAchievements.filter { $0.category == category }
        }
        return appState.tieredAchievements
    }
    
    // MARK: - Statistics
    var unlockedCount: Int {
        appState.tieredAchievements.filter { $0.isUnlocked }.count
    }
    
    var totalTiers: Int {
        appState.tieredAchievements.reduce(0) { total, achievement in
            total + (achievement.progress.tierUnlockDates.count)
        }
    }
    
    var completionPercentage: Int {
        let totalPossibleTiers = appState.tieredAchievements.reduce(0) { total, achievement in
            total + achievement.requirements.count
        }
        guard totalPossibleTiers > 0 else { return 0 }
        return Int((Double(totalTiers) / Double(totalPossibleTiers)) * 100)
    }
    
    // MARK: - Available Categories
    var availableCategories: [AchievementCategory] {
        let categories = Set(appState.tieredAchievements.map { $0.category })
        return AchievementCategory.allCases.filter { categories.contains($0) }
    }
}
