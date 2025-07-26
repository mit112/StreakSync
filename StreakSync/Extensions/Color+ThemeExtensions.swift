//
//  Color+ThemeExtensions.swift
//  StreakSync
//
//  Theme-aware color extensions that work with ThemeManager
//

import SwiftUI

// MARK: - Hex Color Support (Keep from ColorTheme.swift)
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        let scanner = Scanner(string: hex)
        if hex.hasPrefix("#") {
            scanner.currentIndex = hex.index(after: hex.startIndex)
        }

        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)

        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Theme-Based Semantic Colors
extension Color {
    // MARK: - Primary Colors (Direct access without ThemeManager)
    static var themeBackground: Color {
        Color(.systemBackground)
    }
    
    static var themeAccent: Color {
        Color(.systemBlue)
    }
    
    static var themeCard: Color {
        Color(.secondarySystemBackground)
    }
    
    // MARK: - Streak Status Colors (System colors)
    static var activeStreakColor: Color {
        Color(.systemGreen)
    }
    
    static var inactiveStreakColor: Color {
        Color(.systemOrange)
    }
    
    static var brokenStreakColor: Color {
        Color(.systemRed)
    }
    
    // MARK: - Game Category Colors (Environment-aware)
    static func gameColor(for category: GameCategory, isDarkMode: Bool = false) -> Color {
        switch category {
        case .word:
            return isDarkMode ? Color(hex: "60A5FA") : Color(hex: "2563EB")
        case .math:
            return isDarkMode ? Color(hex: "C084FC") : Color(hex: "9333EA")
        case .music:
            return isDarkMode ? Color(hex: "F472B6") : Color(hex: "EC4899")
        case .geography:
            return isDarkMode ? Color(hex: "5EEAD4") : Color(hex: "14B8A6")
        case .trivia:
            return isDarkMode ? Color(hex: "818CF8") : Color(hex: "6366F1")
        case .puzzle:
            return isDarkMode ? Color(hex: "67E8F9") : Color(hex: "06B6D4")
        case .custom:
            return isDarkMode ? Color(hex: "9CA3AF") : Color(hex: "6B7280")
        }
    }
    
    // MARK: - Semantic Success/Error Colors
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

// MARK: - Gradient Extensions
extension LinearGradient {
    // Create theme gradients dynamically in views that have access to ThemeManager
    static func themeGradient(colors: [Color]) -> LinearGradient {
        LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static func accentGradient(colors: [Color]) -> LinearGradient {
        LinearGradient(
            colors: colors,
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    static func gameGradient(for category: GameCategory, isDarkMode: Bool = false) -> LinearGradient {
        let baseColor = Color.gameColor(for: category, isDarkMode: isDarkMode)
        return LinearGradient(
            colors: [
                baseColor.opacity(0.8),
                baseColor
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
