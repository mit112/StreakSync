//
//  GlassEffect.swift
//  StreakSync
//
//  Created by MiT on 7/23/25.
//

// DesignSystem/Glass/GlassEffect.swift

/*
 * GLASSEFFECT - MODERN GLASSMORPHISM VISUAL DESIGN SYSTEM
 * 
 * WHAT THIS FILE DOES:
 * This file provides a modern glassmorphism effect that creates beautiful, translucent
 * UI elements with blur effects and subtle transparency. It's like a "glass window
 * maker" that transforms regular UI elements into elegant, modern glass-like surfaces.
 * Think of it as the "visual enhancement system" that makes the app look contemporary
 * and sophisticated with beautiful glass effects, shadows, and color overlays.
 * 
 * WHY IT EXISTS:
 * Modern apps use glassmorphism effects to create depth, hierarchy, and visual appeal.
 * This system provides a consistent way to apply glass effects throughout the app,
 * ensuring that all glass elements look cohesive and professional. It handles the
 * complexity of different color schemes, transparency levels, and visual effects
 * to create beautiful, modern UI elements.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This provides modern, sophisticated visual design throughout the app
 * - Creates beautiful glassmorphism effects for cards, overlays, and UI elements
 * - Supports different glass types (light, medium, heavy) for various use cases
 * - Handles light/dark mode transitions automatically
 * - Provides colored glass effects for game cards and themed elements
 * - Ensures consistent visual design across all glass elements
 * - Makes the app look modern and professional
 * 
 * WHAT IT REFERENCES:
 * - GlassConstants: Configuration for glass effect types and properties
 * - SwiftUI: For view modifiers and visual effects
 * - ColorScheme: For adapting to light/dark mode
 * - LinearGradient: For beautiful color transitions
 * - Material effects: For blur and transparency
 * - Shadow effects: For depth and visual hierarchy
 * 
 * WHAT REFERENCES IT:
 * - Game cards: Use this for beautiful glass effects
 * - Overlay views: Use this for modal and popup backgrounds
 * - Navigation elements: Use this for modern navigation bars
 * - Settings panels: Use this for elegant settings interfaces
 * - Various UI components: Use this for consistent glass styling
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. GLASS EFFECT IMPROVEMENTS:
 *    - The current effects are good but could be more sophisticated
 *    - Consider adding more glass types and variations
 *    - Add support for animated glass effects and transitions
 *    - Implement smart glass effect selection based on context
 * 
 * 2. PERFORMANCE OPTIMIZATIONS:
 *    - The current implementation could be optimized
 *    - Consider implementing efficient glass effect rendering
 *    - Add support for glass effect caching and reuse
 *    - Implement smart glass effect management
 * 
 * 3. ACCESSIBILITY IMPROVEMENTS:
 *    - The current accessibility support could be enhanced
 *    - Add support for reduced transparency preferences
 *    - Implement accessibility-enhanced glass effects
 *    - Add support for different accessibility needs
 * 
 * 4. USER EXPERIENCE IMPROVEMENTS:
 *    - The current glass system could be more user-friendly
 *    - Add support for glass effect customization
 *    - Implement smart glass effect recommendations
 *    - Add support for glass effect preferences
 * 
 * 5. TESTING IMPROVEMENTS:
 *    - Add comprehensive unit tests for glass effect logic
 *    - Test different glass types and configurations
 *    - Add visual regression tests for glass effects
 *    - Test accessibility features
 * 
 * 6. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for glass effect features
 *    - Document the different glass types and usage patterns
 *    - Add examples of how to use different glass effects
 *    - Create glass effect usage guidelines
 * 
 * 7. EXTENSIBILITY IMPROVEMENTS:
 *    - Make it easier to add new glass effect types
 *    - Add support for custom glass effect configurations
 *    - Implement glass effect plugins
 *    - Add support for third-party glass effect integrations
 * 
 * 8. VISUAL DESIGN IMPROVEMENTS:
 *    - The current visual design could be enhanced
 *    - Add support for more sophisticated color blending
 *    - Implement smart color adaptation for different contexts
 *    - Add support for dynamic glass effects
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - Glassmorphism: Modern design trend using glass-like effects
 * - View modifiers: Ways to add behavior and styling to SwiftUI views
 * - Visual effects: Techniques for creating beautiful and engaging interfaces
 * - Color schemes: Light and dark mode variations
 * - Transparency: Making UI elements see-through for visual appeal
 * - Blur effects: Making backgrounds blurry for depth and focus
 * - Shadows: Creating depth and visual hierarchy
 * - Modern design: Contemporary approaches to creating beautiful interfaces
 * - Visual hierarchy: Organizing information to guide user attention
 * - Design systems: Standardized approaches to creating consistent experiences
 */
import SwiftUI

/// Core glass effect view modifier
struct GlassEffect: ViewModifier {
    let type: GlassConstants.GlassType
    let tintColor: Color?
    @Environment(\.colorScheme) private var colorScheme
    
    // Add explicit initializer
    init(type: GlassConstants.GlassType, tintColor: Color? = nil) {
        self.type = type
        self.tintColor = tintColor
    }
    
    private var backgroundColor: Color {
        let baseOpacity: Double
        
        // Add vibrant tint overlay for game cards
        if let tint = tintColor {
            return colorScheme == .dark ?
                tint.opacity(0.15) : // More visible in dark mode
                tint.opacity(0.08)   // Subtle in light mode
        }
        
        switch type {
        case .light:
            baseOpacity = GlassConstants.Opacity.lightGlass
        case .medium:
            baseOpacity = GlassConstants.Opacity.mediumGlass
        case .heavy:
            baseOpacity = GlassConstants.Opacity.heavyGlass
        case .colored(let color):
            return color.opacity(GlassConstants.Opacity.coloredGlass)
        }
        
        if colorScheme == .dark {
            // Dark mode uses semi-transparent dark background
            return Color(red: 28/255, green: 33/255, blue: 39/255)
                .opacity(baseOpacity * 4) // Increase opacity for dark mode
        } else {
            // Light mode uses semi-transparent white
            return Color.white.opacity(baseOpacity)
        }
    }
    
    private var borderColor: Color {
        let opacity = colorScheme == .dark ?
            GlassConstants.Border.darkMode :
            GlassConstants.Border.lightMode
        return Color.white.opacity(opacity)
    }
    
    private var shadowColor: Color {
        colorScheme == .dark ?
            GlassConstants.darkModeShadow :
            GlassConstants.lightModeShadow
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Existing blur layer
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .blur(radius: type.blurRadius)
                    
                    // Enhanced color layer with tint
                    backgroundColor
                    
                    // Add colored gradient for game cards
                    if let tint = tintColor {
                        LinearGradient(
                            colors: [
                                tint.opacity(colorScheme == .dark ? 0.2 : 0.1),
                                tint.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                    
                    // Existing gradient overlay
                }
            )
            // Enhanced colored shadow
            .shadow(
                color: tintColor?.opacity(0.3) ?? shadowColor,
                radius: 12,
                x: 0,
                y: 6
            )
    }
}

// MARK: - View Extension
extension View {
    func glassEffect(type: GlassConstants.GlassType = .medium, tint: Color? = nil) -> some View {
        self.modifier(GlassEffect(type: type, tintColor: tint))
    }
}
