// GameCompactCardView.swift
//
//  Compact grid card for games
//

import SwiftUI

struct GameCompactCardView: View {
    let streak: GameStreak
    let isFavorite: Bool
    let onFavoriteToggle: (() -> Void)?
    let onTap: () -> Void
    
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    
    private var game: Game? {
        appState.games.first { $0.id == streak.gameId }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Icon and favorite in header
                HStack {
                    Spacer()
                    
                    if let onFavoriteToggle = onFavoriteToggle {
                        Button {
                            onFavoriteToggle()
                        } label: {
                            Image(systemName: isFavorite ? "star.fill" : "star")
                                .font(.caption)
                                .foregroundStyle(isFavorite ? .yellow : Color(.systemGray3))
                                .symbolEffect(.bounce, value: isFavorite)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
                
                // Game icon
                ZStack {
                    Circle()
                        .fill(game?.backgroundColor.color.opacity(0.15) ?? Color.gray.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: game?.iconSystemName ?? "gamecontroller")
                        .font(.title3)
                        .foregroundStyle(game?.backgroundColor.color ?? .gray)
                }
                
                // Game name
                Text(streak.gameName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                // Streak info
                HStack(spacing: 4) {
                    if streak.isActive {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    
                    Text("\(streak.currentStreak)")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(streak.isActive ? .primary : .secondary)
                }
                
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color(.systemGray5), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
