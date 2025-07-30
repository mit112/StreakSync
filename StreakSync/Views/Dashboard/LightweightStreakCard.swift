// LightweightStreakCard.swift
import SwiftUI

struct LightweightStreakCard: View {
    let streak: GameStreak
    let hasAppeared: Bool
    let animationIndex: Int
    let isFavorite: Bool
    let onFavoriteToggle: (() -> Void)?
    let onTap: () -> Void
    
    @Environment(AppState.self) private var appState
    
    private var game: Game? {
        appState.games.first { $0.id == streak.gameId }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Simple icon
                if let game = game {
                    Image(systemName: game.iconSystemName)
                        .font(.title2)
                        .foregroundStyle(game.backgroundColor.color)
                        .frame(width: 40, height: 40)
                }
                
                // Text info
                VStack(alignment: .leading, spacing: 4) {
                    Text(streak.gameName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    HStack {
                        if streak.isActive {
                            Label("\(streak.currentStreak)", systemImage: "flame.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        } else {
                            Text("Inactive")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Favorite button
                if let onFavoriteToggle = onFavoriteToggle {
                    Button(action: onFavoriteToggle) {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .foregroundStyle(isFavorite ? .yellow : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}
