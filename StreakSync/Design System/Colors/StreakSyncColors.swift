//
//  PaletteColor.swift
//  StreakSync
//
//  Decorative gradient colors used by stat cards and dashboard elements.
//  NOTE: These are NOT structural colors — all card/background/border colors
//  should use semantic system colors (Color(.systemGroupedBackground), etc.)
//

import SwiftUI

// MARK: - Decorative Palette Colors
enum PaletteColor: String, CaseIterable {
    case primary = "58CC02"       // Green - used in stat gradients
    case secondary = "FF9600"     // Warm orange - stat gradients
    case background = "FFFFFF"
    case cardBackground = "F2F2F7"
    case textPrimary = "3C3C3C"
    case textSecondary = "8E8E93"

    var color: Color {
        Color(hex: rawValue)
    }

    var darkVariant: Color {
        switch self {
        case .primary:       return Color(hex: "4CAF50")
        case .secondary:     return Color(hex: "FFB74D")
        case .background:    return Color(hex: "000000")
        case .cardBackground: return Color(hex: "1A1A1A")
        case .textPrimary:   return Color(hex: "FFFFFF")
        case .textSecondary: return Color(hex: "8E8E93")
        }
    }
}
