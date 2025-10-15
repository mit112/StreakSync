//
//  AccessibilityEnhancements.swift
//  StreakSync
//
//  Enhanced accessibility features and dynamic type support
//

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
