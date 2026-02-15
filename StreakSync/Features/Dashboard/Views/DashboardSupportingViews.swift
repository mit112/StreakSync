//
//  DashboardSupportingViews.swift
//  StreakSync
//
//  MODERNIZED: iOS 26 native materials, hover effects, and animations
//

import SwiftUI
import OSLog

// MARK: - Compact Progress Badge
struct CompactProgressBadge: View {
    let icon: String
    let value: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image.safeSystemName(icon, fallback: "questionmark.circle")
                .font(.caption)
                .symbolEffect(.pulse, options: .repeating.speed(0.5), value: value > 0)
            Text("\(value)")
                .font(.caption.weight(.semibold))
                .contentTransition(.numericText())
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background {
            Capsule()
                .fill(color.opacity(0.15))
                .overlay {
                    Capsule()
                        .stroke(.thinMaterial, lineWidth: 0.5)
                }
        }
        .animation(.smooth, value: value)
    }
}

// MARK: - Game Empty State
struct GameEmptyState: View {
    let title: String
    let subtitle: String
    let action: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gamecontroller")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
                .symbolEffect(.bounce, options: .nonRepeating)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let action = action {
                Button("Add Games", action: action)
                    .buttonStyle(.borderedProminent)
                    .hoverEffect(.lift)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Mini Streak Card
struct MiniStreakCard: View {
    let streak: GameStreak
    let game: Game
    let action: () -> Void
    
    @State private var isHovered = false
    
    private var safeIconName: String {
        let iconName = game.iconSystemName
        return iconName.isEmpty ? "gamecontroller" : iconName
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image.safeSystemName(safeIconName, fallback: "gamecontroller")
                    .font(.title2)
                    .foregroundStyle(game.backgroundColor.color)
                    .symbolEffect(.bounce, value: isHovered)
                
                VStack(spacing: 2) {
                    Text("\(streak.currentStreak)")
                        .font(.headline)
                        .contentTransition(.numericText())
                    Text("days")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Text(game.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 80)
            .padding(.vertical, 12)
            .cardStyle(cornerRadius: 12)
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.smooth(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .hoverEffect(.highlight)
    }
}

// MARK: - Enhanced Streak Card (iOS 26 Hero Animation Support)
struct EnhancedStreakCard: View {
    let streak: GameStreak
    let hasAppeared: Bool
    let animationIndex: Int
    let isFavorite: Bool
    let onFavoriteToggle: (() -> Void)?
    let action: () -> Void
    
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    
    private var game: Game? {
        appState.games.first { $0.id == streak.gameId }
    }
    
    private var gameColor: Color {
        game?.backgroundColor.color ?? .gray
    }
    
    var body: some View {
        iOS26EnhancedStreakCard(
            streak: streak,
            game: game,
            gameColor: gameColor,
            isFavorite: isFavorite,
            hasAppeared: hasAppeared,
            animationIndex: animationIndex,
            onFavoriteToggle: onFavoriteToggle,
            action: action
        )
    }
    
}

// MARK: - iOS 26 Enhanced Streak Card (Improved Color Design)
private struct iOS26EnhancedStreakCard: View {
    let streak: GameStreak
    let game: Game?
    let gameColor: Color
    let isFavorite: Bool
    let hasAppeared: Bool
    let animationIndex: Int
    let onFavoriteToggle: (() -> Void)?
    let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false
    @State private var isHovered = false
    @State private var iconBounce = false
    @State private var favoriteScale = false
    
    // Computed colors based on color scheme
    private var cardBackgroundColor: Color {
        if colorScheme == .dark {
            return Color(UIColor.secondarySystemBackground)
        } else {
            return .white
        }
    }
    
    private var cardBorderColor: Color {
        if colorScheme == .dark {
            return Color.white.opacity(0.1)
        } else {
            return Color.black.opacity(0.12)
        }
    }
    
    private var shadowColor: Color {
        if colorScheme == .dark {
            return isHovered ? gameColor.opacity(0.3) : .black.opacity(0.3)
        } else {
            return isHovered ? gameColor.opacity(0.2) : .black.opacity(0.1)
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Enhanced Game Icon
                gameIcon
                
                // Content Stack
                VStack(alignment: .leading, spacing: 10) {
                    // Header Row
                    headerRow
                    
                    // Stats Row
                    statsRow
                    
                    // Progress Bar
                    progressBar
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background {
                StreakSyncColors.enhancedGameCardBackground(
                    for: colorScheme,
                    gameColor: gameColor,
                    isActive: streak.isActive && streak.currentStreak > 0,
                    isHovered: isHovered
                )
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : (isHovered ? 1.02 : 1.0))
        .animation(.smooth(duration: 0.12), value: isPressed)
        .animation(.smooth(duration: 0.2), value: isHovered)
        .hoverEffect(.lift)
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(.smooth(duration: 0.08)) {
                    isPressed = pressing
                }
                if pressing {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            },
            perform: {}
        )
        .onHover { hovering in
            withAnimation(.smooth(duration: 0.2)) {
                isHovered = hovering
            }
            if hovering {
                iconBounce = true
            }
        }
        // iOS 26 Scroll Transition
        .scrollTransition { content, phase in
            content
                .opacity(phase.isIdentity ? 1 : 0.85)
                .scaleEffect(
                    x: phase.isIdentity ? 1 : 0.98,
                    y: phase.isIdentity ? 1 : 0.98
                )
        }
        // Initial appearance animation
        .modifier(InitialAnimationModifier(
            hasAppeared: hasAppeared,
            index: animationIndex,
            totalCount: 10
        ))
    }
    
    // MARK: - Game Icon (Simplified)
    private var gameIcon: some View {
        ZStack {
            Circle()
                .fill(gameColor.opacity(0.2))
                .frame(width: 56, height: 56)
                .overlay {
                    Circle()
                        .stroke(gameColor.opacity(0.4), lineWidth: 1)
                }
            
            Image.safeSystemName(safeGameIconName, fallback: "gamecontroller")
                .font(.title2.weight(.medium))
                .foregroundStyle(gameColor)
                .symbolEffect(.bounce, value: iconBounce)
            
            // Activity indicator
            if let lastPlayed = streak.lastPlayedDate, Calendar.current.isDateInToday(lastPlayed) {
                Circle()
                    .fill(PaletteColor.primary.color)
                    .frame(width: 12, height: 12)
                    .overlay {
                        Circle()
                            .stroke(cardBackgroundColor, lineWidth: 2)
                    }
                    .offset(x: 20, y: -20)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    private var safeGameIconName: String {
        guard let iconName = game?.iconSystemName, !iconName.isEmpty else {
            Logger(subsystem: "com.streaksync.app", category: "Dashboard").warning("Empty/nil icon for game '\(game?.displayName ?? "nil")' (streak: \(streak.gameName))")
            return "gamecontroller"
        }
        return iconName
    }
    
    // MARK: - Header Row
    private var headerRow: some View {
        HStack {
            Text(game?.displayName ?? streak.gameName)
                .font(.system(.headline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            
            Spacer()
            
            if let onFavoriteToggle = onFavoriteToggle {
                Button(action: {
                    withAnimation(.bouncy) {
                        favoriteScale.toggle()
                        onFavoriteToggle()
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 16))
                        .foregroundStyle(
                            isFavorite ? Color.yellow : Color.secondary.opacity(0.5)
                        )
                        .symbolEffect(.bounce, value: favoriteScale)
                        .scaleEffect(favoriteScale ? 1.2 : 1.0)
                }
                .buttonStyle(.plain)
                .hoverEffect(.highlight)
            }
        }
    }
    
    // MARK: - Stats Row (Better contrast)
    private var statsRow: some View {
        HStack(spacing: 20) {
            // Current streak with flame
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(
                        streak.currentStreak > 0 ?
                        Color.orange :
                        Color.secondary.opacity(0.5)
                    )
                    .symbolEffect(
                        .pulse,
                        options: .repeating.speed(0.5),
                        value: streak.isActive
                    )
                
                Text("\(streak.currentStreak)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(
                        streak.currentStreak > 0 ?
                        .primary :
                        .secondary
                    )
                    .contentTransition(.numericText(countsDown: false))
                
                Text("days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Completion rate with better visibility
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(
                        streak.completionRate > 0 ?
                        Color.green :
                        Color.secondary.opacity(0.5)
                    )
                
                Text("\(Int(streak.completionRate * 100))%")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(
                        streak.completionRate > 0 ?
                        Color.primary.opacity(0.8) :
                        Color.secondary
                    )
                    .contentTransition(.numericText())
            }
            
            Spacer()
            
            // Last played (if needed, more subtle)
            if let lastPlayed = streak.lastPlayedDate {
                Text(
                    lastPlayed.isToday ? "Today" :
                    lastPlayed.formatted(.relative(presentation: .named))
                )
                .font(.caption)
                .foregroundStyle(.tertiary)
                .opacity(0.8)
            }
        }
    }
    
    // MARK: - Progress Bar (More visible)
    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track with better visibility
                Capsule()
                    .fill(
                        colorScheme == .dark ?
                        Color.white.opacity(0.1) :
                        Color.black.opacity(0.1)
                    )
                    .frame(height: 4)
                
                // Progress fill
                if streak.currentStreak > 0 {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    gameColor.opacity(0.9),
                                    gameColor
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: geometry.size.width * min(Double(streak.currentStreak) / 30.0, 1.0),
                            height: 4
                        )
                        .animation(.smooth(duration: 0.5), value: streak.currentStreak)
                    
                    // Subtle glow for active streaks
                    if streak.isActive {
                        Capsule()
                            .fill(gameColor)
                            .frame(
                                width: geometry.size.width * min(Double(streak.currentStreak) / 30.0, 1.0),
                                height: 4
                            )
                            .blur(radius: 6)
                            .opacity(0.5)
                    }
                }
            }
        }
        .frame(height: 4)
    }
    
}
