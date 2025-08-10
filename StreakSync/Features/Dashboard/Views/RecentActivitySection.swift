//
//  RecentActivitySection.swift
//  StreakSync
//
//  Recent activity section for dashboard
//

import SwiftUI


// MARK: - Recent Activity Section
struct RecentActivitySection: View {
    let filteredStreaks: [GameStreak]
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
                .foregroundStyle(.primary)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(filteredStreaks.prefix(5)) { streak in
                        if let game = appState.games.first(where: { $0.id == streak.gameId }) {
                            MiniStreakCard(
                                streak: streak,
                                game: game,
                                action: {
                                    // Navigate to game detail
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    RecentActivitySection(
        filteredStreaks: []
    )
    .environment(AppState())
    .environmentObject(NavigationCoordinator())
}
