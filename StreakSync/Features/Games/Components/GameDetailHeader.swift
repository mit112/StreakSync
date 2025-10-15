//
//  GameDetailHeader.swift
//  StreakSync
//
//  Enhanced header component for game detail view
//

import SwiftUI

struct GameDetailHeader: View {
    let game: Game
    let streak: GameStreak
    
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Animated game icon
            AnimatedGameIcon(
                game: game,
                isActive: streak.isActive
            )
            
            // Game info
            GameInfoSection(
                game: game,
                streak: streak
            )
            
            // Animated stats pills
            StatsRow(streak: streak)
        }
        .padding(Spacing.xl)
        .glassCard()
    }
}

// MARK: - Animated Game Icon
private struct AnimatedGameIcon: View {
    let game: Game
    let isActive: Bool
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(game.backgroundColor.color.opacity(0.15))
                .frame(width: 100, height: 100)
                .scaleEffect(isAnimating && isActive ? 1.1 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                    value: isAnimating
                )
            
            Image.safeSystemName(game.iconSystemName, fallback: "gamecontroller")
                .font(.system(size: 44))
                .foregroundStyle(game.backgroundColor.color)
        }
        .hoverable()
        .onAppear {
            if isActive {
                isAnimating = true
            }
        }
    }
}

// MARK: - Game Info Section
private struct GameInfoSection: View {
    let game: Game
    let streak: GameStreak
    
    var body: some View {
        VStack(spacing: Spacing.xs) {
            Text(game.displayName)
                .font(.title2.weight(.semibold))
            
            HStack(spacing: Spacing.sm) {
                Text(game.category.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                if let _ = streak.lastPlayedDate {
                    Text("•")
                        .foregroundStyle(.tertiary)
                    
                    Text(streak.lastPlayedText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Stats Row
private struct StatsRow: View {
    let streak: GameStreak
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            AnimatedStatPill(
                value: "\(streak.currentStreak)",
                label: "Current",
                color: streak.currentStreak > 0 ? .green : .orange,
                isActive: streak.isActive
            )
            
            AnimatedStatPill(
                value: "\(streak.maxStreak)",
                label: "Best",
                color: .blue,
                isActive: false
            )
            
            AnimatedStatPill(
                value: streak.completionPercentage,
                label: "Success",
                color: .purple,
                isActive: false
            )
        }
    }
}

// MARK: - Preview
#Preview {
    GameDetailHeader(
        game: Game.wordle,
        streak: GameStreak(
            gameId: Game.wordle.id,
            gameName: "wordle",
            currentStreak: 15,
            maxStreak: 23,
            totalGamesPlayed: 100,
            totalGamesCompleted: 85,
            lastPlayedDate: Date(),
            streakStartDate: Date()
        )
    )
    .padding()
}
