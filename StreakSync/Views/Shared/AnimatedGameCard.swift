//
//  AnimatedGameCard.swift
//  StreakSync
//
//  Animated game card component extracted from ImprovedDashboardView
//

import SwiftUI

// MARK: - Animated Game Card
struct AnimatedGameCard: View {
    let game: Game
    let animationIndex: Int
    let hasInitiallyAppeared: Bool
    let onTap: () -> Void
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var themeManager: ThemeManager
    
    @State private var showCheckmark = false
    @State private var hasAnimatedCheckmark = false
    
    private var streak: GameStreak? {
        appState.getStreak(for: game)
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: game.iconSystemName)
                        .font(.title2)
                        .foregroundStyle(game.backgroundColor.color)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(game.displayName)
                            .font(.headline)
                        
                        if let lastPlayed = game.lastPlayedDate {
                            Text(lastPlayed.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if game.hasPlayedToday {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                            .transition(.scale.combined(with: .opacity))
                            .opacity(showCheckmark ? 1 : 0)
                            .scaleEffect(showCheckmark ? 1 : 0.5)
                    }
                }
                
                // Streak info with animations
                if let streak = streak, streak.currentStreak > 0 {
                    HStack(spacing: 16) {
                        AnimatedStreakStat(
                            value: "\(streak.currentStreak)",
                            label: "Current",
                            color: Color.orange
                        )
                        
                        AnimatedStreakStat(
                            value: "\(streak.maxStreak)",
                            label: "Best",
                            color: .secondary
                        )
                        
                        Spacer()
                        
                        Text("\(streak.totalGamesPlayed) played")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .modifier(InitialAnimationModifier(hasAppeared: hasInitiallyAppeared, index: animationIndex, totalCount: 10))
        .onAppear {
            if game.hasPlayedToday && !hasAnimatedCheckmark {
                withAnimation(.easeInOut.delay(Double(animationIndex) * 0.1)) {
                    showCheckmark = true
                }
                hasAnimatedCheckmark = true
            }
        }
    }
}

// MARK: - Animated Streak Stat Component (moved here as it's used by AnimatedGameCard)
struct AnimatedStreakStat: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.caption)
                Text(value)
                    .font(.title3.weight(.semibold))
                    .contentTransition(.numericText())
            }
            .foregroundStyle(color)
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Scale Button Style (moved here as it's used by AnimatedGameCard)
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    HapticManager.shared.trigger(.buttonTap)
                }
            }
    }
}

// MARK: - Initial Animation Modifier (shared utility)
struct InitialAnimationModifier: ViewModifier {
    let hasAppeared: Bool
    let index: Int
    let totalCount: Int
    
    func body(content: Content) -> some View {
        if !hasAppeared {
            content
                .opacity(0)
                .offset(y: 20)
                .animation(
                    .spring(response: 0.5, dampingFraction: 0.8)
                    .delay(Double(index) * 0.05),
                    value: hasAppeared
                )
        } else {
            content
        }
    }
}

// MARK: - Preview
#Preview {
    AnimatedGameCard(
        game: Game.wordle,
        animationIndex: 0,
        hasInitiallyAppeared: true,
        onTap: { print("Tapped") }
    )
    .padding()
    .environment(AppState())
    .environmentObject(ThemeManager.shared)
}