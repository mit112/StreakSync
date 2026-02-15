//
//  EmptyStates.swift
//  StreakSync
//
//  Beautiful empty states with ContentUnavailableView
//

import SwiftUI

// MARK: - Dashboard Empty State
struct DashboardEmptyState: View {
    let searchText: String
    let action: () -> Void
    
    var body: some View {
        modernEmptyState
    }
    
    private var modernEmptyState: some View {
        ContentUnavailableView {
            Label(
                searchText.isEmpty ? "No Games Yet" : "No Results",
                systemImage: searchText.isEmpty ? "gamecontroller" : "magnifyingglass"
            )
        } description: {
            Text(
                searchText.isEmpty
                ? "Start tracking your daily puzzle games.\nAdd your first game to begin!"
                : "No games match '\(searchText)'.\nTry a different search term."
            )
        } actions: {
            if searchText.isEmpty {
                Button("Browse Games") {
                    action()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }
    
}

// MARK: - Achievements Empty State
struct AchievementsEmptyState: View {
    var body: some View {
        ContentUnavailableView(
            "No Achievements Yet",
            systemImage: "trophy",
            description: Text("Complete games and build streaks to unlock achievements!")
        )
    }
}
