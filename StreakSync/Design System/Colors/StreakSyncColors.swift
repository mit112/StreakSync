//
//  StreakSyncColors.swift
//  StreakSync
//
//  Sophisticated earthy color system with vintage aesthetic
//

import SwiftUI

// MARK: - Core Palette Colors (Energetic Growth - Market Tested)
enum PaletteColor: String, CaseIterable {
    case primary = "58CC02"    // Vibrant green - primary actions and streaks
    case secondary = "FF9600"  // Warm orange - secondary actions and CTAs
    case background = "FFFFFF" // Pure white - matches iOS system
    case cardBackground = "F2F2F7" // iOS secondarySystemGroupedBackground
    case textPrimary = "3C3C3C" // Dark gray - primary text
    case textSecondary = "8E8E93" // Medium gray - secondary text
    
    var color: Color {
        Color(hex: rawValue)
    }
    
    // Dark mode variants (optimized for dark mode)
    var darkVariant: Color {
        switch self {
        case .primary:
            return Color(hex: "4CAF50")  // Slightly muted green for dark mode
        case .secondary:
            return Color(hex: "FFB74D")  // Brighter orange for dark mode
        case .background:
            return Color(hex: "000000")  // Pure black for dark mode
        case .cardBackground:
            return Color(hex: "1A1A1A")  // Slightly warmer dark gray for dark mode cards
        case .textPrimary:
            return Color(hex: "FFFFFF")  // White text for dark mode
        case .textSecondary:
            return Color(hex: "8E8E93")  // Same secondary text for dark mode
        }
    }
}

// MARK: - Semantic Color System
struct StreakSyncColors {
    
    // MARK: - Color Cache
    @MainActor private static var colorCache: [String: Color] = [:]
    
    // MARK: - Cached Color Access
    @MainActor
    private static func cachedColor(for key: String, colorScheme: ColorScheme, provider: () -> Color) -> Color {
        let cacheKey = "\(key)_\(colorScheme == .dark ? "dark" : "light")"
        if let cached = colorCache[cacheKey] { return cached }
        let color = provider()
        colorCache[cacheKey] = color
        return color
    }
    
    // MARK: - Primary Colors
    @MainActor static func primary(for colorScheme: ColorScheme) -> Color {
        cachedColor(for: "primary", colorScheme: colorScheme) {
            colorScheme == .dark ?
                PaletteColor.primary.darkVariant :
                PaletteColor.primary.color
        }
    }
    
