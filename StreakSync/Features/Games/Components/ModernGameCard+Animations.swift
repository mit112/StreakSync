//
//  ModernGameCard+Animations.swift
//  StreakSync
//
//  Enhanced animations for game cards
//

import SwiftUI

extension ModernGameCard {
    // Add this to the ModernGameCard's favorite button
    var animatedFavoriteButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                onFavoriteToggle?()
            }
        }) {
            Image(systemName: isFavorite ? "star.fill" : "star")
                .font(.caption)
                .foregroundStyle(isFavorite ? .yellow : .secondary)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(
                    .bounce.up,
                    options: .nonRepeating,
                    value: isFavorite
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Animated Progress Component
struct AnimatedProgressBar: View {
    let progress: Double
    let color: Color
    
    @State private var animatedProgress: Double = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Capsule()
                    .fill(Color(.quaternarySystemFill))
                    .frame(height: 6)
                
                // Animated progress
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: geometry.size.width * min(animatedProgress, 1.0),
                        height: 6
                    )
            }
        }
        .frame(height: 6)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Celebration View for Achievements
struct AchievementCelebration: View {
    let achievement: TieredAchievement
    let tier: AchievementTier
    @State private var showParticles = false
    @State private var scale = 0.5
    @State private var opacity = 0.0
    
    var body: some View {
        ZStack {
            // Particle effects
            if showParticles {
                ForEach(0..<12, id: \.self) { index in
                    ParticleView(
                        color: tier.color,
                        delay: Double(index) * 0.05
                    )
                }
            }
            
            // Achievement badge
            VStack(spacing: 16) {
                Image(systemName: achievement.iconSystemName)
                    .font(.system(size: 64))
                    .foregroundStyle(tier.color)
                    .symbolEffect(.bounce.up, options: .nonRepeating)
                
                VStack(spacing: 8) {
                    Text(tier.displayName)
                        .font(.headline)
                        .foregroundStyle(tier.color)
                    
                    Text(achievement.displayName)
                        .font(.title2.weight(.bold))
                    
                    Text(achievement.description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
            
            withAnimation(.easeOut(duration: 0.3)) {
                showParticles = true
            }
        }
    }
}

// MARK: - Particle View
private struct ParticleView: View {
    let color: Color
    let delay: Double
    
    @State private var offset = CGSize.zero
    @State private var opacity = 1.0
    @State private var scale = 1.0
    
    private let randomAngle = Double.random(in: 0...360)
    private let randomDistance = Double.random(in: 100...200)
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(offset)
            .onAppear {
                let radians = randomAngle * .pi / 180
                let x = cos(radians) * randomDistance
                let y = sin(radians) * randomDistance
                
                withAnimation(.easeOut(duration: 1.5).delay(delay)) {
                    offset = CGSize(width: x, height: y)
                    opacity = 0
                    scale = 0.3
                }
            }
    }
}
