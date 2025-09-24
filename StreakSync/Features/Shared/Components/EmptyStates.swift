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
        if #available(iOS 17.0, *) {
            modernEmptyState
        } else {
            legacyEmptyState
        }
    }
    
    @available(iOS 17.0, *)
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
    
    private var legacyEmptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: searchText.isEmpty ? "gamecontroller" : "magnifyingglass")
                .font(.system(size: 56))
                .foregroundStyle(.quaternary)
                .symbolEffect(.pulse, options: .repeating)
            
            VStack(spacing: 8) {
                Text(searchText.isEmpty ? "No Games Yet" : "No Results")
                    .font(.title2.weight(.semibold))
                
                Text(
                    searchText.isEmpty
                    ? "Start tracking your daily puzzle games"
                    : "No games match your search"
                )
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }
            
            if searchText.isEmpty {
                Button {
                    action()
                } label: {
                    Label("Browse Games", systemImage: "plus.circle.fill")
                        .font(.body.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Achievements Empty State
struct AchievementsEmptyState: View {
    var body: some View {
        if #available(iOS 17.0, *) {
            ContentUnavailableView(
                "No Achievements Yet",
                systemImage: "trophy",
                description: Text("Complete games and build streaks to unlock achievements!")
            )
        } else {
            VStack(spacing: 20) {
                Image(systemName: "trophy")
                    .font(.system(size: 56))
                    .foregroundStyle(.quaternary)
                
                VStack(spacing: 8) {
                    Text("No Achievements Yet")
                        .font(.title2.weight(.semibold))
                    
                    Text("Complete games and build streaks to unlock achievements!")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
        }
    }
}
