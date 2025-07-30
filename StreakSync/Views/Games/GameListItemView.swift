// GameListItemView.swift
//
//  Compact list view for games
//

import SwiftUI

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
                // Smaller icon
                Image(systemName: game?.iconSystemName ?? "gamecontroller")
                    .font(.body)
                    .foregroundStyle(game?.backgroundColor.color ?? .gray)
                    .frame(width: 24, height: 24)
                
                // Game name
                Text(streak.gameName)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                // Status indicators
                HStack(spacing: 8) {
                    if streak.isActive {
                        Image(systemName: "flame.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    
                    // Streak count
                    Text("\(streak.currentStreak)")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(streak.isActive ? .primary : .secondary)
                        .frame(minWidth: 30, alignment: .trailing)
                    
                    // Favorite toggle
                    if let onFavoriteToggle = onFavoriteToggle {
                        Button {
                            onFavoriteToggle()
                        } label: {
                            Image(systemName: isFavorite ? "star.fill" : "star")
                                .font(.caption)
                                .foregroundStyle(isFavorite ? .yellow : .secondary)
                                .symbolEffect(.bounce, value: isFavorite)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
