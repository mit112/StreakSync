//
//  DetailViews.swift
//  StreakSync
//
//  Simplified detail views for game results and achievements
//

/*
 * PLACEHOLDERVIEWS - REUSABLE UI COMPONENTS AND DETAIL DISPLAYS
 * 
 * WHAT THIS FILE DOES:
 * This file provides reusable UI components and detail views for displaying specific
 * information in a clean, consistent way. It's like a "component library" that contains
 * common UI patterns and detail displays used throughout the app. Think of it as the
 * "UI toolkit" that provides standardized ways to show detailed information about
 * achievements, game results, and other app content.
 * 
 * WHY IT EXISTS:
 * The app needs consistent ways to display detailed information about achievements,
 * game results, and other content. Instead of creating different components for each
 * use case, this file provides reusable components that ensure consistent styling
 * and behavior. It also includes placeholder views for loading states and empty
 * content, making the app feel more polished and responsive.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This provides consistent UI components throughout the app
 * - Creates reusable detail views for achievements and game results
 * - Provides placeholder views for loading and empty states
 * - Ensures consistent styling and behavior across the app
 * - Makes the app feel more polished and professional
 * - Reduces code duplication and maintenance overhead
 * - Provides a foundation for consistent user experience
 * 
 * WHAT IT REFERENCES:
 * - SwiftUI: For UI components and layout
 * - SafeSFSymbol: For safe icon display with fallbacks
 * - Achievement: For achievement data and display
 * - GameResult: For game result data and display
 * - Spacing: For consistent spacing throughout the app
 * - Color system: For consistent colors and theming
 * 
 * WHAT REFERENCES IT:
 * - Achievement views: Use this for displaying achievement details
 * - Game result views: Use this for displaying game result details
 * - Loading states: Use this for placeholder content
 * - Empty states: Use this for when there's no content to display
 * - Various feature views: Use this for consistent detail displays
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. COMPONENT ORGANIZATION:
 *    - The current organization is good but could be more modular
 *    - Consider separating into different files by component type
 *    - Add support for more component variations and configurations
 *    - Implement component composition for complex displays
 * 
 * 2. STYLING IMPROVEMENTS:
 *    - The current styling is consistent but could be more flexible
 *    - Consider adding support for different themes and styles
 *    - Add support for custom styling and branding
 *    - Implement responsive design for different screen sizes
 * 
 * 3. ACCESSIBILITY IMPROVEMENTS:
 *    - The current accessibility support could be enhanced
 *    - Add better VoiceOver navigation and descriptions
 *    - Implement accessibility shortcuts
 *    - Add support for different accessibility needs
 * 
 * 4. PERFORMANCE OPTIMIZATIONS:
 *    - The current implementation could be optimized
 *    - Consider implementing efficient rendering for large datasets
 *    - Add support for lazy loading and view recycling
 *    - Implement smart caching for frequently used components
 * 
 * 5. USER EXPERIENCE IMPROVEMENTS:
 *    - The current components could be more interactive
 *    - Add support for different interaction patterns
 *    - Implement smart defaults based on content type
 *    - Add support for customization and personalization
 * 
 * 6. TESTING IMPROVEMENTS:
 *    - Add comprehensive unit tests for component logic
 *    - Test different content scenarios and edge cases
 *    - Add UI tests for component interactions
 *    - Test accessibility features
 * 
 * 7. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for component features
 *    - Document the different component types and usage patterns
 *    - Add examples of how to use different components
 *    - Create component usage guidelines
 * 
 * 8. EXTENSIBILITY IMPROVEMENTS:
 *    - Make it easier to add new component types
 *    - Add support for custom component layouts
 *    - Implement component plugins
 *    - Add support for third-party component integrations
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - Reusable components: UI elements that can be used in multiple places
 * - Detail views: Screens that show detailed information about specific items
 * - Placeholder views: UI elements that show when content is loading or empty
 * - Component libraries: Collections of reusable UI components
 * - Consistent styling: Making sure all parts of the app look cohesive
 * - User experience: Making sure the app is easy and pleasant to use
 * - Accessibility: Making sure the app is usable for everyone
 * - Performance: Making sure the app runs smoothly
 * - Code organization: Keeping related functionality together
 * - Design systems: Standardized approaches to creating consistent experiences
 */

import SwiftUI

