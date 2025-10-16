//
//  ThemeManager.swift
//  StreakSync
//
//  CONSOLIDATED: Single source of truth for theme management
//

import SwiftUI
import Combine

// MARK: - Updated ThemeManager
@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var followSystemColorScheme: Bool = true
    
    // Derive a best-effort color scheme outside of a View context
    // Note: This is a fallback for when not in a view context
    // Views should use @Environment(\.colorScheme) instead
    private var colorScheme: ColorScheme {
        // Default to light mode as fallback
        // Views should use @Environment(\.colorScheme) for proper color scheme detection
        return .light
    }
    
    // MARK: - Primary Palette Colors
    var primaryColor: Color {
        StreakSyncColors.primary(for: colorScheme)
    }
    
    var secondaryColor: Color {
        StreakSyncColors.secondary(for: colorScheme)
    }
    
    var tertiaryColor: Color {
        StreakSyncColors.tertiary(for: colorScheme)
    }
    
    // MARK: - Background Colors
    var primaryBackground: Color {
        StreakSyncColors.background(for: colorScheme)
    }
    
    var cardBackground: Color {
        StreakSyncColors.cardBackground(for: colorScheme)
    }
    
    var secondaryBackground: Color {
        StreakSyncColors.secondaryBackground(for: colorScheme)
    }
    
    // MARK: - Gradients
    var accentGradient: LinearGradient {
        StreakSyncColors.accentGradient(for: colorScheme)
    }
    
    var fullSpectrumGradient: LinearGradient {
        StreakSyncColors.fullSpectrumGradient(for: colorScheme)
    }
    
    // MARK: - Status Colors
    var successColor: Color {
        StreakSyncColors.success(for: colorScheme)
    }
    
    var warningColor: Color {
        StreakSyncColors.warning(for: colorScheme)
    }
    
    var errorColor: Color {
        StreakSyncColors.error(for: colorScheme)
    }
    
    // MARK: - Game Category Colors
    func gameColor(for category: GameCategory) -> Color {
        StreakSyncColors.gameColor(for: category, colorScheme: colorScheme)
    }
}
