//
//  AnimatedGameCard.swift
//  StreakSync
//
//  Animated game card component extracted from ImprovedDashboardView
//

/*
 * ANIMATEDGAMECARD - ENGAGING GAME DISPLAY WITH SMOOTH ANIMATIONS
 * 
 * WHAT THIS FILE DOES:
 * This file provides an animated, interactive card component for displaying individual games
 * with their streaks, progress, and status. It's like a "game showcase card" that presents
 * each game in an attractive, animated format with visual feedback and smooth transitions.
 * Think of it as the "game presentation system" that makes each game look appealing and
 * provides clear visual information about the user's progress and achievements.
 * 
 * WHY IT EXISTS:
 * The app needs an attractive way to display games and their associated streaks. This
 * component provides a consistent, animated card format that shows game information,
 * streak data, and completion status in an engaging way. It makes the dashboard feel
 * more dynamic and provides clear visual feedback about the user's gaming progress.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This is the primary way games are displayed throughout the app
 * - Creates engaging, animated cards for each game
 * - Shows streak information, progress, and completion status
 * - Provides visual feedback with animations and transitions
 * - Uses consistent styling and color theming
 * - Makes the app feel more dynamic and engaging
 * - Provides clear visual hierarchy and information display
 * 
 * WHAT IT REFERENCES:
 * - Game: Core game data model
 * - GameStreak: Streak information and progress data
 * - AppState: For accessing current app state and data
 * - StreakSyncColors: For consistent color theming
 * - SafeSFSymbol: For safe icon display with fallbacks
 * - AnimatedStreakStat: For displaying streak statistics
 * - GlassEffect: For modern glassmorphism styling
 * 
 * WHAT REFERENCES IT:
 * - Dashboard views: Use this to display games in the main interface
 * - Game list views: Use this to show games in various contexts
 * - Search results: Use this to display matching games
 * - Category views: Use this to show games by category
 * - Various feature views: Use this for consistent game display
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. CARD DESIGN IMPROVEMENTS:
 *    - The current design is good but could be more sophisticated
 *    - Consider adding more card variations and layouts
 *    - Add support for custom card configurations
 *    - Implement smart card layout selection based on content
 * 
 * 2. ANIMATION IMPROVEMENTS:
 *    - The current animations are good but could be enhanced
 *    - Consider adding more sophisticated animation effects
 *    - Add support for custom animation configurations
 *    - Implement smart animation selection based on context
 * 
 * 3. INFORMATION DISPLAY IMPROVEMENTS:
 *    - The current information display could be enhanced
 *    - Add support for more detailed game information
 *    - Implement smart information prioritization
 *    - Add support for customizable information display
 * 
 * 4. ACCESSIBILITY IMPROVEMENTS:
 *    - The current accessibility support could be enhanced
 *    - Add better VoiceOver navigation and descriptions
 *    - Implement accessibility shortcuts
 *    - Add support for different accessibility needs
 * 
 * 5. PERFORMANCE OPTIMIZATIONS:
 *    - The current implementation could be optimized
 *    - Consider implementing efficient card rendering
 *    - Add support for card caching and reuse
 *    - Implement smart card management
 * 
 * 6. USER EXPERIENCE IMPROVEMENTS:
 *    - The current card system could be more user-friendly
 *    - Add support for card customization and preferences
 *    - Implement smart card recommendations
 *    - Add support for card tutorials and guidance
 * 
 * 7. TESTING IMPROVEMENTS:
 *    - Add comprehensive unit tests for card logic
 *    - Test different card configurations and scenarios
 *    - Add UI tests for card interactions
 *    - Test accessibility features
 * 
 * 8. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for card features
 *    - Document the different card types and usage patterns
 *    - Add examples of how to use different cards
 *    - Create card usage guidelines
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - Card components: UI elements that display information in a contained format
 * - Animations: Visual effects that make interactions feel smooth and engaging
 * - Visual hierarchy: Organizing information to guide user attention
 * - Color theming: Using consistent colors throughout the app
 * - Data binding: Connecting UI components to data sources
 * - Component composition: Building complex UI from simpler components
 * - User experience: Making sure the interface is engaging and informative
 * - Accessibility: Making sure cards work for users with different needs
 * - Performance: Making sure cards render efficiently
 * - Design systems: Standardized approaches to creating consistent experiences
 */

