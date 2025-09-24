//
//  ModernGameCard.swift
//  StreakSync
//
//  Clean, modern game card with material design
//

import SwiftUI

struct ModernGameCard: View {
    let streak: GameStreak
    let game: Game
    let isFavorite: Bool
    let onFavoriteToggle: (() -> Void)?
    let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false
    
    // Computed properties
    private var gameColor: Color {
        game.backgroundColor.color
    }
    
    private var hasPlayedToday: Bool {
        game.hasPlayedToday
    }
    
    private var daysAgo: String {
        guard let lastPlayed = streak.lastPlayedDate else { return "Never played" }
        
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: lastPlayed, to: Date()).day ?? 0
        
        switch days {
        case 0: return "Today"
        case 1: return "Yesterday"
        default: return "\(days) days ago"
        }
    }
    
    private var completionRate: Int {
        guard streak.totalGamesPlayed > 0 else { return 0 }
        return Int((Double(streak.totalGamesCompleted) / Double(streak.totalGamesPlayed)) * 100)
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon with subtle background
                gameIcon
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    // Title row
                    HStack {
                        Text(game.displayName)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Favorite button
                        if let onFavoriteToggle = onFavoriteToggle {
                            Button(action: onFavoriteToggle) {
                                Image(systemName: isFavorite ? "star.fill" : "star")
                                    .font(.caption)
                                    .foregroundStyle(isFavorite ? .yellow : .secondary)
                                    .contentTransition(.symbolEffect(.replace))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    // Single metadata line
                    HStack(spacing: 8) {
                        // Streak indicator
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                                .font(.caption2)
                                .foregroundStyle(streak.currentStreak > 0 ? .orange : .secondary)
                            Text("\(streak.currentStreak)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .contentTransition(.numericText())
                        }
                        
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        
                        // Completion rate
                        HStack(spacing: 3) {
                            Image(systemName: hasPlayedToday ? "checkmark.circle.fill" : "circle")
                                .font(.caption2)
                                .foregroundStyle(hasPlayedToday ? .green : .secondary)
                            Text("\(completionRate)%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        
                        // Last played
                        Text(daysAgo)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                    }
                    
                    // Progress bar
                    progressBar
                }
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background {
                StreakSyncColors.gameListItemBackground(for: colorScheme)
            }
        }
        .buttonStyle(ModernCardButtonStyle())
    }
    
    // MARK: - Game Icon
    private var gameIcon: some View {
        ZStack {
            Circle()
                .fill(gameColor.opacity(colorScheme == .dark ? 0.2 : 0.12))
                .frame(width: 48, height: 48)
            
            Image(systemName: game.iconSystemName)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(gameColor)
                .symbolRenderingMode(.hierarchical)
        }
    }
    
    // MARK: - Progress Bar
    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Capsule()
                    .fill(Color(.quaternarySystemFill))
                    .frame(height: 6)
                
                // Progress
                if streak.currentStreak > 0 {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    gameColor,
                                    gameColor.opacity(0.7)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: min(
                                geometry.size.width * (Double(streak.currentStreak) / 30.0),
                                geometry.size.width
                            ),
                            height: 6
                        )
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: streak.currentStreak)
                }
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Modern Card Button Style
struct ModernCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
    }
}


// MARK: - Preview
#Preview {
    VStack(spacing: 16) {
        ModernGameCard(
            streak: GameStreak(
                gameId: Game.wordle.id,
                gameName: "wordle",
                currentStreak: 15,
                maxStreak: 23,
                totalGamesPlayed: 50,
                totalGamesCompleted: 45,
                lastPlayedDate: Date(),
                streakStartDate: Date().addingTimeInterval(-15 * 24 * 60 * 60)
            ),
            game: Game.wordle,
            isFavorite: true,
            onFavoriteToggle: { print("Toggle favorite") },
            action: { print("Card tapped") }
        )
        
        ModernGameCard(
            streak: GameStreak(
                gameId: Game.quordle.id,
                gameName: "quordle",
                currentStreak: 3,
                maxStreak: 12,
                totalGamesPlayed: 30,
                totalGamesCompleted: 20,
                lastPlayedDate: Date().addingTimeInterval(-1 * 24 * 60 * 60),
                streakStartDate: Date().addingTimeInterval(-3 * 24 * 60 * 60)
            ),
            game: Game.quordle,
            isFavorite: false,
            onFavoriteToggle: { print("Toggle favorite") },
            action: { print("Card tapped") }
        )
    }
    .padding()
    .background(Color(.systemBackground))
}
