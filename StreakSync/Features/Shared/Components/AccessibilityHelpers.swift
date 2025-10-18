//
//  AccessibilityHelpers.swift
//  StreakSync
//
//  Accessibility utility functions
//

/*
 * ACCESSIBILITYHELPERS - UTILITY FUNCTIONS FOR ACCESSIBILITY AND INCLUSIVE DESIGN
 * 
 * WHAT THIS FILE DOES:
 * This file provides utility functions and extensions that make it easier to add
 * accessibility features throughout the app. It's like an "accessibility helper
 * library" that provides common accessibility patterns and utilities that can be
 * used across different components. Think of it as the "accessibility toolkit"
 * that simplifies the process of making the app accessible and inclusive for
 * all users, regardless of their abilities or how they interact with their device.
 * 
 * WHY IT EXISTS:
 * Adding accessibility features can be repetitive and complex. This file provides
 * reusable utilities and extensions that make it easier to add accessibility
 * features consistently throughout the app. It reduces code duplication and
 * ensures that accessibility features are implemented correctly and consistently.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This simplifies accessibility implementation throughout the app
 * - Provides reusable accessibility utilities and extensions
 * - Ensures consistent accessibility implementation
 * - Reduces code duplication for accessibility features
 * - Makes it easier to add accessibility to new components
 * - Supports dynamic type and reduced motion preferences
 * - Provides proper VoiceOver announcements and navigation
 * 
 * WHAT IT REFERENCES:
 * - SwiftUI: For UI components and accessibility features
 * - UIAccessibility: For accessibility announcements and settings
 * - UIFontMetrics: For dynamic type support
 * - TieredAchievement: For achievement-specific accessibility
 * - AchievementTier: For tier-specific accessibility
 * - ViewModifier: For creating reusable accessibility enhancements
 * 
 * WHAT REFERENCES IT:
 * - All UI components: Use these utilities for accessibility
 * - Achievement views: Use these for accessible achievement information
 * - Game components: Use these for accessible game information
 * - Various feature views: Use these for consistent accessibility
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. ACCESSIBILITY UTILITY IMPROVEMENTS:
 *    - The current utilities are good but could be more comprehensive
 *    - Consider adding more accessibility utilities and patterns
 *    - Add support for more accessibility features
 *    - Implement smart accessibility recommendations
 * 
 * 2. USER EXPERIENCE IMPROVEMENTS:
 *    - The current accessibility utilities could be more user-friendly
 *    - Add support for accessibility customization and preferences
 *    - Implement smart accessibility recommendations
 *    - Add support for accessibility tutorials and guidance
 * 
 * 3. TESTING IMPROVEMENTS:
 *    - Add comprehensive testing for accessibility utilities
 *    - Test with real assistive technologies
 *    - Add automated accessibility testing
 *    - Test with users who have different abilities
 * 
 * 4. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for accessibility utilities
 *    - Document the different utilities and usage patterns
 *    - Add examples of how to use different utilities
 *    - Create accessibility utility usage guidelines
 * 
 * 5. COMPLIANCE IMPROVEMENTS:
 *    - Ensure compliance with accessibility guidelines
 *    - Add support for different accessibility standards
 *    - Implement accessibility auditing
 *    - Add accessibility monitoring and reporting
 * 
 * 6. PERFORMANCE OPTIMIZATIONS:
 *    - The current implementation could be optimized
 *    - Consider implementing efficient accessibility utilities
 *    - Add support for accessibility caching and reuse
 *    - Implement smart accessibility management
 * 
 * 7. EXTENSIBILITY IMPROVEMENTS:
 *    - Make it easier to add new accessibility utilities
 *    - Add support for custom accessibility configurations
 *    - Implement accessibility plugins
 *    - Add support for third-party accessibility integrations
 * 
 * 8. MONITORING AND OBSERVABILITY:
 *    - Add detailed logging for accessibility utility usage
 *    - Implement metrics for accessibility effectiveness
 *    - Add support for accessibility debugging
 *    - Monitor accessibility performance and reliability
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - Accessibility utilities: Helper functions that make accessibility easier to implement
 * - Inclusive design: Designing for all users, regardless of their abilities
 * - VoiceOver: Apple's screen reader for users with visual impairments
 * - Dynamic type: Supporting different text sizes for better readability
 * - Reduced motion: Respecting user preferences for motion and animations
 * - Accessibility announcements: Providing information to screen readers
 * - User experience: Making sure the app is usable and enjoyable for everyone
 * - Code organization: Keeping related functionality together
 * - Design systems: Standardized approaches to creating consistent experiences
 * - Utility functions: Reusable functions that simplify common tasks
 */

import SwiftUI

// MARK: - Accessibility Extensions
extension View {
    /// Announces achievement unlock to VoiceOver
    func announceAchievement(_ achievement: TieredAchievement, tier: AchievementTier) -> some View {
        self.onAppear {
            let message = NSLocalizedString(
                "voiceover.achievement_unlocked",
                comment: "Achievement unlocked announcement"
            )
            let announcement = String(format: message, "\(tier.displayName) \(achievement.displayName)")
            
            UIAccessibility.post(
                notification: .announcement,
                argument: announcement
            )
        }
    }
    
    /// Provides proper accessibility label for achievement progress
    func achievementAccessibilityLabel(_ achievement: TieredAchievement) -> some View {
        self.accessibilityLabel(
            "\(achievement.displayName). \(achievement.description). Progress: \(achievement.progressDescription)"
        )
    }
    
    /// Adjusts animations based on accessibility settings
    func accessibilityAdjustedAnimation<V>(_ animation: Animation?, value: V) -> some View where V: Equatable {
        self.animation(
            UIAccessibility.isReduceMotionEnabled ? .easeInOut(duration: 0.2) : animation,
            value: value
        )
    }
}

// MARK: - Dynamic Type Support
struct ScaledFont: ViewModifier {
    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design
    
    func body(content: Content) -> some View {
        content.font(
            Font.system(size: UIFontMetrics.default.scaledValue(for: size), weight: weight, design: design)
        )
    }
}

extension View {
    func scaledFont(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        modifier(ScaledFont(size: size, weight: weight, design: design))
    }
}
