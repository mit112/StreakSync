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

// MARK: - Animation System (Native iOS feel)
enum AnimationDuration {
    /// 0.25s - iOS standard quick animation
    static let standard: Double = 0.25
    
    /// 0.35s - iOS standard smooth animation
    static let smooth: Double = 0.35
}

// MARK: - Animation Presets (Simplified)
extension Animation {
    /// Standard iOS easing curve - quick and responsive
    static var standard: Animation {
        .easeInOut(duration: AnimationDuration.standard)
    }
    
    /// Smooth iOS easing curve - for larger transitions
    static var smooth: Animation {
        .easeInOut(duration: AnimationDuration.smooth)
    }
}

// MARK: - Shadow System (Minimal - only 2 options)
struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
    
    /// Subtle shadow for floating elements only
    static let subtle = ShadowStyle(
        color: .black.opacity(0.08),
        radius: 2,
        x: 0,
        y: 1
    )
    
    /// Elevated shadow for modals and sheets
    static let elevated = ShadowStyle(
        color: .black.opacity(0.15),
        radius: 8,
        x: 0,
        y: 4
    )
}

// MARK: - Typography Helpers
extension Font {
    /// Use Dynamic Type system fonts
    static var streakNumber: Font {
        .system(.largeTitle, design: .rounded).weight(.bold)
    }
    
    static var sectionHeader: Font {
        .headline
    }
    
    static var cardTitle: Font {
        .subheadline.weight(.medium)
    }
    
    static var cardSubtitle: Font {
        .caption
    }
}

// MARK: - Color Helpers
extension Color {
    /// System colors only - no custom colors
    static var streakActive: Color {
        .primary
    }
    
    static var streakInactive: Color {
        .secondary
    }
    

    static var groupedBackground: Color {
        Color(.systemGroupedBackground)
    }
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


// MARK: - Device Size Helpers
struct DeviceSize {
    static var isSmallDevice: Bool {
        UIScreen.main.bounds.width < 375
    }
    
    static var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
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
    
    /// Add standard accessibility for text content
    func accessibleText(label: String) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isStaticText)
    }
}
