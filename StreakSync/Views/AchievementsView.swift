//
//  AchievementsView.swift
//  StreakSync
//
//  Simplified achievements view with clean grid layout
//

import SwiftUI

// MARK: - Achievements View
struct AchievementsView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var coordinator: NavigationCoordinator
    
    private var unlockedCount: Int {
        appState.achievements.filter(\.isUnlocked).count
    }
    
    private var totalCount: Int {
        appState.achievements.count
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                // Progress header
                progressHeader
                
                // Achievements grid
                achievementsGrid
            }
            .padding()
        }
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.large)
    }
    
    // MARK: - Progress Header
    private var progressHeader: some View {
        VStack(spacing: Spacing.md) {
            // Progress circle
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 8)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: CGFloat(unlockedCount) / CGFloat(totalCount))
                    .stroke(Color.yellow, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 2) {
                    Text("\(unlockedCount)")
                        .font(.largeTitle.weight(.bold))
                    Text("of \(totalCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Text("Achievements Unlocked")
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
    }
    
    // MARK: - Achievements Grid
    private var achievementsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: Spacing.md),
                GridItem(.flexible(), spacing: Spacing.md)
            ],
            spacing: Spacing.md
        ) {
            ForEach(appState.achievements) { achievement in
                AchievementCard(achievement: achievement)
                    .onTapGesture {
                        coordinator.presentSheet(.achievementDetail(achievement))
                    }
            }
        }
    }
}

// MARK: - Achievement Card
struct AchievementCard: View {
    let achievement: Achievement
    
    var body: some View {
        VStack(spacing: Spacing.md) {
            // Icon
            Image(systemName: achievement.iconSystemName)
                .font(.largeTitle)
                .foregroundStyle(achievement.isUnlocked ? achievement.displayColor : .gray)
            
            // Title
            Text(achievement.title)
                .font(.caption.weight(.medium))
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            // Status
            if achievement.isUnlocked {
                if let date = achievement.unlockedDate {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Locked")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.card)
                        .stroke(
                            achievement.isUnlocked ? achievement.displayColor.opacity(0.3) : Color.clear,
                            lineWidth: 1
                        )
                )
        )
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
