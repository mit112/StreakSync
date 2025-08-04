//
//  TieredAchievement+Extensions.swift
//  StreakSync
//
//  UI-related extensions for TieredAchievement
//

import SwiftUI

extension TieredAchievement {
    /// The display color based on current tier or gray if locked
    var displayColor: Color {
        progress.currentTier?.color ?? Color(.systemGray3)
    }
}