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
    @Environment(\.colorScheme) private var colorScheme
    
    private var backgroundColor: Color {
        let baseOpacity: Double
        
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
                    // Blur layer
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .blur(radius: type.blurRadius)
                    
                    // Color layer
                    backgroundColor
                    
                    // Gradient overlay for depth
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.05 : 0.1),
                            Color.white.opacity(colorScheme == .dark ? 0.02 : 0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .overlay(
                // Border
                RoundedRectangle(cornerRadius: 0)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
            .shadow(color: shadowColor, radius: 8, x: 0, y: 4)
    }
}

// MARK: - View Extension
extension View {
    /// Applies glass effect to any view
    func glassEffect(type: GlassConstants.GlassType = .medium) -> some View {
        self.modifier(GlassEffect(type: type))
    }
}
