//
//  AccessibilityEnhancements.swift
//  StreakSync
//
//  Enhanced accessibility features and dynamic type support
//

/*
 * ACCESSIBILITYENHANCEMENTS - COMPREHENSIVE ACCESSIBILITY AND INCLUSIVE DESIGN
 * 
 * WHAT THIS FILE DOES:
 * This file provides comprehensive accessibility enhancements that make the app
 * usable and enjoyable for users with different abilities and needs. It's like
 * an "accessibility toolkit" that ensures the app works well with screen readers,
 * supports different text sizes, and provides clear navigation for all users.
 * Think of it as the "inclusive design system" that makes the app accessible
 * to everyone, regardless of their abilities or how they interact with their device.
 * 
 * WHY IT EXISTS:
 * Accessibility is not just a legal requirement - it's essential for creating
 * an inclusive app that works for everyone. This file provides the tools and
 * enhancements needed to make the app accessible to users with visual, motor,
 * or cognitive disabilities. It ensures the app is usable with assistive
 * technologies and provides a great experience for all users.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This ensures the app is accessible to all users
 * - Provides comprehensive accessibility support for different needs
 * - Supports dynamic type for users who need larger text
 * - Enhances VoiceOver navigation and descriptions
 * - Provides clear accessibility labels and hints
 * - Makes the app usable with assistive technologies
 * - Ensures compliance with accessibility guidelines
 * 
 * WHAT IT REFERENCES:
 * - SwiftUI: For UI components and accessibility features
 * - DynamicTypeSize: For supporting different text sizes
 * - AccessibilityFocusState: For managing focus in VoiceOver
 * - Game: For providing game-specific accessibility information
 * - GameStreak: For providing streak-specific accessibility information
 * - ViewModifier: For creating reusable accessibility enhancements
 * 
 * WHAT REFERENCES IT:
 * - All UI components: Use these enhancements for accessibility
 * - Game cards: Use these for accessible game information
 * - Buttons: Use these for accessible button interactions
 * - Forms: Use these for accessible form navigation
 * - Various feature views: Use these for consistent accessibility
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. ACCESSIBILITY ENHANCEMENTS:
 *    - The current accessibility support is good but could be more comprehensive
 *    - Consider adding more accessibility features and enhancements
 *    - Add support for more assistive technologies
 *    - Implement smart accessibility recommendations
 * 
 * 2. USER EXPERIENCE IMPROVEMENTS:
 *    - The current accessibility could be more user-friendly
 *    - Add support for accessibility customization and preferences
 *    - Implement smart accessibility recommendations
 *    - Add support for accessibility tutorials and guidance
 * 
 * 3. TESTING IMPROVEMENTS:
 *    - Add comprehensive accessibility testing
 *    - Test with real assistive technologies
 *    - Add automated accessibility testing
 *    - Test with users who have different abilities
 * 
 * 4. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for accessibility features
 *    - Document the different accessibility enhancements and usage patterns
 *    - Add examples of how to use different accessibility features
 *    - Create accessibility usage guidelines
 * 
 * 5. COMPLIANCE IMPROVEMENTS:
 *    - Ensure compliance with WCAG guidelines
 *    - Add support for different accessibility standards
 *    - Implement accessibility auditing
 *    - Add accessibility monitoring and reporting
 * 
 * 6. PERFORMANCE OPTIMIZATIONS:
 *    - The current implementation could be optimized
 *    - Consider implementing efficient accessibility rendering
 *    - Add support for accessibility caching and reuse
 *    - Implement smart accessibility management
 * 
 * 7. EXTENSIBILITY IMPROVEMENTS:
 *    - Make it easier to add new accessibility features
 *    - Add support for custom accessibility configurations
 *    - Implement accessibility plugins
 *    - Add support for third-party accessibility integrations
 * 
 * 8. MONITORING AND OBSERVABILITY:
 *    - Add detailed logging for accessibility usage
 *    - Implement metrics for accessibility effectiveness
 *    - Add support for accessibility debugging
 *    - Monitor accessibility performance and reliability
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - Accessibility: Making sure the app works for users with different abilities
 * - Inclusive design: Designing for all users, regardless of their abilities
 * - VoiceOver: Apple's screen reader for users with visual impairments
 * - Dynamic type: Supporting different text sizes for better readability
 * - Assistive technologies: Tools that help users with disabilities use devices
 * - Accessibility labels: Descriptions that help screen readers understand content
 * - Accessibility hints: Additional information about how to interact with elements
 * - Focus management: Ensuring users can navigate the app effectively
 * - User experience: Making sure the app is usable and enjoyable for everyone
 * - Design systems: Standardized approaches to creating consistent experiences
 */

import SwiftUI

// MARK: - Dynamic Type Support
struct DynamicTypeModifier: ViewModifier {
    let maxSize: DynamicTypeSize?
    
    init(maxSize: DynamicTypeSize? = nil) {
        self.maxSize = maxSize
    }
    
    func body(content: Content) -> some View {
        if let maxSize = maxSize {
            content
                .dynamicTypeSize(.small ... maxSize)
        } else {
            content
        }
    }
}

// MARK: - Accessibility Focus Management
struct AccessibilityFocusModifier: ViewModifier {
    @AccessibilityFocusState private var isFocused: Bool
    let shouldFocus: Bool
    
    init(shouldFocus: Bool) {
        self.shouldFocus = shouldFocus
    }
    
