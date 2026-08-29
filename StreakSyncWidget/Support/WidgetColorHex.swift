//
//  WidgetColorHex.swift
//  StreakSyncWidget
//
//  Conversion between "#RRGGBB" strings and SwiftUI/UIKit colors
//

import SwiftUI
import UIKit

/// `WidgetGameEntry.colorHex` arrives pre-flattened precisely so the widget never
/// has to import the app's `ColorTheme` hex helpers. This is that decoder, plus
/// the matching encoder used to build sample data from the catalog.
enum WidgetColorHex {
    /// Parses "#RRGGBB" (with or without the leading hash).
    /// Returns nil rather than a guess, so callers pick their own fallback.
    static func color(_ hex: String) -> Color? {
        var trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("#") {
            trimmed.removeFirst()
        }
        guard trimmed.count == 6, let value = UInt32(trimmed, radix: 16) else {
            return nil
        }
        return Color(
            red: Double((value >> 16) & 0xFF) / 255.0,
            green: Double((value >> 8) & 0xFF) / 255.0,
            blue: Double(value & 0xFF) / 255.0
        )
    }

    /// Flattens a catalog color into the same shape the snapshot carries.
    /// Only used for sample/placeholder content — live rows carry their own hex.
    static func hexString(from codableColor: CodableColor) -> String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard codableColor.uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return "#FF9F0A"
        }
        return String(
            format: "#%02X%02X%02X",
            channel(red),
            channel(green),
            channel(blue)
        )
    }

    /// Display P3 colors can report components outside 0...1 in extended sRGB,
    /// so clamp before narrowing to a byte.
    private static func channel(_ component: CGFloat) -> Int {
        Int((min(max(component, 0), 1) * 255).rounded())
    }
}
