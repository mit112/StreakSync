//
//  GradientSystem.swift
//  StreakSync
//
//  Created by MiT on 7/23/25.
//

// DesignSystem/Colors/GradientSystem.swift
import SwiftUI

/// Gradient system for the new design
public struct GradientSystem {
    
    // MARK: - Game Gradients
    struct GameGradients {
        static func gradient(for gameName: String, colorScheme: ColorScheme) -> LinearGradient {
            let colors = gameColors(for: gameName, colorScheme: colorScheme)
            return LinearGradient(
                colors: colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        
        internal static func gameColors(for gameName: String, colorScheme: ColorScheme) -> [Color] {
            switch gameName.lowercased() {
            case "wordle":
                return colorScheme == .dark ?
                    [Color(hex: "2C4E2A"), Color(hex: "538D4E"), Color(hex: "1F3A1C"), Color(hex: "3D5C3A")] :
                    [Color(hex: "6AAA64"), Color(hex: "C9DC87"), Color(hex: "E3F2E1"), Color(hex: "F7DA21")]
                
            case "nerdle":
                return colorScheme == .dark ?
                    [Color(hex: "4A3C6B"), Color(hex: "6B5B95"), Color(hex: "8B7AA8"), Color(hex: "D8A7CA")] :
                    [Color(hex: "B19CD9"), Color(hex: "DCC9E8"), Color(hex: "F0E6F6"), Color(hex: "FFB6C1")]
                
            case "quordle":
                return colorScheme == .dark ?
                    [Color(hex: "1E3A8A"), Color(hex: "2563EB"), Color(hex: "1E40AF"), Color(hex: "3730A3")] :
                    [Color(hex: "3B82F6"), Color(hex: "93C5FD"), Color(hex: "DBEAFE"), Color(hex: "EFF6FF")]
                
            case "heardle":
                return colorScheme == .dark ?
                    [Color(hex: "831843"), Color(hex: "DB2777"), Color(hex: "BE185D"), Color(hex: "9D174D")] :
                    [Color(hex: "EC4899"), Color(hex: "F9A8D4"), Color(hex: "FCE7F3"), Color(hex: "FDF2F8")]
                
            default:
                return colorScheme == .dark ?
                    [Color.gray, Color.gray.opacity(0.7)] :
                    [Color.blue, Color.blue.opacity(0.3)]
            }
        }
    }
    
    // MARK: - System Gradients
    struct System {
        static let cardGradient = LinearGradient(
            colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let glassOverlay = LinearGradient(
            colors: [Color.white.opacity(0.1), Color.clear],
            startPoint: .top,
            endPoint: .bottom
        )
        
        static func adaptiveBackground(colorScheme: ColorScheme) -> RadialGradient {
            RadialGradient(
                colors: colorScheme == .dark ?
                    [Color(hex: "0A0F14"), Color(hex: "1A1F2E")] :
                    [Color(hex: "FAFAF9"), Color(hex: "F0F0EF")],
                center: .center,
                startRadius: 0,
                endRadius: 500
            )
        }
    }
}

// MARK: - Color Extension for Hex
//extension Color {
//    init(hex: String) {
//        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
//        var int: UInt64 = 0
//        Scanner(string: hex).scanHexInt64(&int)
//        let a, r, g, b: UInt64
//        switch hex.count {
//        case 3: // RGB (12-bit)
//            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
//        case 6: // RGB (24-bit)
//            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
//        case 8: // ARGB (32-bit)
//            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
//        default:
//            (a, r, g, b) = (255, 0, 0, 0)
//        }
//        
//        self.init(
//            .sRGB,
//            red: Double(r) / 255,
//            green: Double(g) / 255,
//            blue:  Double(b) / 255,
//            opacity: Double(a) / 255
//        )
//    }
//}
