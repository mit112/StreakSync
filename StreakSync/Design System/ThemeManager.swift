import SwiftUI
import Combine

internal class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var currentTheme: ColorTheme = .indigo
    @Published var useTimeBasedThemes: Bool = true
    @Published var followSystemColorScheme: Bool = true

    var colorScheme: ColorScheme? {
        followSystemColorScheme ? nil : (prefersDarkMode ? .dark : .light)
    }

    private var prefersDarkMode: Bool = false

    private init() {
        loadSettings()
        updateThemeIfNeeded()

        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            DispatchQueue.main.async { [weak self] in
                self?.updateThemeIfNeeded()
            }
        }
    }

    var colors: ThemeColors {
        currentTheme.colors
    }

    var isDarkMode: Bool {
        UITraitCollection.current.userInterfaceStyle == .dark
    }

    var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: isDarkMode ?
                colors.gradientDark.map { Color(hex: $0) } :
                colors.gradientLight.map { Color(hex: $0) },
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var subtleBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: isDarkMode ?
                colors.gradientDark.map { Color(hex: $0).opacity(0.3) } :
                colors.gradientLight.map { Color(hex: $0).opacity(0.6) },
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var primaryBackground: Color {
        Color(hex: isDarkMode ? colors.backgroundDark : colors.backgroundLight)
    }

    var cardBackground: Color {
        isDarkMode
            ? Color(.systemGray6).opacity(0.5)
            : Color(hex: "F9FAFB") // light solid card background
    }

    var statOrangeGradient: LinearGradient {
        LinearGradient(
            colors: colors.statOrange.map { Color(hex: $0) },
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var statGreenGradient: LinearGradient {
        LinearGradient(
            colors: colors.statGreen.map { Color(hex: $0) },
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var accentGradient: LinearGradient {
        LinearGradient(
            colors: isDarkMode ? colors.accentDark.map { Color(hex: $0) } : colors.accentLight.map { Color(hex: $0) },
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var primaryAccent: Color {
        Color(hex: isDarkMode ? colors.accentDark[0] : colors.accentLight[0])
    }

    var streakActiveColor: Color {
        Color(hex: colors.statGreen[0])
    }

    var streakInactiveColor: Color {
        Color(hex: colors.statOrange[0])
    }

    func timeBasedTheme() -> ColorTheme {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<9: return .aurora
        case 9..<12: return .ocean
        case 12..<17: return .forest
        case 17..<21: return .sunset
        default: return .indigo
        }
    }

    func updateThemeIfNeeded() {
        guard useTimeBasedThemes else { return }
        let newTheme = timeBasedTheme()
        if newTheme != currentTheme {
            withAnimation(.smooth(duration: 1.0)) {
                currentTheme = newTheme
            }
        }
    }

    func setTheme(_ theme: ColorTheme) {
        withAnimation(.smooth) {
            currentTheme = theme
            useTimeBasedThemes = false
            saveSettings()
        }
    }

    func enableTimeBasedThemes() {
        useTimeBasedThemes = true
        updateThemeIfNeeded()
        saveSettings()
    }

    private func loadSettings() {
        let defaults = UserDefaults.standard
        if let themeRaw = defaults.string(forKey: "selectedTheme"),
           let theme = ColorTheme(rawValue: themeRaw) {
            currentTheme = theme
        }
        useTimeBasedThemes = defaults.bool(forKey: "useTimeBasedThemes")
        followSystemColorScheme = defaults.bool(forKey: "followSystemColorScheme")
    }

    private func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(currentTheme.rawValue, forKey: "selectedTheme")
        defaults.set(useTimeBasedThemes, forKey: "useTimeBasedThemes")
        defaults.set(followSystemColorScheme, forKey: "followSystemColorScheme")
    }
}
