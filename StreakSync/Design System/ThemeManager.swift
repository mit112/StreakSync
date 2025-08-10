//
//  ThemeManager.swift
//  StreakSync
//
//  CONSOLIDATED: Single source of truth for theme management
//

import SwiftUI
import Combine

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var followSystemColorScheme: Bool = true
    
    private init() {
        loadSettings()
    }
    
    // MARK: - System Color Scheme
    
    var colorScheme: ColorScheme? {
        followSystemColorScheme ? nil : nil // Always follow system
    }
    
    var isDarkMode: Bool {
        UITraitCollection.current.userInterfaceStyle == .dark
    }
    
    // MARK: - Background Colors (System colors only)
    
    var primaryBackground: Color {
        Color(.systemBackground)
    }
    
    var cardBackground: Color {
        Color(.secondarySystemBackground)
    }
    
    var tertiaryBackground: Color {
        Color(.tertiarySystemBackground)
    }
    
    var groupedBackground: Color {
        Color(.systemGroupedBackground)
    }
    
    // MARK: - Accent Colors
    
    var primaryAccent: Color {
        Color.accentColor
    }
    
    var successColor: Color {
        Color(.systemGreen)
    }
    
    var warningColor: Color {
        Color(.systemOrange)
    }
    
    var errorColor: Color {
        Color(.systemRed)
    }
    
    // MARK: - Streak Colors
    
    var streakActiveColor: Color {
        Color(.systemGreen)
    }
    
    var streakInactiveColor: Color {
        Color(.systemOrange)
    }
    
    var streakBrokenColor: Color {
        Color(.systemRed)
    }
    
    // MARK: - Simple Gradients (UI elements only)
    
    var statOrangeGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(.systemOrange),
                Color(.systemOrange).opacity(0.8)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    var statGreenGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(.systemGreen),
                Color(.systemGreen).opacity(0.8)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    var accentGradient: LinearGradient {
        LinearGradient(
            colors: [
                primaryAccent,
                primaryAccent.opacity(0.8)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    // MARK: - Deprecated Properties (For backward compatibility)
    
    @available(*, deprecated, message: "Use primaryBackground instead")
    var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [primaryBackground],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    @available(*, deprecated, message: "Use primaryBackground instead")
    var subtleBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: [primaryBackground],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Settings
    
    private func loadSettings() {
        let defaults = UserDefaults.standard
        followSystemColorScheme = defaults.bool(forKey: "followSystemColorScheme")
        if !defaults.bool(forKey: "hasSetDefaults") {
            followSystemColorScheme = true
            defaults.set(true, forKey: "followSystemColorScheme")
            defaults.set(true, forKey: "hasSetDefaults")
        }
    }
    
    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(followSystemColorScheme, forKey: "followSystemColorScheme")
    }
    
    // MARK: - Removed Features
    
    @available(*, deprecated, message: "Time-based themes removed")
    func updateThemeIfNeeded() {
        // No-op
    }
    
    @available(*, deprecated, message: "Use system colors")
    var currentTheme: ColorTheme {
        get { .indigo }
        set { /* No-op */ }
    }
    
    @available(*, deprecated, message: "Time-based themes removed")
    var useTimeBasedThemes: Bool {
        get { false }
        set { /* No-op */ }
    }
}
