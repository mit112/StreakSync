//
//  AnimatedGameCard.swift
//  StreakSync
//
//  Animated game card component extracted from ImprovedDashboardView
//

import SwiftUI

struct AnimatedGameCard: View {
    let game: Game
    let animationIndex: Int
    let hasInitiallyAppeared: Bool
    let onTap: () -> Void
    
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showCheckmark = false
    @State private var hasAnimatedCheckmark = false
    
    private var streak: GameStreak? {
        appState.getStreak(for: game)
    }
    
    // Get vibrant color for the game category
    private var gameColor: Color {
        game.backgroundColor.color
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    // Colorful icon with gradient background
                    Image.safeSystemName(game.iconSystemName, fallback: "gamecontroller")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            LinearGradient(
                                colors: [
                                    gameColor,
                                    gameColor.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: gameColor.opacity(0.3), radius: 4, y: 2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(game.displayName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        if let lastPlayed = streak?.lastPlayedDate {
                            Text(lastPlayed.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if let lastPlayed = streak?.lastPlayedDate, Calendar.current.isDateInToday(lastPlayed) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                            .transition(.scale.combined(with: .opacity))
                            .opacity(showCheckmark ? 1 : 0)
                            .scaleEffect(showCheckmark ? 1 : 0.5)
                    }
                }
                
                // Streak info
                if let streak = streak, streak.currentStreak > 0 {
                    HStack(spacing: 16) {
                        AnimatedStreakStat(
                            value: "\(streak.currentStreak)",
                            label: "Current",
                            colors: [
                                .orange,
                                .red
                            ]
                        )
                        
                        AnimatedStreakStat(
                            value: "\(streak.maxStreak)",
                            label: "Best",
                            colors: [gameColor, gameColor.opacity(0.8)]
                        )
                        
                        Spacer()
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(gameColor.opacity(colorScheme == .dark ? 0.06 : 0.1))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color(.separator).opacity(colorScheme == .dark ? 0.2 : 0.35), lineWidth: 0.5)
                    }
            }
            .shadow(color: gameColor.opacity(colorScheme == .dark ? 0.15 : 0.2), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
        .modifier(InitialAnimationModifier(hasAppeared: hasInitiallyAppeared, index: animationIndex, totalCount: 10))
        .onAppear {
            let hasPlayedToday = streak?.lastPlayedDate.map { Calendar.current.isDateInToday($0) } ?? false
            if hasPlayedToday && !hasAnimatedCheckmark {
                withAnimation(.easeInOut.delay(Double(animationIndex) * 0.1)) {
                    showCheckmark = true
                }
                hasAnimatedCheckmark = true
            }
        }
    }
}

// MARK: - Enhanced Animated Streak Stat Component
struct AnimatedStreakStat: View {
    let value: String
    let label: String
    let colors: [Color] // Changed from single color to gradient colors
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.caption)
                    .foregroundStyle(
                        LinearGradient(
                            colors: colors,
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                Text(value)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: colors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .contentTransition(.numericText())
            }
            
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
// MARK: - Initial Animation Modifier (Keep for compatibility)
struct InitialAnimationModifier: ViewModifier {
    let hasAppeared: Bool
    let index: Int
    let totalCount: Int
    
    func body(content: Content) -> some View {
        content
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 20)
            .animation(
                .smooth(duration: 0.5)
                .delay(Double(index) * 0.05),
                value: hasAppeared
            )
    }
}


// MARK: - Preview
#Preview {
    VStack(spacing: 16) {
        AnimatedGameCard(
            game: Game.wordle,
            animationIndex: 0,
            hasInitiallyAppeared: true,
            onTap: { print("Tapped") }
        )
        
        AnimatedGameCard(
            game: Game.quordle,
            animationIndex: 1,
            hasInitiallyAppeared: true,
            onTap: { print("Tapped") }
        )
        
        AnimatedGameCard(
            game: Game.nerdle,
            animationIndex: 2,
            hasInitiallyAppeared: true,
            onTap: { print("Tapped") }
        )
    }
    .padding()
    .preferredColorScheme(.dark) // Test in dark mode
    .environment(AppState())
}
