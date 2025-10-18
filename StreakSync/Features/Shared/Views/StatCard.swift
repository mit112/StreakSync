//
//  StatCard.swift
//  StreakSync
//
//  Reusable stat card component for displaying metrics
//  FIXED: Simplified gradient handling for StreakSyncColors
//

/*
 * STATCARD - REUSABLE METRICS DISPLAY COMPONENT
 * 
 * WHAT THIS FILE DOES:
 * This file creates a reusable component for displaying statistics and metrics in a
 * beautiful, consistent way throughout the app. It's like a "metric display widget"
 * that shows important numbers (like streak counts, games played, etc.) with icons,
 * colors, and animations. Think of it as the "statistics card" that makes data
 * visually appealing and easy to understand at a glance.
 * 
 * WHY IT EXISTS:
 * The app needs to display lots of different statistics and metrics in a consistent
 * way. Instead of creating different components for each type of stat, this reusable
 * component provides a standardized way to display any metric with proper styling,
 * animations, and user interactions. It ensures all statistics look cohesive and
 * professional throughout the app.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This provides consistent statistics display throughout the app
 * - Creates beautiful, animated metric cards with icons and colors
 * - Supports different types of statistics (streaks, games, achievements, etc.)
 * - Provides interactive elements with haptic feedback and animations
 * - Ensures consistent visual design for all metrics
 * - Handles different color schemes and themes automatically
 * - Integrates with the app's design system and color palette
 * 
 * WHAT IT REFERENCES:
 * - PaletteColor: The app's color system for consistent theming
 * - SafeSymbol: For safe SF Symbol usage with fallbacks
 * - SwiftUI: For UI components, animations, and interactions
 * - ColorScheme: For adapting to light/dark mode
 * - LinearGradient: For beautiful color transitions
 * 
 * WHAT REFERENCES IT:
 * - Dashboard: Uses this to display key statistics
 * - Game detail views: Use this to show game-specific metrics
 * - Analytics views: Use this to display performance data
 * - Achievement views: Use this to show progress statistics
 * - Various feature views: Use this for consistent metric display
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. COMPONENT ORGANIZATION:
 *    - The current component is well-organized but could be more modular
 *    - Consider separating into smaller, more focused components
 *    - Add support for different card layouts and sizes
 *    - Implement component composition for complex metrics
 * 
 * 2. ANIMATION IMPROVEMENTS:
 *    - The current animations are basic - could be more sophisticated
 *    - Add support for custom animations and transitions
 *    - Implement smart animations based on data changes
 *    - Add support for animation preferences and accessibility
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
 *    - Implement smart caching for frequently used metrics
 * 
 * 5. USER EXPERIENCE IMPROVEMENTS:
 *    - The current interface could be more intuitive
 *    - Add support for different interaction patterns
 *    - Implement smart defaults based on metric type
 *    - Add support for customization and personalization
 * 
 * 6. TESTING IMPROVEMENTS:
 *    - Add comprehensive unit tests for component logic
 *    - Test different metric types and data scenarios
 *    - Add UI tests for component interactions
 *    - Test accessibility features
 * 
 * 7. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for component features
 *    - Document the different metric types and usage patterns
 *    - Add examples of how to use different features
 *    - Create component usage guidelines
 * 
 * 8. EXTENSIBILITY IMPROVEMENTS:
 *    - Make it easier to add new metric types
 *    - Add support for custom metric layouts
 *    - Implement metric plugins
 *    - Add support for third-party metric integrations
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - Reusable components: UI elements that can be used in multiple places
 * - Statistics display: Showing numerical data in a visually appealing way
 * - Animations: Making UI elements move and change smoothly
 * - Color systems: Using consistent colors throughout an app
 * - Accessibility: Making sure the app is usable for everyone
 * - User experience: Making sure the app is easy and pleasant to use
 * - Design systems: Standardized visual elements and components
 * - SwiftUI: Apple's modern UI framework for building user interfaces
 * - Component composition: Building complex UI from simpler parts
 * - Visual design: Creating beautiful and engaging user interfaces
 */

import SwiftUI

