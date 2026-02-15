//
//  NavigationCoordinator+TieredAchievements.swift
//  StreakSync
//
//  Extension to add tiered achievement navigation support
//

import SwiftUI

extension NavigationCoordinator {
    
    @ViewBuilder
    func tieredAchievementDetailSheet(for achievement: TieredAchievement) -> some View {
        NavigationStack {
            TieredAchievementDetailView(achievement: achievement)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            self.dismissSheet()
                        }
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
