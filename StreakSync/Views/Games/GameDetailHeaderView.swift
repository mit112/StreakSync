//
//  GameDetailHeaderView.swift
//  StreakSync
//
//  Game header component extracted from GameDetailView
//

import SwiftUI

// MARK: - Game Detail Header View
struct GameDetailHeaderView: View {
    let game: Game
    let streak: GameStreak
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                GameIconSection(game: game)
                GameInfoSection(game: game, streak: streak)
                Spacer()
            }
            
            StreakStatsRow(streak: streak)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(game.backgroundColor.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Game Icon Section
private struct GameIconSection: View {
    let game: Game
    
    var body: some View {
        Image(systemName: game.iconSystemName)
            .font(.system(size: 50))
            .foregroundStyle(game.backgroundColor.color)
            .frame(width: 70, height: 70)
            .background(
                game.backgroundColor.color.opacity(0.1),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .accessibilityHidden(true)
    }
}

// MARK: - Game Info Section
private struct GameInfoSection: View {
    let game: Game
    let streak: GameStreak
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(game.displayName)
                .font(.title2.weight(.semibold))
            
            Text(game.category.displayName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            if let lastPlayed = streak.lastPlayedDate {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text("Last played \(lastPlayed, style: .relative)")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Streak Stats Row
private struct StreakStatsRow: View {
    let streak: GameStreak
    
    var body: some View {
        HStack {
            StatPillView(
                title: "Current",
                value: "\(streak.currentStreak)",
                color: streak.streakStatus.color
            )
            
            StatPillView(
                title: "Best",
                value: "\(streak.maxStreak)",
                color: .orange
            )
            
            StatPillView(
                title: "Success",
                value: streak.completionPercentage,
                color: .blue
            )
        }
    }
}

// MARK: - Stat Pill View
struct StatPillView: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview
#Preview {
    GameDetailHeaderView(
        game: Game.wordle,
        streak: GameStreak(
            gameId: Game.wordle.id,
            gameName: "wordle",
            currentStreak: 5,
            maxStreak: 12,
            totalGamesPlayed: 30,
            totalGamesCompleted: 25,
            lastPlayedDate: Date(),
            streakStartDate: Date()
        )
    )
    .padding()
}