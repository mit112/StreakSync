//
//  ColorTheme.swift
//  StreakSync
//
//  Unified theme system with color definitions and extensions
//

import SwiftUI

// MARK: - Color Theme Definitions
enum ColorTheme: String, CaseIterable {
    case indigo = "Indigo Dreams"      // Current refined theme
    case aurora = "Aurora"              // Northern lights inspired
    case sunset = "Sunset"              // Warm sunset colors
    case ocean = "Ocean Depths"         // Deep sea blues
    case forest = "Forest"              // Natural greens
    case monochrome = "Monochrome"      // Elegant grayscale
    
    var colors: ThemeColors {
        switch self {
        case .indigo:
            return ThemeColors(
                backgroundLight: "F8FAFC",
                backgroundDark: "0A0E14",
                gradientLight: ["E0E7FF", "C7D2FE"],
                gradientDark: ["1E293B", "0F172A"],
                accentLight: ["4338CA", "6366F1"],
                accentDark: ["818CF8", "6366F1"],
                statOrange: ["FB923C", "F97316"],
                statGreen: ["34D399", "10B981"]
            )
            
        case .aurora:
            return ThemeColors(
                backgroundLight: "F8FAFC",
                backgroundDark: "0C0E1A",
                gradientLight: ["E0F2FE", "BAE6FD"],
                gradientDark: ["1E3A5F", "0F2942"],
                accentLight: ["0EA5E9", "06B6D4"],
                accentDark: ["38BDF8", "22D3EE"],
                statOrange: ["F59E0B", "F97316"],
                statGreen: ["10B981", "059669"]
            )
            
        case .sunset:
            return ThemeColors(
                backgroundLight: "FFFBF5",
                backgroundDark: "1A0F0A",
                gradientLight: ["FEE2E2", "FECACA"],
                gradientDark: ["451A03", "78350F"],
                accentLight: ["DC2626", "F97316"],
                accentDark: ["F87171", "FB923C"],
                statOrange: ["F59E0B", "EA580C"],
                statGreen: ["84CC16", "65A30D"]
            )
            
        case .ocean:
            return ThemeColors(
                backgroundLight: "F0F9FF",
                backgroundDark: "0A1628",
                gradientLight: ["DBEAFE", "BFDBFE"],
                gradientDark: ["1E3A8A", "1E40AF"],
                accentLight: ["2563EB", "1D4ED8"],
                accentDark: ["60A5FA", "3B82F6"],
                statOrange: ["FB923C", "F97316"],
                statGreen: ["34D399", "10B981"]
            )
            
        case .forest:
            return ThemeColors(
                backgroundLight: "F0FDF4",
                backgroundDark: "0A1F0F",
                gradientLight: ["D1FAE5", "A7F3D0"],
                gradientDark: ["064E3B", "047857"],
                accentLight: ["059669", "047857"],
                accentDark: ["34D399", "10B981"],
                statOrange: ["F59E0B", "D97706"],
                statGreen: ["10B981", "059669"]
            )
            
        case .monochrome:
            return ThemeColors(
                backgroundLight: "FAFAFA",
                backgroundDark: "0A0A0A",
                gradientLight: ["E5E5E5", "D4D4D4"],
                gradientDark: ["262626", "171717"],
                accentLight: ["404040", "525252"],
                accentDark: ["A3A3A3", "D4D4D4"],
                statOrange: ["737373", "525252"],
                statGreen: ["525252", "404040"]
            )
        }
    }
}

// MARK: - Theme Colors Structure
struct ThemeColors {
    let backgroundLight: String
    let backgroundDark: String
    let gradientLight: [String]
    let gradientDark: [String]
    let accentLight: [String]
    let accentDark: [String]
    let statOrange: [String]
    let statGreen: [String]
}

// MARK: - Hex Color Support
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
    // MARK: - Primary Colors
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
        case .nytGames:
            return isDarkMode ? Color(hex: "F87171") : Color(hex: "DC2626")
        case .linkedinGames:
            return isDarkMode ? Color(hex: "60A5FA") : Color(hex: "0077B5")
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
    // Create theme gradients dynamically
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
