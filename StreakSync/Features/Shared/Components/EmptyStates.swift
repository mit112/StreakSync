//
//  EmptyStates.swift
//  StreakSync
//
//  Beautiful empty states with ContentUnavailableView
//

/*
 * EMPTYSTATES - ELEGANT EMPTY STATE COMPONENTS FOR BETTER USER EXPERIENCE
 * 
 * WHAT THIS FILE DOES:
 * This file provides beautiful, informative empty state components that are displayed
 * when there's no content to show. It's like a "friendly guide" that helps users
 * understand what to do when screens are empty, providing helpful messages, actions,
 * and visual cues. Think of it as the "empty space manager" that transforms potentially
 * confusing empty screens into helpful, engaging experiences that guide users forward.
 * 
 * WHY IT EXISTS:
 * Empty states are crucial for good user experience - they help users understand what
 * to do when there's no content to display. Instead of showing blank screens, this
 * component provides informative, actionable empty states that guide users and make
 * the app feel more welcoming and helpful. It handles different scenarios like no
 * games, no search results, and no achievements with appropriate messaging and actions.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This provides essential user guidance when screens are empty
 * - Creates beautiful, informative empty states for different scenarios
 * - Provides helpful messaging and actionable guidance
 * - Supports both modern iOS 17+ and legacy iOS versions
 * - Uses appropriate icons, colors, and animations
 * - Makes the app feel more welcoming and user-friendly
 * - Reduces user confusion and improves onboarding experience
 * 
 * WHAT IT REFERENCES:
 * - SwiftUI: For UI components and layout
 * - ContentUnavailableView: iOS 17+ native empty state component
 * - Label: For icon and text combinations
 * - Button: For actionable elements in empty states
 * - Image: For visual icons and illustrations
 * - Text: For informative messaging
 * 
 * WHAT REFERENCES IT:
 * - Dashboard views: Use this when no games are available
 * - Search results: Use this when no search results are found
 * - Achievement views: Use this when no achievements are unlocked
 * - Game lists: Use this when game lists are empty
 * - Various feature views: Use this for consistent empty state handling
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. EMPTY STATE IMPROVEMENTS:
 *    - The current empty states are good but could be more sophisticated
 *    - Consider adding more empty state variations and scenarios
 *    - Add support for custom empty state configurations
 *    - Implement smart empty state selection based on context
 * 
 * 2. USER EXPERIENCE IMPROVEMENTS:
 *    - The current empty states could be more user-friendly
 *    - Add support for empty state customization and preferences
 *    - Implement smart empty state recommendations
 *    - Add support for empty state tutorials and guidance
 * 
 * 3. ACCESSIBILITY IMPROVEMENTS:
 *    - The current accessibility support could be enhanced
 *    - Add better VoiceOver navigation and descriptions
 *    - Implement accessibility shortcuts
 *    - Add support for different accessibility needs
 * 
 * 4. VISUAL DESIGN IMPROVEMENTS:
 *    - The current visual design could be enhanced
 *    - Add support for more sophisticated visual elements
 *    - Implement smart visual adaptation for different contexts
 *    - Add support for dynamic visual elements
 * 
 * 5. PERFORMANCE OPTIMIZATIONS:
 *    - The current implementation could be optimized
 *    - Consider implementing efficient empty state rendering
 *    - Add support for empty state caching and reuse
 *    - Implement smart empty state management
 * 
 * 6. TESTING IMPROVEMENTS:
 *    - Add comprehensive unit tests for empty state logic
 *    - Test different empty state scenarios and configurations
 *    - Add UI tests for empty state interactions
 *    - Test accessibility features
 * 
 * 7. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for empty state features
 *    - Document the different empty state types and usage patterns
 *    - Add examples of how to use different empty states
 *    - Create empty state usage guidelines
 * 
 * 8. EXTENSIBILITY IMPROVEMENTS:
 *    - Make it easier to add new empty state types
 *    - Add support for custom empty state configurations
 *    - Implement empty state plugins
 *    - Add support for third-party empty state integrations
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - Empty states: UI components that show when there's no content to display
 * - User experience: Making sure the app is helpful and easy to use
 * - ContentUnavailableView: Apple's modern component for empty states
 * - User guidance: Helping users understand what to do next
 * - Visual design: Creating appealing and informative interfaces
 * - Accessibility: Making sure empty states work for all users
 * - iOS version compatibility: Supporting different iOS versions
 * - Component libraries: Collections of reusable UI components
 * - User onboarding: Helping new users get started with the app
 * - Design systems: Standardized approaches to creating consistent experiences
 */

import SwiftUI

// MARK: - Dashboard Empty State
struct DashboardEmptyState: View {
    let searchText: String
    let action: () -> Void
    
    var body: some View {
        if #available(iOS 17.0, *) {
            modernEmptyState
        } else {
            legacyEmptyState
        }
    }
    
    @available(iOS 17.0, *)
    private var modernEmptyState: some View {
        ContentUnavailableView {
            Label(
                searchText.isEmpty ? "No Games Yet" : "No Results",
                systemImage: searchText.isEmpty ? "gamecontroller" : "magnifyingglass"
            )
        } description: {
            Text(
                searchText.isEmpty
                ? "Start tracking your daily puzzle games.\nAdd your first game to begin!"
                : "No games match '\(searchText)'.\nTry a different search term."
            )
        } actions: {
            if searchText.isEmpty {
                Button("Browse Games") {
                    action()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }
    
    private var legacyEmptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: searchText.isEmpty ? "gamecontroller" : "magnifyingglass")
                .font(.system(size: 56))
                .foregroundStyle(.quaternary)
                .symbolEffect(.pulse, options: .repeating)
            
            VStack(spacing: 8) {
                Text(searchText.isEmpty ? "No Games Yet" : "No Results")
                    .font(.title2.weight(.semibold))
                
                Text(
                    searchText.isEmpty
                    ? "Start tracking your daily puzzle games"
                    : "No games match your search"
                )
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }
            
            if searchText.isEmpty {
                Button {
                    action()
                } label: {
                    Label("Browse Games", systemImage: "plus.circle.fill")
                        .font(.body.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Achievements Empty State
struct AchievementsEmptyState: View {
    var body: some View {
        if #available(iOS 17.0, *) {
            ContentUnavailableView(
                "No Achievements Yet",
                systemImage: "trophy",
                description: Text("Complete games and build streaks to unlock achievements!")
            )
        } else {
            VStack(spacing: 20) {
                Image(systemName: "trophy")
                    .font(.system(size: 56))
                    .foregroundStyle(.quaternary)
                
                VStack(spacing: 8) {
                    Text("No Achievements Yet")
                        .font(.title2.weight(.semibold))
                    
                    Text("Complete games and build streaks to unlock achievements!")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
        }
    }
}
