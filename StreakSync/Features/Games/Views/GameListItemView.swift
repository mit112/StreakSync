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
    @Environment(\.colorScheme) private var colorScheme
    
    private var game: Game? {
        appState.games.first { $0.id == streak.gameId }
    }
    
    private var safeIconName: String {
        guard let iconName = game?.iconSystemName, !iconName.isEmpty else {
            return "gamecontroller"
        }
        return iconName
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                Image.safeSystemName(safeIconName, fallback: "gamecontroller")
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
                    StreakSyncColors.gameListItemBackgroundiOS26(for: colorScheme)
                } else {
                    StreakSyncColors.gameListItemBackground(for: colorScheme)
                }
            }
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
    }
}