//// MARK: - Game Result Detail View
//struct GameResultDetailView: View {
//    let result: GameResult
//    @Environment(\.dismiss) private var dismiss
//    
//    var body: some View {
//        NavigationStack {
//            ScrollView {
//                VStack(spacing: Spacing.xxl) {
//                    // Score display
//                    VStack(spacing: Spacing.md) {
//                        Text(result.scoreEmoji)
//                            .font(.system(size: 72))
//                        
//                        Text(result.gameName.capitalized)
//                            .font(.title3.weight(.medium))
//                        
//                        Text(result.displayScore)
//                            .font(.headline)
//                            .foregroundStyle(.secondary)
//                    }
//                    .padding(.top, Spacing.xl)
//                    
//                    // Details
//                    VStack(spacing: 0) {
//                        DetailRow(label: "Date", value: result.date.formatted(date: .abbreviated, time: .omitted))
//                        Divider()
//                        DetailRow(label: "Status", value: result.completed ? "Completed" : "Not Completed")
//                        Divider()
//                        DetailRow(label: "Attempts", value: result.displayScore)
//                        
//                        if let puzzleNumber = result.parsedData["puzzleNumber"] {
//                            Divider()
//                            DetailRow(label: "Puzzle", value: "#\(puzzleNumber)")
//                        }
//                    }
//                    .background(Color(.secondarySystemBackground))
//                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card))
//                    
//                    // Share button
//                    ShareLink(item: result.sharedText) {
//                        Label("Share Result", systemImage: "square.and.arrow.up")
//                            .frame(maxWidth: .infinity)
//                    }
//                    .buttonStyle(.borderedProminent)
//                }
//                .padding()
//            }
//            .navigationTitle("Game Result")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .topBarTrailing) {
//                    Button("Done") {
//                        dismiss()
//                    }
//                }
//            }
//        }
//        .presentationDetents([.medium])
//    }
//}

// MARK: - Achievement Detail View
struct AchievementDetailView: View {
    let achievement: Achievement
    @Environment(\.dismiss) private var dismiss
    
    private var safeIconName: String {
        let iconName = achievement.iconSystemName
        return iconName.isEmpty ? "star.fill" : iconName
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.xxl) {
                // Achievement icon
                VStack(spacing: Spacing.lg) {
                    ZStack {
                        Circle()
                            .fill(achievement.isUnlocked ? achievement.displayColor.opacity(0.2) : Color(.systemGray6))
                            .frame(width: 100, height: 100)
                        
                        Image.safeSystemName(safeIconName, fallback: "star.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(achievement.isUnlocked ? achievement.displayColor : .gray)
                    }
                    
                    VStack(spacing: Spacing.xs) {
                        Text(achievement.title)
                            .font(.title3.weight(.semibold))
                        
                        Text(achievement.isUnlocked ? "Unlocked" : "Locked")
                            .font(.subheadline)
                            .foregroundStyle(achievement.isUnlocked ? .green : .secondary)
                    }
                }
                
                // Description
                Text(achievement.description)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                
                // Unlock info
                if let unlockedDate = achievement.unlockedDate {
                    VStack(spacing: Spacing.sm) {
                        Label("Unlocked on", systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(unlockedDate.formatted(date: .complete, time: .omitted))
                            .font(.subheadline)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.button))
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Achievement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}



// MARK: - Detail Row Helper
//struct DetailRow: View {
//    let label: String
//    let value: String
//    
//    var body: some View {
//        HStack {
//            Text(label)
//                .font(.subheadline)
//                .foregroundStyle(.secondary)
//            
//            Spacer()
//            
//            Text(value)
//                .font(.subheadline)
//        }
//        .padding()
//    }
//}

// MARK: - Preview
#Preview("Game Result Detail") {
    GameResultDetailView(
        result: GameResult(
            gameId: UUID(),
            gameName: "wordle",
            date: Date(),
            score: 3,
            maxAttempts: 6,
            completed: true,
            sharedText: "Wordle 942 3/6",
            parsedData: ["puzzleNumber": "942"]
        )
    )
}

#Preview("Achievement Detail") {
    AchievementDetailView(
        achievement: Achievement(
            title: "Week Warrior",
            description: "Maintain a 7-day streak",
            iconSystemName: "flame.fill",
            requirement: .streakLength(7),
            unlockedDate: Date()
        )
    )
}
