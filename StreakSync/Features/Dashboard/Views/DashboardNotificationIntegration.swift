//
//  DashboardNotificationIntegration.swift
//  StreakSync
//
//  Example integration of notification nudges in the dashboard
//

import SwiftUI

// MARK: - Dashboard with Notification Integration
struct DashboardWithNotifications: View {
    @Environment(AppState.self) private var appState
    @State private var showingNotificationSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Global notification nudge at the top
            NotificationNudgeView()
            
            // Main dashboard content
            dashboardContent
        }
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingNotificationSettings = true
                } label: {
                    Image(systemName: "bell")
                        .foregroundColor(.accentColor)
                }
            }
        }
        .sheet(isPresented: $showingNotificationSettings) {
            NotificationSettingsView()
        }
    }
    
    @ViewBuilder
    private var dashboardContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Dashboard header
                NotificationDashboardHeaderView()
                
                // Games with individual nudges
                ForEach(appState.games) { game in
                    gameRow(for: game)
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private func gameRow(for game: Game) -> some View {
        VStack(spacing: 8) {
            // Game card
            GameCardView(game: game)
            
            // Game-specific notification nudge
            GameNotificationNudgeView(game: game)
            
            // Streak risk nudge if applicable
            if let streak = appState.streaks.first(where: { $0.gameId == game.id }) {
                StreakRiskNudgeView(game: game, streakCount: streak.currentStreak)
            }
        }
    }
}

// MARK: - Dashboard Header
struct NotificationDashboardHeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Streaks")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Keep your daily puzzle streaks alive")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Game Card View
struct GameCardView: View {
    let game: Game
    
    var body: some View {
        HStack(spacing: 12) {
            GameIcon(game: game, size: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(game.name)
                    .font(.headline)
                
                Text("\(game.recentResults.count) games played")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("7")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.accentColor)
                
                Text("day streak")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack {
        DashboardWithNotifications()
            .environment(AppState(persistenceService: MockPersistenceService()))
    }
}