// MARK: - Generic Stat Card
struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let gradientColors: [Color] // Store colors instead of gradient
    let action: (() -> Void)?
    
    @State private var isPressed = false
    @Environment(\.colorScheme) private var colorScheme
    
    init(
        icon: String,
        value: String,
        label: String,
        gradient: LinearGradient,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.value = value
        self.label = label
        // For backward compatibility, we'll store placeholder colors
        self.gradientColors = [Color.blue, Color.purple]
        self.action = action
    }
    
    // New initializer that takes colors directly
    init(
        icon: String,
        value: String,
        label: String,
        colors: [Color],
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.value = value
        self.label = label
        self.gradientColors = colors
        self.action = action
    }
    
    // Convenience initializers using palette colors
    static func activeStreaks(_ count: Int, action: (() -> Void)? = nil) -> StatCard {
        StatCard(
            icon: "flame.fill",
            value: "\(count)",
            label: "Active",
            colors: [PaletteColor.secondary.color, PaletteColor.primary.color],
            action: action
        )
    }
    
    static func todayCompleted(_ count: Int, action: (() -> Void)? = nil) -> StatCard {
        StatCard(
            icon: "checkmark.circle.fill",
            value: "\(count)",
            label: "Today",
            colors: [PaletteColor.primary.color],
            action: action
        )
    }
    
    static func totalGames(_ count: Int, action: (() -> Void)? = nil) -> StatCard {
        StatCard(
            icon: "gamecontroller.fill",
            value: "\(count)",
            label: "Games",
            colors: [PaletteColor.textSecondary.color, PaletteColor.cardBackground.color],
            action: action
        )
    }
    
    var body: some View {
        Button {
            if let action = action {
                action()
            } else {
                // Default animation when no action
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    isPressed.toggle()
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image.safeSystemName(icon, fallback: "chart.bar")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(adaptedGradient)
                    .symbolEffect(.bounce, value: isPressed)
                
                VStack(alignment: .leading, spacing: 0) {
                    Text(value)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                    
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                adaptedGradient.opacity(0.3),
                                lineWidth: 1
                            )
                    )
            )
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPressed)
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
    
    // Create gradient with adapted colors for current color scheme
    private var adaptedGradient: LinearGradient {
        let adaptedColors = gradientColors.map { color in
            adaptColorForScheme(color)
        }
        
        return LinearGradient(
            colors: adaptedColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // Adapt individual colors to color scheme
    private func adaptColorForScheme(_ color: Color) -> Color {
        // Check if this is one of our palette colors and adapt accordingly
        if color == PaletteColor.primary.color {
            return colorScheme == .dark ? PaletteColor.primary.darkVariant : PaletteColor.primary.color
        } else if color == PaletteColor.secondary.color {
            return colorScheme == .dark ? PaletteColor.secondary.darkVariant : PaletteColor.secondary.color
        } else if color == PaletteColor.textSecondary.color {
            return colorScheme == .dark ? PaletteColor.textSecondary.darkVariant : PaletteColor.textSecondary.color
        } else if color == PaletteColor.cardBackground.color {
            return colorScheme == .dark ? PaletteColor.cardBackground.darkVariant : PaletteColor.cardBackground.color
        } else if color == PaletteColor.background.color {
            return colorScheme == .dark ? PaletteColor.background.darkVariant : PaletteColor.background.color
        }
        // Return original color if not a palette color
        return color
    }
}

// MARK: - Enhanced Quick Stat Pill (Legacy wrapper for compatibility)
struct EnhancedQuickStatPill: View {
    let icon: String
    let value: String
    let label: String
    let gradient: LinearGradient
    let hasAppeared: Bool
    let animationIndex: Int
    
    var body: some View {
        StatCard(
            icon: icon,
            value: value,
            label: label,
            gradient: gradient
        )
        .modifier(InitialAnimationModifier(
            hasAppeared: hasAppeared,
            index: animationIndex,
            totalCount: 4
        ))
    }
}

// MARK: - Stat Card Row
struct StatCardRow: View {
    let stats: [(icon: String, value: String, label: String, gradient: LinearGradient)]
    let hasAppeared: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            ForEach(Array(stats.enumerated()), id: \.offset) { index, stat in
                StatCard(
                    icon: stat.icon,
                    value: stat.value,
                    label: stat.label,
                    gradient: stat.gradient
                )
                .modifier(InitialAnimationModifier(
                    hasAppeared: hasAppeared,
                    index: index + 2,
                    totalCount: stats.count + 2
                ))
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        // Individual stat cards
        HStack(spacing: 16) {
            StatCard.activeStreaks(5)
            StatCard.todayCompleted(3)
            StatCard.totalGames(12)
        }
        .padding()
        
        // Using StatCardRow with palette colors
        StatCardRow(
            stats: [
                ("flame.fill", "8", "Streak", StreakSyncColors.accentGradient(for: .light)),
                ("trophy.fill", "15", "Awards", LinearGradient(
                    colors: [PaletteColor.background.color, PaletteColor.textSecondary.color],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            ],
            hasAppeared: true
        )
        .padding()
    }
    .background(Color(.systemBackground))
}
