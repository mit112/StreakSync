//
//  GlassConstants.swift
//  StreakSync
//
//  Created by MiT on 7/23/25.
//

// DesignSystem/Glass/GlassConstants.swift
import SwiftUI

/// Glass effect constants matching our design system specifications
public enum GlassConstants {
    
    // MARK: - Glass Opacity Values
    enum Opacity {
        static let lightGlass = 0.2
        static let mediumGlass = 0.4
        static let heavyGlass = 0.6
        static let coloredGlass = 0.2
        
        // Dark mode adjustments
        static let darkModeFactor = 0.5 // Reduces opacity by half in dark mode
    }
    
    // MARK: - Blur Radius Values
    enum Blur {
        static let light: CGFloat = 10
        static let medium: CGFloat = 20
        static let heavy: CGFloat = 30
        static let colored: CGFloat = 20
    }
    
    // MARK: - Border Opacity
    enum Border {
        static let lightMode: CGFloat = 0.3
        static let darkMode: CGFloat = 0.1
    }
    
    // MARK: - Shadow Configuration
    static let lightModeShadow = Color(red: 31/255, green: 38/255, blue: 135/255).opacity(0.15)
    static let darkModeShadow = Color.black.opacity(0.3)
    
    // MARK: - Glass Types
    enum GlassType {
        case light
        case medium
        case heavy
        case colored(Color)
        
        var blurRadius: CGFloat {
            switch self {
            case .light: return Blur.light
            case .medium: return Blur.medium
            case .heavy: return Blur.heavy
            case .colored: return Blur.colored
            }
        }
    }
}
