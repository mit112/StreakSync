//
//  UIConstants.swift
//  StreakSync
//
//  Simplified UI constants for minimalist HIG-focused design
//

/*
 * UICONSTANTS - DESIGN SYSTEM FOUNDATION AND VISUAL CONSISTENCY
 * 
 * WHAT THIS FILE DOES:
 * This file provides the foundational design system constants that ensure visual
 * consistency throughout the app. It's like a "design system rulebook" that
 * defines spacing, typography, animations, and visual elements in a standardized
 * way. Think of it as the "visual foundation" that makes the app look cohesive
 * and professional by providing consistent spacing, colors, animations, and
 * typography across all components and screens.
 * 
 * WHY IT EXISTS:
 * Maintaining visual consistency across a large app requires standardized design
 * tokens and constants. Instead of hardcoding values throughout the codebase,
 * this file provides a centralized system of design constants that ensures
 * consistency, makes updates easier, and follows Apple's Human Interface
 * Guidelines. It creates a cohesive visual language that users can rely on.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This provides the visual foundation for the entire app
 * - Ensures consistent spacing, typography, and visual elements
 * - Follows Apple's Human Interface Guidelines for native iOS feel
 * - Makes design updates easier by centralizing constants
 * - Provides a cohesive visual language throughout the app
 * - Supports accessibility with proper spacing and typography
 * - Creates a professional, polished appearance
 * 
 * WHAT IT REFERENCES:
 * - SwiftUI: For UI components and styling
 * - Font: For typography system and dynamic type support
 * - Color: For color system and theming
 * - Animation: For consistent animation timing and easing
 * - CGFloat: For precise spacing and sizing values
 * 
 * WHAT REFERENCES IT:
 * - ALL UI COMPONENTS: Use these constants for consistent styling
 * - Design system components: Use these for standardized appearance
 * - Feature views: Use these for consistent layout and spacing
 * - Custom components: Use these for cohesive visual design
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. DESIGN SYSTEM IMPROVEMENTS:
 *    - The current system is good but could be more comprehensive
 *    - Consider adding more design tokens and variations
 *    - Add support for different themes and contexts
 *    - Implement smart design token selection
 * 
 * 2. ACCESSIBILITY IMPROVEMENTS:
 *    - The current accessibility support could be enhanced
 *    - Add support for accessibility-enhanced spacing and typography
 *    - Implement smart accessibility adaptations
 *    - Add support for different accessibility needs
 * 
 * 3. THEMING IMPROVEMENTS:
 *    - The current theming could be more sophisticated
 *    - Add support for multiple themes and variations
 *    - Implement smart theme selection
 *    - Add support for user customization
 * 
 * 4. PERFORMANCE OPTIMIZATIONS:
 *    - The current implementation could be optimized
 *    - Consider implementing efficient constant management
 *    - Add support for constant caching and reuse
 *    - Implement smart constant management
 * 
 * 5. TESTING IMPROVEMENTS:
 *    - Add comprehensive testing for design constants
 *    - Test different design scenarios and configurations
 *    - Add visual regression testing
 *    - Test accessibility features
 * 
 * 6. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for design constants
 *    - Document the different constants and usage patterns
 *    - Add examples of how to use different constants
 *    - Create design constant usage guidelines
 * 
 * 7. EXTENSIBILITY IMPROVEMENTS:
 *    - Make it easier to add new design constants
 *    - Add support for custom design configurations
 *    - Implement design constant plugins
 *    - Add support for third-party design integrations
 * 
 * 8. MONITORING AND OBSERVABILITY:
 *    - Add detailed logging for design constant usage
 *    - Implement metrics for design consistency
 *    - Add support for design debugging
 *    - Monitor design performance and reliability
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - Design systems: Standardized approaches to creating consistent visual design
 * - Design tokens: Reusable values for spacing, colors, typography, and other design elements
 * - Visual consistency: Making sure all parts of the app look cohesive
 * - Human Interface Guidelines: Apple's design principles for iOS apps
 * - Typography: The art and technique of arranging text for readability and appeal
 * - Spacing systems: Organized approaches to creating consistent layouts
 * - Animation timing: Creating smooth, natural-feeling animations
 * - Accessibility: Making sure design works for users with different needs
 * - Code organization: Keeping related functionality together
 * - Maintainability: Making code easy to update and modify
 */

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
        // Fallback for when not in view context
        // Views should use @Environment(\.horizontalSizeClass) for proper size detection
        return false
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
