//
//  AccessibilityHelpers.swift
//  StreakSync
//
//  Accessibility utility functions
//

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
