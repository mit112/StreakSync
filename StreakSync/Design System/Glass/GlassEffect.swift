//
//  GlassEffect.swift
//  StreakSync
//
//  Created by MiT on 7/23/25.
//

// DesignSystem/Glass/GlassEffect.swift
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