    func body(content: Content) -> some View {
        content
            .accessibilityFocused($isFocused)
            .onAppear {
                if shouldFocus {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isFocused = true
                    }
                }
            }
    }
}

// MARK: - Enhanced Button Accessibility
struct AccessibleButtonModifier: ViewModifier {
    let label: String
    let hint: String?
    let value: String?
    
    init(label: String, hint: String? = nil, value: String? = nil) {
        self.label = label
        self.hint = hint
        self.value = value
    }
    
    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Game Card Accessibility
struct GameCardAccessibilityModifier: ViewModifier {
    let game: Game
    let streak: GameStreak?
    
    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .combine)
            .accessibilityLabel(gameCardAccessibilityLabel)
            .accessibilityValue(gameCardAccessibilityValue)
            .accessibilityHint("Double tap to view game details")
            .accessibilityAddTraits(.isButton)
    }
    
    private var gameCardAccessibilityLabel: String {
        "\(game.displayName) game"
    }
    
    private var gameCardAccessibilityValue: String {
        guard let streak = streak else {
            return "No streak data"
        }
        
        var components: [String] = []
        
        if streak.currentStreak > 0 {
            components.append("Current streak: \(streak.currentStreak) days")
        }
        
        if let lastPlayed = streak.lastPlayedDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            components.append("Last played: \(formatter.localizedString(for: lastPlayed, relativeTo: Date()))")
        }
        
        if streak.completionRate > 0 {
            let percentage = Int(streak.completionRate * 100)
            components.append("Completion rate: \(percentage) percent")
        }
        
        return components.joined(separator: ", ")
    }
}

// MARK: - Achievement Accessibility
struct AchievementAccessibilityModifier: ViewModifier {
    let achievement: Achievement
    let tier: AchievementTier?
    let isUnlocked: Bool
    
    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .combine)
            .accessibilityLabel(achievementAccessibilityLabel)
            .accessibilityValue(achievementAccessibilityValue)
            .accessibilityHint(achievementAccessibilityHint)
    }
    
    private var achievementAccessibilityLabel: String {
        "\(achievement.title) achievement"
    }
    
    private var achievementAccessibilityValue: String {
        if isUnlocked {
            if let tier = tier {
                return "Unlocked at \(tier.displayName) level"
            } else {
                return "Unlocked"
            }
        } else {
            return "Locked"
        }
    }
    
    private var achievementAccessibilityHint: String {
        if isUnlocked {
            return "Achievement unlocked"
        } else {
            return "Keep playing to unlock this achievement"
        }
    }
}

// MARK: - Loading State Accessibility
struct LoadingStateAccessibilityModifier: ViewModifier {
    let isLoading: Bool
    let loadingMessage: String
    
    init(isLoading: Bool, loadingMessage: String = "Loading content") {
        self.isLoading = isLoading
        self.loadingMessage = loadingMessage
    }
    
    func body(content: Content) -> some View {
        content
            .accessibilityLabel(isLoading ? loadingMessage : "")
            .accessibilityAddTraits(isLoading ? .updatesFrequently : [])
    }
}

// MARK: - View Extensions
extension View {
    /// Apply dynamic type size limits
    func dynamicTypeSize(upTo maxSize: DynamicTypeSize) -> some View {
        modifier(DynamicTypeModifier(maxSize: maxSize))
    }
    
    /// Manage accessibility focus
    func accessibilityFocus(_ shouldFocus: Bool) -> some View {
        modifier(AccessibilityFocusModifier(shouldFocus: shouldFocus))
    }
    
    /// Enhanced button accessibility
    func accessibleButton(label: String, hint: String? = nil, value: String? = nil) -> some View {
        modifier(AccessibleButtonModifier(label: label, hint: hint, value: value))
    }
    
    /// Game card accessibility
    func gameCardAccessibility(game: Game, streak: GameStreak?) -> some View {
        modifier(GameCardAccessibilityModifier(game: game, streak: streak))
    }
    
    /// Achievement accessibility
    func achievementAccessibility(achievement: Achievement, tier: AchievementTier?, isUnlocked: Bool) -> some View {
        modifier(AchievementAccessibilityModifier(achievement: achievement, tier: tier, isUnlocked: isUnlocked))
    }
    
    /// Loading state accessibility
    func loadingStateAccessibility(isLoading: Bool, message: String = "Loading content") -> some View {
        modifier(LoadingStateAccessibilityModifier(isLoading: isLoading, loadingMessage: message))
    }
}

// MARK: - Accessibility Announcements
struct AccessibilityAnnouncer {
    static func announce(_ message: String) {
        DispatchQueue.main.async {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
    
    static func announceAchievementUnlocked(_ achievement: Achievement, tier: AchievementTier) {
        let message = "Achievement unlocked: \(achievement.title) at \(tier.displayName) level"
        announce(message)
    }
    
    static func announceStreakUpdated(_ game: Game, newStreak: Int) {
        let message = "\(game.displayName) streak updated to \(newStreak) days"
        announce(message)
    }
    
    static func announceDataRefreshed() {
        announce("Data refreshed successfully")
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        Button("Sample Button") { }
            .accessibleButton(label: "Sample Button", hint: "Tap to perform action")
        
        Text("Sample Text")
            .dynamicTypeSize(upTo: .accessibility3)
        
        Text("Loading...")
            .loadingStateAccessibility(isLoading: true, message: "Loading games")
    }
    .padding()
}
