// GameCompactCardView.swift
//
//  Enhanced compact grid card for games with improved visual design
//

import SwiftUI

struct GameCompactCardView: View {
    let streak: GameStreak
    let isFavorite: Bool
    let onFavoriteToggle: (() -> Void)?
    let onTap: () -> Void
    
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false
    @State private var isHovered = false
    
    private var game: Game? {
        appState.games.first { $0.id == streak.gameId }
    }
    
    private var gameColor: Color {
        game?.backgroundColor.color ?? .gray
    }
    
    private var hasPlayedToday: Bool {
        guard let lastPlayed = streak.lastPlayedDate else { return false }
        return GameDateHelper.isGameResultFromToday(lastPlayed)
    }
    
    private var isActive: Bool {
        streak.currentStreak > 0
    }
    
    private var daysAgo: String {
        guard let lastPlayed = streak.lastPlayedDate else { return "Never" }
        return GameDateHelper.getGamePlayedDescription(lastPlayed)
    }
    
    private var completionRate: Int {
        guard streak.totalGamesPlayed > 0 else { return 0 }
        return Int((Double(streak.totalGamesCompleted) / Double(streak.totalGamesPlayed)) * 100)
    }
    
    private var safeIconName: String {
        guard let iconName = game?.iconSystemName, !iconName.isEmpty else {
            return "gamecontroller"
        }
        return iconName
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Top section with favorite and status indicator
                HStack {
                    // Active streak indicator
                    if isActive {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                            Text("\(streak.currentStreak)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.orange)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background {
                            Capsule()
                                .fill(.orange.opacity(0.15))
                        }
                    } else {
                        Spacer()
                    }
                    
                    Spacer()
                    
                    // Favorite button
                    if let onFavoriteToggle = onFavoriteToggle {
                        Button {
                            onFavoriteToggle()
                        } label: {
                            Image(systemName: isFavorite ? "star.fill" : "star")
                                .font(.caption)
                                .foregroundStyle(isFavorite ? .yellow : .secondary)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16) // Reduced horizontal padding to prevent overlap
                .padding(.top, 16) // Reduced top padding
                .padding(.bottom, 12) // Reduced bottom padding
                
                // Main content - centered with proper spacing
                VStack(spacing: 10) {
                    // Game icon with enhanced styling
                    ZStack {
                        // Background circle with gradient
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        gameColor.opacity(colorScheme == .dark ? 0.25 : 0.15),
                                        gameColor.opacity(colorScheme == .dark ? 0.15 : 0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                        
                        // Inner glow for active games
                        if isActive {
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            gameColor.opacity(0.4),
                                            gameColor.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                                .frame(width: 56, height: 56)
                        }
                        
                        Image.safeSystemName(safeIconName, fallback: "gamecontroller")
                            .font(.system(size: 26, weight: .medium))
                            .foregroundStyle(gameColor)
                            .symbolRenderingMode(.hierarchical)
                    }
                    
                    // Game name with better typography
                    Text(game?.displayName ?? streak.gameName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.8)
                        .frame(height: 32)
                    
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12) // Add horizontal padding to main content
                
                // Flexible spacer to push content up
                Spacer(minLength: 0)

                // Footer stats anchored to bottom
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: hasPlayedToday ? "checkmark.circle.fill" : "circle")
                            .font(.caption2)
                            .foregroundStyle(hasPlayedToday ? .green : .secondary)
                        Text("\(completionRate)%")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    Text(daysAgo)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 180) // Keep the same height
            .background {
                enhancedCardBackground
            }
        }
        .buttonStyle(EnhancedCardButtonStyle())
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }
    
    // MARK: - Enhanced Card Background
    private var enhancedCardBackground: some View {
        ZStack {
            // Base card background
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    colorScheme == .dark ? 
                    Color(hex: "1A1A1A") :
                    Color(hex: "FFFDFB").opacity(0.95)
                )
            
            // Subtle gradient overlay
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: gameColor.opacity(0.04), location: 0),
                            .init(color: .clear, location: 0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Border with consistent styling
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            colorScheme == .dark ? 
                            Color(.separator).opacity(0.4) :
                            Color(hex: "E8D5C7").opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
            
            // Active state overlay for games with current streaks
            if isActive {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                gameColor.opacity(0.4),
                                gameColor.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.0
                    )
            }
        }
        .shadow(
            color: isActive ? 
            gameColor.opacity(0.2) :
            (colorScheme == .dark ? .black.opacity(0.15) : .black.opacity(0.05)),
            radius: isActive ? 8 : 4,
            x: 0,
            y: isActive ? 4 : 2
        )
    }
}

// MARK: - Enhanced Card Button Style
struct EnhancedCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

// MARK: - Preview
#Preview {
    LazyVGrid(columns: [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ], spacing: 8) {
        GameCompactCardView(
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
            isFavorite: true,
            onFavoriteToggle: { print("Toggle favorite") },
            onTap: { print("Card tapped") }
        )
        
        GameCompactCardView(
            streak: GameStreak(
                gameId: Game.quordle.id,
                gameName: "quordle",
                currentStreak: 0,
                maxStreak: 12,
                totalGamesPlayed: 30,
                totalGamesCompleted: 20,
                lastPlayedDate: Date().addingTimeInterval(-3 * 24 * 60 * 60),
                streakStartDate: Date().addingTimeInterval(-3 * 24 * 60 * 60)
            ),
            isFavorite: false,
            onFavoriteToggle: { print("Toggle favorite") },
            onTap: { print("Card tapped") }
        )
    }
    .padding()
    .background(Color(.systemBackground))
    .environment(AppState())
}