import SwiftUI

struct AnimatedGameCard: View {
    let game: Game
    let animationIndex: Int
    let hasInitiallyAppeared: Bool
    let onTap: () -> Void
    
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showCheckmark = false
    @State private var hasAnimatedCheckmark = false
    
    private var streak: GameStreak? {
        appState.getStreak(for: game)
    }
    
    // Get vibrant color for the game category
    private var gameColor: Color {
        StreakSyncColors.gameColor(for: game.category, colorScheme: colorScheme)
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    // Colorful icon with gradient background
                    Image.safeSystemName(game.iconSystemName, fallback: "gamecontroller")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            LinearGradient(
                                colors: [
                                    gameColor,
                                    gameColor.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: gameColor.opacity(0.3), radius: 4, y: 2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(game.displayName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        if let lastPlayed = streak?.lastPlayedDate {
                            Text(lastPlayed.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if let lastPlayed = streak?.lastPlayedDate, Calendar.current.isDateInToday(lastPlayed) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(StreakSyncColors.success(for: colorScheme))
                            .transition(.scale.combined(with: .opacity))
                            .opacity(showCheckmark ? 1 : 0)
                            .scaleEffect(showCheckmark ? 1 : 0.5)
                    }
                }
                
                // Streak info
                if let streak = streak, streak.currentStreak > 0 {
                    HStack(spacing: 16) {
                        AnimatedStreakStat(
                            value: "\(streak.currentStreak)",
                            label: "Current",
                            colors: [
                                StreakSyncColors.primary(for: colorScheme),
                                StreakSyncColors.secondary(for: colorScheme)
                            ]
                        )
                        
                        AnimatedStreakStat(
                            value: "\(streak.maxStreak)",
                            label: "Best",
                            colors: [gameColor, gameColor.opacity(0.8)]
                        )
                        
                        Spacer()
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.clear)
                    .glassEffect(type: .medium, tint: gameColor)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .modifier(InitialAnimationModifier(hasAppeared: hasInitiallyAppeared, index: animationIndex, totalCount: 10))
        .onAppear {
            let hasPlayedToday = streak?.lastPlayedDate.map { Calendar.current.isDateInToday($0) } ?? false
            if hasPlayedToday && !hasAnimatedCheckmark {
                withAnimation(.easeInOut.delay(Double(animationIndex) * 0.1)) {
                    showCheckmark = true
                }
                hasAnimatedCheckmark = true
            }
        }
    }
}

// MARK: - Enhanced Animated Streak Stat Component
struct AnimatedStreakStat: View {
    let value: String
    let label: String
    let colors: [Color] // Changed from single color to gradient colors
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.caption)
                    .foregroundStyle(
                        LinearGradient(
                            colors: colors,
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                Text(value)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: colors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .contentTransition(.numericText())
            }
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}


// MARK: - Scale Button Style (moved here as it's used by AnimatedGameCard)
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    HapticManager.shared.trigger(.buttonTap)
                }
            }
    }
}

// MARK: - Initial Animation Modifier (shared utility)
// MARK: - Initial Animation Modifier (Keep for compatibility)
struct InitialAnimationModifier: ViewModifier {
    let hasAppeared: Bool
    let index: Int
    let totalCount: Int
    
    func body(content: Content) -> some View {
        content
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 20)
            .animation(
                .smooth(duration: 0.5)
                .delay(Double(index) * 0.05),
                value: hasAppeared
            )
    }
}


// MARK: - Preview
#Preview {
    VStack(spacing: 16) {
        AnimatedGameCard(
            game: Game.wordle,
            animationIndex: 0,
            hasInitiallyAppeared: true,
            onTap: { print("Tapped") }
        )
        
        AnimatedGameCard(
            game: Game.quordle,
            animationIndex: 1,
            hasInitiallyAppeared: true,
            onTap: { print("Tapped") }
        )
        
        AnimatedGameCard(
            game: Game.nerdle,
            animationIndex: 2,
            hasInitiallyAppeared: true,
            onTap: { print("Tapped") }
        )
    }
    .padding()
    .preferredColorScheme(.dark) // Test in dark mode
    .environment(AppState())
}
