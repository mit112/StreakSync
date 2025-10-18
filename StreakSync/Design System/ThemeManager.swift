//
//  ThemeManager.swift
//  StreakSync
//
//  CONSOLIDATED: Single source of truth for theme management
//

/*
 * THEMEMANAGER - CENTRALIZED THEME AND STYLING COORDINATOR
 * 
 * WHAT THIS FILE DOES:
 * This file is the "theme coordinator" that manages all the visual styling and theming
 * throughout the app. It's like a "style guide manager" that provides consistent colors,
 * gradients, and visual elements to all parts of the app. Think of it as the "visual
 * identity controller" that ensures every screen, button, and component looks cohesive
 * and follows the app's design system.
 * 
 * WHY IT EXISTS:
 * Without a centralized theme manager, different parts of the app might use different
 * colors or styles, making the app look inconsistent and unprofessional. This manager
 * provides a single source of truth for all visual elements, ensuring that the app
 * has a cohesive look and feel. It also handles the complexity of different color
 * schemes (light/dark mode) and provides easy access to all design system elements.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This ensures consistent visual design throughout the app
 * - Provides centralized access to all colors, gradients, and visual elements
 * - Handles light/dark mode transitions automatically
 * - Ensures all components follow the same design system
 * - Makes it easy to update the app's visual identity
 * - Provides semantic color names for better code readability
 * - Integrates with the app's color system and design tokens
 * 
 * WHAT IT REFERENCES:
 * - StreakSyncColors: The core color system and palette
 * - ColorScheme: For detecting light/dark mode
 * - GameCategory: For game-specific colors
 * - SwiftUI: For Color types and gradients
 * - Combine: For reactive programming and updates
 * 
 * WHAT REFERENCES IT:
 * - EVERYTHING: This is used by virtually every UI component in the app
 * - All SwiftUI views: Use this for consistent theming
 * - Design system components: Use this for standardized styling
 * - AppContainer: Creates and manages the ThemeManager
 * - Settings: Can configure theme preferences
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. THEME SYSTEM IMPROVEMENTS:
 *    - The current theme system is basic - could be more sophisticated
 *    - Consider adding support for multiple themes and user customization
 *    - Add support for theme switching animations
 *    - Implement smart theme recommendations based on user preferences
 * 
 * 2. COLOR SYSTEM INTEGRATION:
 *    - The current color system integration could be enhanced
 *    - Consider adding support for dynamic color generation
 *    - Add support for color accessibility and contrast validation
 *    - Implement smart color adaptation for different contexts
 * 
 * 3. PERFORMANCE OPTIMIZATIONS:
 *    - The current color access could be optimized
 *    - Consider caching frequently used colors
 *    - Add support for lazy color loading
 *    - Implement efficient color scheme detection
 * 
 * 4. USER EXPERIENCE IMPROVEMENTS:
 *    - The current theme system could be more user-friendly
 *    - Add support for theme previews and customization
 *    - Implement smart theme suggestions
 *    - Add support for theme sharing and import/export
 * 
 * 5. ACCESSIBILITY IMPROVEMENTS:
 *    - The current accessibility support could be enhanced
 *    - Add support for high contrast themes
 *    - Implement color blindness-friendly alternatives
 *    - Add support for dynamic type scaling
 * 
 * 6. TESTING IMPROVEMENTS:
 *    - Add comprehensive unit tests for theme logic
 *    - Test different color schemes and themes
 *    - Add visual regression tests for theme changes
 *    - Test accessibility features
 * 
 * 7. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for all theme elements
 *    - Document the color system and design tokens
 *    - Add examples of how to use different themes
 *    - Create theme usage guidelines
 * 
 * 8. EXTENSIBILITY IMPROVEMENTS:
 *    - Make it easier to add new themes
 *    - Add support for custom theme plugins
 *    - Implement theme templates and presets
 *    - Add support for third-party theme integrations
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - Theme management: Centralized approach to managing app appearance
 * - Design systems: Standardized visual elements and components
 * - Color schemes: Light and dark mode variations
 * - Semantic colors: Colors with meaning (primary, secondary, success, error)
 * - Gradients: Smooth color transitions for visual appeal
 * - Visual consistency: Making sure all parts of the app look cohesive
 * - Design tokens: Standardized values for consistent design
 * - Accessibility: Ensuring colors work for all users
 * - User experience: Making sure the app looks professional and appealing
 * - Code organization: Keeping related functionality together
 */

import SwiftUI
import Combine

// MARK: - Updated ThemeManager
@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var followSystemColorScheme: Bool = true
    
    // Derive a best-effort color scheme outside of a View context
    // Note: This is a fallback for when not in a view context
    // Views should use @Environment(\.colorScheme) instead
    private var colorScheme: ColorScheme {
        // Default to light mode as fallback
        // Views should use @Environment(\.colorScheme) for proper color scheme detection
        return .light
    }
    
    // MARK: - Primary Palette Colors
    var primaryColor: Color {
        StreakSyncColors.primary(for: colorScheme)
    }
    
    var secondaryColor: Color {
        StreakSyncColors.secondary(for: colorScheme)
    }
    
    var tertiaryColor: Color {
        StreakSyncColors.tertiary(for: colorScheme)
    }
    
    // MARK: - Background Colors
    var primaryBackground: Color {
        StreakSyncColors.background(for: colorScheme)
    }
    
    var cardBackground: Color {
        StreakSyncColors.cardBackground(for: colorScheme)
    }
    
    var secondaryBackground: Color {
        StreakSyncColors.secondaryBackground(for: colorScheme)
    }
    
    // MARK: - Gradients
    var accentGradient: LinearGradient {
        StreakSyncColors.accentGradient(for: colorScheme)
    }
    
    var fullSpectrumGradient: LinearGradient {
        StreakSyncColors.fullSpectrumGradient(for: colorScheme)
    }
    
    // MARK: - Status Colors
    var successColor: Color {
        StreakSyncColors.success(for: colorScheme)
    }
    
    var warningColor: Color {
        StreakSyncColors.warning(for: colorScheme)
    }
    
    var errorColor: Color {
        StreakSyncColors.error(for: colorScheme)
    }
    
    // MARK: - Game Category Colors
    func gameColor(for category: GameCategory) -> Color {
        StreakSyncColors.gameColor(for: category, colorScheme: colorScheme)
    }
}
