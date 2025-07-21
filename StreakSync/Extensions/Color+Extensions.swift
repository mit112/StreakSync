//
//  Color+Extensions.swift
//  StreakSync
//
//  FINAL CLEAN VERSION: No duplicate extensions, system colors only
//

import SwiftUI

// MARK: - StreakSync Color Palette (System Colors Only)
extension Color {
    // MARK: - App-Specific Colors (Using System Colors)
    static var streakGreen: Color {
        Color(.systemGreen)
    }
    
    static var streakOrange: Color {
        Color(.systemOrange)
    }
    
    static var streakRed: Color {
        Color(.systemRed)
    }
    
    
    static var secondaryCardBackground: Color {
        Color(.secondarySystemBackground)
    }
    
    // MARK: - Semantic Colors (Auto-adapt to Dark Mode)
    static var adaptiveBackground: Color {
        Color(.systemBackground)
    }
    
    static var adaptiveSecondaryBackground: Color {
        Color(.secondarySystemBackground)
    }
    
    static var adaptiveTertiaryBackground: Color {
        Color(.tertiarySystemBackground)
    }
    
    static var adaptiveLabel: Color {
        Color(.label)
    }
    
    static var adaptiveSecondaryLabel: Color {
        Color(.secondaryLabel)
    }
    
    static var adaptiveTertiaryLabel: Color {
        Color(.tertiaryLabel)
    }
    
    // MARK: - Streak Status Colors
    static var activeStreakColor: Color {
        Color(.systemGreen)
    }
    
    static var inactiveStreakColor: Color {
        Color(.systemOrange)
    }
    
    static var brokenStreakColor: Color {
        Color(.systemRed)
    }
    
    // MARK: - Game Category Colors
    static var wordGameColor: Color {
        Color(.systemBlue)
    }
    
    static var mathGameColor: Color {
        Color(.systemPurple)
    }
    
    static var musicGameColor: Color {
        Color(.systemPink)
    }
    
    static var geographyGameColor: Color {
        Color(.systemTeal)
    }
    
    static var triviaGameColor: Color {
        Color(.systemIndigo)
    }
    
    static var puzzleGameColor: Color {
        Color(.systemCyan)
    }
    
    static var customGameColor: Color {
        Color(.systemGray)
    }
    
    // MARK: - Achievement Colors
    static var achievementUnlockedColor: Color {
        Color(.systemYellow)
    }
    
    static var achievementLockedColor: Color {
        Color(.systemGray2)
    }
    
    // MARK: - Success/Error Colors
    static var successColor: Color {
        Color(.systemGreen)
    }
    
    static var warningColor: Color {
        Color(.systemOrange)
    }
    
    static var errorColor: Color {
        Color(.systemRed)
    }
    
    static var infoColor: Color {
        Color(.systemBlue)
    }
}

// MARK: - Game Category Color Mapping
extension GameCategory {
    var color: Color {
        switch self {
        case .word: return .wordGameColor
        case .math: return .mathGameColor
        case .music: return .musicGameColor
        case .geography: return .geographyGameColor
        case .trivia: return .triviaGameColor
        case .puzzle: return .puzzleGameColor
        case .custom: return .customGameColor
        }
    }
}

// MARK: - CodableColor SwiftUI Integration


extension CodableColor {
    var color: Color {
        Color(uiColor: self.uiColor)
    }
    
    // Dark mode aware color creation
    static func adaptive(light: UIColor, dark: UIColor) -> CodableColor {
        let dynamicColor = UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return dark
            case .light, .unspecified:
                return light
            @unknown default:
                return light
            }
        }
        return CodableColor(dynamicColor)
    }
}

// MARK: - Color Accessibility Helpers
extension Color {
    /// Returns a contrasting color suitable for text on this background
    var contrastingTextColor: Color {
        // This is a simplified implementation
        // In production, you'd calculate the actual luminance
        return self == .primary ? .adaptiveLabel : .adaptiveBackground
    }
    
    /// Returns true if this color provides sufficient contrast for accessibility
    func hasAccessibleContrast(with other: Color) -> Bool {
        // Simplified check - in production, implement WCAG contrast ratio calculation
        return self != other
    }
}

// MARK: - Gradient Definitions
extension Color {
    static var streakGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [.streakOrange, .streakRed]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var achievementGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [.achievementUnlockedColor, .successColor]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    static var cardGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [.adaptiveBackground, .adaptiveSecondaryBackground]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Color Scheme Support
extension ColorScheme {
    var isDark: Bool {
        self == .dark
    }
    
    var isLight: Bool {
        self == .light
    }
}

// MARK: - Environment Color Helpers
struct AdaptiveColorKey: EnvironmentKey {
    static let defaultValue: ColorScheme = .light
}

extension EnvironmentValues {
    var adaptiveColorScheme: ColorScheme {
        get { self[AdaptiveColorKey.self] }
        set { self[AdaptiveColorKey.self] = newValue }
    }
}

// MARK: - Preview Helpers
#if DEBUG
extension Color {
    static var previewBackground: Color {
        Color(.systemBackground)
    }
    
    static var previewSecondaryBackground: Color {
        Color(.secondarySystemBackground)
    }
    
    static func random() -> Color {
        Color(
            red: Double.random(in: 0...1),
            green: Double.random(in: 0...1),
            blue: Double.random(in: 0...1)
        )
    }
}
#endif
