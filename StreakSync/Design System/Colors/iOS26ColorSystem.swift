//
//  iOS26ColorSystem.swift
//  StreakSync
//
//  FIXED: Correct syntax for system colors in SwiftUI
//

import SwiftUI

// MARK: - iOS 26 Semantic Color System
struct iOS26Colors {
    
    // MARK: - Background Colors (System)
    static var primaryBackground: Color {
        Color(.systemBackground)
    }
    
    static var secondaryBackground: Color {
        Color(.secondarySystemBackground)
    }
    
    static var tertiaryBackground: Color {
        Color(.tertiarySystemBackground)
    }
    
    static var groupedBackground: Color {
        Color(.systemGroupedBackground)
    }
    
    static var secondaryGroupedBackground: Color {
        Color(.secondarySystemGroupedBackground)
    }
    
    // MARK: - Fill Colors (For surfaces)
    static var primaryFill: Color {
        Color(.systemFill)
    }
    
    static var secondaryFill: Color {
        Color(.secondarySystemFill)
    }
    
    static var tertiaryFill: Color {
        Color(.tertiarySystemFill)
    }
    
    static var quaternaryFill: Color {
        Color(.quaternarySystemFill)
    }
    
    // MARK: - Label Colors (Text)
    static var primaryLabel: Color {
        Color(.label)
    }
    
    static var secondaryLabel: Color {
        Color(.secondaryLabel)
    }
    
    static var tertiaryLabel: Color {
        Color(.tertiaryLabel)
    }
    
    static var quaternaryLabel: Color {
        Color(.quaternaryLabel)
    }
    
    // MARK: - Separator & Borders
    static var separator: Color {
        Color(.separator)
    }
    
    static var opaqueSeparator: Color {
        Color(.opaqueSeparator)
    }
    
    // MARK: - Semantic Colors (FIXED SYNTAX)
    static var accent: Color {
        Color.accentColor // This one doesn't need UIColor
    }
    
    static var success: Color {
        Color(.systemGreen)
    }
    
    static var warning: Color {
        Color(.systemOrange)
    }
    
    static var error: Color {
        Color(.systemRed)
    }
    
    static var info: Color {
        Color(.systemBlue)
    }
    
    // MARK: - System Colors (FIXED)
    static var systemBlue: Color {
        Color(.systemBlue)
    }
    
    static var systemPurple: Color {
        Color(.systemPurple)
    }
    
    static var systemPink: Color {
        Color(.systemPink)
    }
    
    static var systemTeal: Color {
        Color(.systemTeal)
    }
    
    static var systemIndigo: Color {
        Color(.systemIndigo)
    }
    
    static var systemCyan: Color {
        Color(.systemCyan)
    }
    
    static var systemGray: Color {
        Color(.systemGray)
    }
    
    static var systemBrown: Color {
        Color(.systemBrown)
    }
    
    static var systemMint: Color {
        Color(.systemMint)
    }
    
    // MARK: - Game Category Colors
    static func gameColor(for category: GameCategory) -> Color {
        switch category {
        case .word:
            return Color(.systemBlue)
        case .math:
            return Color(.systemPurple)
        case .music:
            return Color(.systemPink)
        case .geography:
            return Color(.systemTeal)
        case .trivia:
            return Color(.systemIndigo)
        case .puzzle:
            return Color(.systemCyan)
        case .custom:
            return Color(.systemGray)
        }
    }
    
    // MARK: - Streak Status Colors
    static var activeStreak: Color {
        Color(.systemGreen)
    }
    
    static var inactiveStreak: Color {
        Color(.systemOrange)
    }
    
    static var brokenStreak: Color {
        Color(.systemRed)
    }
    
    static var pendingStreak: Color {
        Color(.systemYellow)
    }
}