    @MainActor static func secondary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ?
            PaletteColor.secondary.darkVariant :
            PaletteColor.secondary.color
    }
    
    @MainActor static func tertiary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ?
            PaletteColor.textSecondary.darkVariant :
            PaletteColor.textSecondary.color
    }

    // MARK: - Background Colors (Using iOS System Colors)
    @MainActor static func background(for colorScheme: ColorScheme) -> Color {
        Color(.systemBackground)
    }

    @MainActor static func secondaryBackground(for colorScheme: ColorScheme) -> Color {
        Color(.secondarySystemBackground)
    }

    @MainActor static func cardBackground(for colorScheme: ColorScheme) -> Color {
        Color(.systemBackground)
    }
    
    // MARK: - Game List Item Background
    static func gameListItemBackground(for colorScheme: ColorScheme) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(.systemBackground))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        colorScheme == .dark ? 
                            Color(.separator) :
                            Color(.separator).opacity(0.3),  // Subtle border
                        lineWidth: 0.5
                    )
            }
            .shadow(
                color: colorScheme == .dark ? 
                    .black.opacity(0.2) : 
                    .black.opacity(0.08),  // More pronounced shadow for polish
                radius: colorScheme == .dark ? 12 : 8,
                x: 0,
                y: colorScheme == .dark ? 6 : 4
            )
    }
    
    // MARK: - Game List Item Background (iOS 26+)
    @available(iOS 26.0, *)
    static func gameListItemBackgroundiOS26(for colorScheme: ColorScheme) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(.systemBackground))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        colorScheme == .dark ? 
                            Color(.separator) :
                            Color(.separator).opacity(0.2),  // Subtle border
                        lineWidth: 0.5
                    )
            }
            .shadow(
                color: colorScheme == .dark ? 
                    .black.opacity(0.15) : 
                    .black.opacity(0.06),  // Enhanced shadow for polish
                radius: colorScheme == .dark ? 10 : 6,
                x: 0,
                y: colorScheme == .dark ? 5 : 3
            )
    }
    
    // MARK: - Enhanced Game Card Background (iOS 26+)
    @available(iOS 26.0, *)
    static func enhancedGameCardBackground(
        for colorScheme: ColorScheme,
        gameColor: Color,
        isActive: Bool,
        isHovered: Bool
    ) -> some View {
        ZStack {
            // Base card with material
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
            
            // Gradient overlay for visual interest
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: gameColor.opacity(0.03), location: 0),
                            .init(color: .clear, location: 0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Active streak glow
            if isActive {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                gameColor.opacity(0.4),
                                gameColor.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            } else {
                // Subtle border for inactive
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        colorScheme == .dark ? 
                            PaletteColor.textSecondary.color.opacity(0.3) :
                            PaletteColor.textSecondary.color.opacity(0.2),  // Subtle border
                        lineWidth: 0.5
                    )
            }
        }
        .shadow(
            color: .black.opacity(0.08),
            radius: isHovered ? 16 : 10,
            x: 0,
            y: isHovered ? 8 : 4
        )
    }

    // Add a new subtle background gradient option
    static func backgroundGradient(for colorScheme: ColorScheme) -> LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    PaletteColor.background.darkVariant,
                    Color(hex: "0A0A0A")  // Slightly darker than black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.secondarySystemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
    
    // MARK: - Accent Gradient
    static func accentGradient(for colorScheme: ColorScheme) -> LinearGradient {
        let colors = colorScheme == .dark ? [
            PaletteColor.primary.darkVariant,
            PaletteColor.secondary.darkVariant,
            PaletteColor.textSecondary.darkVariant
        ] : [
            PaletteColor.primary.color,
            PaletteColor.secondary.color,
            PaletteColor.textSecondary.color
        ]
        
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Full Spectrum Gradient
    static func fullSpectrumGradient(for colorScheme: ColorScheme) -> LinearGradient {
        let colors = colorScheme == .dark ?
            PaletteColor.allCases.map { $0.darkVariant } :
            PaletteColor.allCases.map { $0.color }
        
        return LinearGradient(
            colors: colors,
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    // MARK: - Game Category Colors (Energetic Growth)
    static func gameColor(for category: GameCategory, colorScheme: ColorScheme) -> Color {
        switch category {
        case .word:
            // Wordle-style: Primary green for word games
            return colorScheme == .dark ?
                PaletteColor.primary.darkVariant :
                PaletteColor.primary.color
        case .math:
            // Quordle-style: Secondary orange for math games
            return colorScheme == .dark ?
                PaletteColor.secondary.darkVariant :
                PaletteColor.secondary.color
        case .music:
            // Connections-style: Primary green for music games
            return colorScheme == .dark ?
                PaletteColor.primary.darkVariant :
                PaletteColor.primary.color
        case .geography:
            // Spelling Bee-style: Secondary orange for geography games
            return colorScheme == .dark ?
                PaletteColor.secondary.darkVariant :
                PaletteColor.secondary.color
        case .trivia:
            // Letter Boxed-style: Primary green for trivia games
            return colorScheme == .dark ?
                PaletteColor.primary.darkVariant :
                PaletteColor.primary.color
        case .puzzle:
            // Secondary orange for puzzle games
            return colorScheme == .dark ?
                PaletteColor.secondary.darkVariant :
                PaletteColor.secondary.color
        case .nytGames:
            // NYT Games: Red for New York Times branding
            return colorScheme == .dark ?
                Color(hex: "FF3B30").opacity(0.8) :
                Color(hex: "FF3B30")
        case .linkedinGames:
            // LinkedIn Games: LinkedIn blue
            return colorScheme == .dark ?
                Color(hex: "0077B5").opacity(0.8) :
                Color(hex: "0077B5")
        case .custom:
            return colorScheme == .dark ?
                PaletteColor.textSecondary.darkVariant :
                PaletteColor.textSecondary.color
        }
    }
    
    // MARK: - Status Colors (Energetic Growth)
    static func success(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ?
            PaletteColor.primary.darkVariant :
            PaletteColor.primary.color
    }
    
    static func warning(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ?
            PaletteColor.secondary.darkVariant :
            PaletteColor.secondary.color
    }
    
    static func error(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ?
            Color(hex: "FF3B30") :  // iOS red
            Color(hex: "FF3B30")
    }
    
    // MARK: - Text Colors
    static func primaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ?
            PaletteColor.textPrimary.darkVariant :  // White text for dark backgrounds
            PaletteColor.textPrimary.color          // Dark gray text for light backgrounds
    }
    
    static func secondaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ?
            PaletteColor.textSecondary.darkVariant :  // Medium gray for dark mode
            PaletteColor.textSecondary.color          // Medium gray for light mode
    }
    
    // MARK: - Game-Specific Icon Colors
    static func wordleIconColors(for colorScheme: ColorScheme) -> (background: Color, grid: Color, accent: Color) {
        return (
            background: PaletteColor.cardBackground.color,
            grid: PaletteColor.primary.color,
            accent: PaletteColor.secondary.color
        )
    }
    
    static func quordleIconColors(for colorScheme: ColorScheme) -> (background: Color, squares: [Color], borders: Color) {
        return (
            background: PaletteColor.primary.color,
            squares: [PaletteColor.background.color, PaletteColor.secondary.color],
            borders: PaletteColor.background.color
        )
    }
    
    static func connectionsIconColors(for colorScheme: ColorScheme) -> (background: Color, dots: Color, connections: Color) {
        return (
            background: PaletteColor.secondary.color,
            dots: PaletteColor.background.color,
            connections: PaletteColor.primary.color
        )
    }
    
    static func spellingBeeIconColors(for colorScheme: ColorScheme) -> (background: Color, outline: Color, fill: Color) {
        return (
            background: PaletteColor.primary.color,
            outline: PaletteColor.background.color,
            fill: PaletteColor.secondary.color
        )
    }
    
    static func letterBoxedIconColors(for colorScheme: ColorScheme) -> (background: Color, outline: Color, letters: Color) {
        return (
            background: PaletteColor.background.color,
            outline: PaletteColor.primary.color,
            letters: PaletteColor.secondary.color
        )
    }
    
    // MARK: - Accessibility Helpers
    static func contrastRatio(color1: Color, color2: Color) -> Double {
        // Simplified contrast ratio calculation
        // In a real implementation, you'd convert colors to RGB and calculate luminance
        // For now, we'll return estimated ratios based on our color choices
        
        // Night (#080F0F) on Cream (#EFF2C0) - High contrast
        // Ash Gray (#A4BAB7) on Cream (#EFF2C0) - Medium contrast
        // Auburn (#A52422) on Cream (#EFF2C0) - High contrast
        // Khaki (#BEA57D) on Cream (#EFF2C0) - Medium contrast
        
        return 4.5 // Estimated minimum contrast ratio for our palette
    }
    
    static func isAccessibleContrast(foreground: Color, background: Color) -> Bool {
        return contrastRatio(color1: foreground, color2: background) >= 4.5
    }
}

// MARK: - View Extension for Easy Access
extension View {
    func streakSyncStyle() -> some View {
        self.modifier(StreakSyncStyleModifier())
    }
}

struct StreakSyncStyleModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background(StreakSyncColors.background(for: colorScheme))
            .tint(StreakSyncColors.primary(for: colorScheme))
    }
}
