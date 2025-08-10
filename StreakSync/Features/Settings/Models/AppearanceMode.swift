//
//  AppearanceMode.swift
//  StreakSync
//
//  Core appearance mode system with SwiftUI integration
//

import SwiftUI

// MARK: - Appearance Mode Enum
enum AppearanceMode: Int, CaseIterable, Identifiable, Codable {
    case system = 0
    case light = 1
    case dark = 2
    
    var id: Int { rawValue }
    
    /// User-friendly display name
    var displayName: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }
    
    /// SF Symbol icon for each mode
    var iconName: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        }
    }
    
    /// Convert to SwiftUI ColorScheme
    /// Returns nil for system mode to follow device settings
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

// MARK: - View Extension for App-wide Theme
extension View {
    /// Applies the user's appearance preference to the view hierarchy
    func applyAppearanceMode() -> some View {
        self.modifier(AppearanceModeModifier())
    }
}

// MARK: - Appearance Mode Modifier
private struct AppearanceModeModifier: ViewModifier {
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    
    func body(content: Content) -> some View {
        content
            .preferredColorScheme(appearanceMode.colorScheme)
    }
}

//// MARK: - Bundle Extension for App Name
extension Bundle {
    var displayName: String? {
        return object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
               object(forInfoDictionaryKey: "CFBundleName") as? String
    }
}
