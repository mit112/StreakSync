//
//  Typography.swift
//  StreakSync
//
//  Semantic type scale — one role pins a text style + weight + color so
//  hierarchy is a single decision, not three per call site (UI audit §6 Stage 1).
//

import SwiftUI

// MARK: - Typography Roles
/// The app's type ramp, top to bottom. Each role binds a Dynamic Type text
/// style, a weight, and a hierarchical color. Use `.typography(_:)` instead of
/// hand-pairing `.font()` + `.fontWeight()` + `.foregroundStyle()` at each site.
enum Typography {
    /// Screen hero — the single largest number or title on a screen.
    case display
    /// Screen and section titles.
    case title
    /// Card titles and group headers.
    case heading
    /// Default reading text — the baseline everything else departs from.
    case body
    /// Supporting labels beside content.
    case label
    /// Metadata, timestamps, and secondary annotations.
    case caption

    /// Text style + weight for the role. Weight is folded into the font so a
    /// single `.font()` call carries both.
    var font: Font {
        switch self {
        case .display: return .largeTitle.weight(.bold)
        case .title: return .title2.weight(.bold)
        case .heading: return .headline
        case .body: return .body
        case .label: return .subheadline.weight(.medium)
        case .caption: return .caption
        }
    }

    /// Hierarchical foreground color for the role.
    var foregroundStyle: HierarchicalShapeStyle {
        switch self {
        case .display, .title, .heading, .body: return .primary
        case .label, .caption: return .secondary
        }
    }
}

// MARK: - View Adoption
extension View {
    /// Apply a semantic typography role (font + weight + color) in one call.
    /// Chain `.foregroundStyle()` afterward to override the role's default color.
    func typography(_ role: Typography) -> some View {
        self
            .font(role.font)
            .foregroundStyle(role.foregroundStyle)
    }
}
