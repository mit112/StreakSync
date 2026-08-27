//
//  UIConstants.swift
//  StreakSync
//
//  Simplified UI constants for minimalist HIG-focused design
//

import SwiftUI

// MARK: - Spacing System (Simplified)
enum Spacing {
    /// 4pt - Minimal spacing for inline elements
    static let xs: CGFloat = 4
    
    /// 8pt - Small spacing between related elements
    static let sm: CGFloat = 8
    
    /// 12pt - Medium spacing for grouped content
    static let md: CGFloat = 12
    
    /// 16pt - Default spacing for most layouts
    static let lg: CGFloat = 16
    
    /// 20pt - Large spacing for section separation
    static let xl: CGFloat = 20
    
    /// 24pt - Extra large spacing for major sections
    static let xxl: CGFloat = 24

    /// 32pt - Major section separation / large vertical rhythm
    static let xxxl: CGFloat = 32

    /// 40pt - Hero and empty-state vertical breathing room
    static let huge: CGFloat = 40
}

// MARK: - Icon Size System
/// Base glyph/container sizes. Pair with `@ScaledMetric` at the call site so
/// icons scale alongside their adjacent text under Dynamic Type (UI audit §6 Stage 1).
enum IconSize {
    /// 20pt - inline glyph next to body text
    static let sm: CGFloat = 20

    /// 24pt - standard control glyph
    static let md: CGFloat = 24

    /// 32pt - emphasized glyph / small avatar
    static let lg: CGFloat = 32

    /// 48pt - card icon container
    static let xl: CGFloat = 48

    /// 56pt - grid card icon container
    static let xxl: CGFloat = 56
}

// MARK: - Corner Radius System (3 tokens: control / card / sheet)
enum CornerRadius {
    /// 12pt - buttons, chips, inputs, small pills
    static let control: CGFloat = 12

    /// 16pt - ALL content/stat/game/achievement cards
    static let card: CGFloat = 16

    /// 20pt - bottom sheets + large hero surfaces
    static let sheet: CGFloat = 20
}

// MARK: - Layout Constants
enum Layout {
    /// Minimum touch target size per HIG
    static let minTouchTarget: CGFloat = 44
    
    /// Standard content padding
    static let contentPadding: CGFloat = 16
    
    /// Maximum readable width for text
    static let maxReadableWidth: CGFloat = 600
}

// MARK: - Accessibility Helpers
extension View {
    /// Add standard accessibility traits for buttons
    func accessibleButton(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
    }

    /// Enforces the HIG 44pt minimum hit area (WCAG 2.5.8) without growing the
    /// visible glyph. Apply to icon-only controls (DESIGN_AUDIT §4.12).
    func minTapTarget() -> some View {
        frame(minWidth: Layout.minTouchTarget, minHeight: Layout.minTouchTarget)
            .contentShape(Rectangle())
    }
}
