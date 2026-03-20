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
}

// MARK: - Corner Radius System (Simplified to 2 options)
enum CornerRadius {
    /// 10pt - Standard radius for buttons
    static let button: CGFloat = 10
    
    /// 12pt - Standard radius for cards and containers
    static let card: CGFloat = 12
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
}
