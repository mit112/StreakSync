// GameListItemView.swift
//
//  Compact list view for games
//

import SwiftUI

// MARK: - Game List Item View (Simplified for list mode)
struct GameListItemView: View {
    let streak: GameStreak
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
                // Icon
                Image(systemName: game?.iconSystemName ?? "gamecontroller")
                    .font(.title3)
                    .foregroundStyle(game?.backgroundColor.color ?? .gray)
                    .frame(width: 32)
                
                // Name and stats
                VStack(alignment: .leading, spacing: 4) {
                    Text(game?.displayName ?? streak.gameName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    
                    HStack(spacing: 8) {
                        // Streak
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                            Text("\(streak.currentStreak)")
                                .font(.caption)
                                .foregroundStyle(streak.isActive ? .primary : .secondary)
                        }
                        
                        // Completion rate
                        Text("\(Int(streak.completionRate * 100))% success")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background {
                if #available(iOS 26.0, *) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color(.systemGray5), lineWidth: 0.5)
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
    }
}
