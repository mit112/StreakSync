//
//  DashboardStreaksSection.swift
//  StreakSync
//
//  Active streaks section extracted from DashboardView
//

import SwiftUI

// MARK: - Dashboard Streaks Section
struct DashboardStreaksSection: View {
    @Environment(AppState.self) private var appState
    @Environment(NavigationCoordinator.self) private var coordinator
    
    private var activeStreaks: [GameStreak] {
        appState.streaks
            .filter { $0.currentStreak > 0 }
            .sorted { $0.currentStreak > $1.currentStreak }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(
                title: NSLocalizedString("dashboard.active_streaks", comment: "Active Streaks"),
                icon: "flame.fill",
                action: {
                    coordinator.navigateTo(.allStreaks)
                }
            )
            .accessibilityAddTraits(.isHeader)
            
            if activeStreaks.isEmpty {
//                EmptyStreaksCard()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(activeStreaks.prefix(3).enumerated()), id: \.element.id) { index, streak in
                        DashboardStreakRow(streak: streak)
                            .accessibilitySortPriority(Double(activeStreaks.count - index))
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Active Streaks")
    }
}

// MARK: - Dashboard Streak Row
struct DashboardStreakRow: View {
    let streak: GameStreak
    @Environment(NavigationCoordinator.self) private var coordinator
    @StateObject private var browserLauncher = BrowserLauncher.shared
    
    var body: some View {
        HStack {
            // Status icon
            Image(systemName: streak.streakStatus.iconSystemName)
                .foregroundStyle(streak.streakStatus.color)
                .accessibilityHidden(true)
            
            // Game info
            VStack(alignment: .leading, spacing: 2) {
                Text(streak.gameName.capitalized)
                    .font(.subheadline.weight(.medium))
                
                Text("\(streak.completionPercentage) completion rate")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Quick play button
            QuickPlayButton(streak: streak)
            
            // Streak count
            Text(streak.displayText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(streak.streakStatus.color)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture {
            coordinator.navigateTo(.streakHistory(streak))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(streak.gameName), \(streak.displayText), \(streak.completionPercentage) completion rate")
    }
}

// MARK: - Quick Play Button
private struct QuickPlayButton: View {
    let streak: GameStreak
    
    var body: some View {
        Button {
            if let game = Game.popularGames.first(where: { $0.id == streak.gameId }) {
                BrowserLauncher.shared.launchGame(game)
            }
        } label: {
            Image(systemName: "play.fill")
                .font(.caption2)
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(streak.streakStatus.color, in: Circle())
        }
        .accessibilityLabel("Play \(streak.gameName)")
    }
}


// MARK: - Preview
#Preview {
    ScrollView {
        DashboardStreaksSection()
            .environment(AppState())
            .environment(NavigationCoordinator())
            .padding()
    }
}
