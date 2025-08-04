//
//  AchievementsView.swift
//  StreakSync
//
//  Updated to display tiered achievements
//

import SwiftUI

// MARK: - Achievements View
struct AchievementsView: View {
    var body: some View {
        // Simply use the tiered achievements view
        TieredAchievementsGridView()
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        AchievementsView()
            .environment(AppState())
            .environmentObject(NavigationCoordinator())
    }
}
