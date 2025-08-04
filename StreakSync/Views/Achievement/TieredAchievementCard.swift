//
//  TieredAchievementCard.swift
//  StreakSync
//
//  Visual card component for displaying tiered achievements with progress
//

import SwiftUI

// MARK: - Tiered Achievement Card
struct TieredAchievementCard: View {
    let achievement: TieredAchievement
    let onTap: (() -> Void)?
    
    @State private var isPressed = false
    @State private var showUnlockAnimation = false
    @State private var previousTier: AchievementTier?
    
    // Progress calculation
    private var progressToNextTier: Double {
        guard let nextRequirement = achievement.nextTierRequirement else { return 1.0 }
        
        let currentValue = Double(achievement.progress.currentValue)
        let nextThreshold = Double(nextRequirement.threshold)
        
        // Find the previous tier's threshold
        let previousThreshold: Double = {
            if let currentTier = achievement.progress.currentTier,
               let currentIndex = achievement.requirements.firstIndex(where: { $0.tier == currentTier }),
               currentIndex > 0 {
                return Double(achievement.requirements[currentIndex - 1].threshold)
            }
            return 0
        }()
        
        let progress = (currentValue - previousThreshold) / (nextThreshold - previousThreshold)
        return min(max(progress, 0), 1)
    }
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isPressed.toggle()
            }
            onTap?()
        } label: {
            cardContent
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPressed)
        .onAppear {
            self.checkForTierChange()
        }
        .onChange(of: achievement.progress.currentTier) { oldValue, newValue in
            if oldValue != newValue && newValue != nil {
                self.triggerUnlockAnimation()
            }
        }
    }
    
    private var cardContent: some View {
        VStack(spacing: 0) {
            // Top padding
            Spacer(minLength: 16)
            
            // Centered Achievement Icon
            ZStack {
                // Outer ring for tier indication
                if achievement.progress.currentTier != nil {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    achievement.displayColor,
                                    achievement.displayColor.opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 56, height: 56)
                        .blur(radius: showUnlockAnimation ? 4 : 0)
                }
                
                // Background circle
                Circle()
                    .fill(achievement.displayColor.opacity(0.15))
                    .frame(width: 52, height: 52)
                
                // Icon
                Image(systemName: achievement.iconSystemName)
                    .font(.title)
                    .foregroundStyle(
                        achievement.isUnlocked ?
                        achievement.displayColor :
                        Color(.systemGray3)
                    )
                    .symbolEffect(.bounce, value: showUnlockAnimation)
            }
            
            // Spacing after icon
            Spacer(minLength: 12)
            
            // Title and Description
            VStack(alignment: .center, spacing: 6) {
                Text(achievement.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(achievement.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
            }
            .padding(.horizontal, 8)
            
            // Flexible space
            Spacer(minLength: 8)
            
            // Progress Section with padding
            VStack(spacing: 8) {
                // Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(.systemGray5))
                        
                        // Progress Fill with tier color
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                achievement.isUnlocked ?
                                LinearGradient(
                                    colors: [
                                        achievement.displayColor.opacity(0.8),
                                        achievement.displayColor
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ) :
                                LinearGradient(
                                    colors: [
                                        Color.orange.opacity(0.8),
                                        Color.orange
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * progressToNextTier)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progressToNextTier)
                    }
                }
                .frame(height: 6)
                
                // Progress Text with tier icon
                HStack {
                    Text(achievement.progressDescription)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                    
                    Spacer()
                    
                    // Trophy showing NEXT tier to achieve
                    if let nextTier = achievement.progress.nextTier {
                        // Show next tier in its color
                        Image(systemName: nextTier.iconSystemName)  // ← Uses tier's specific icon
                            .font(.caption)
                            .foregroundStyle(nextTier.color)
                    } else if achievement.progress.currentTier == .legendary {
                        // Max tier reached - show legendary in gold
                        Image(systemName: "trophy.fill")
                            .font(.caption)
                            .foregroundStyle(Color.yellow)
                    } else {
                        // No progress yet - show bronze as first goal
                        Image(systemName: "trophy.fill")
                            .font(.caption)
                            .foregroundStyle(AchievementTier.bronze.color)
                    }
                }
            }
            .padding(.horizontal, 16)
            
            // Bottom padding
            Spacer(minLength: 16)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                // Glass background
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                
                // Subtle tier-specific glow for unlocked achievements
                if let currentTier = achievement.progress.currentTier {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            currentTier.color.opacity(0.15),
                            lineWidth: 1
                        )
                        .blur(radius: 1)
                }
            }
        )
        .overlay(
            // Unlock animation particles
            Group {
                if showUnlockAnimation {
                    UnlockParticlesView(color: achievement.displayColor)
                }
            }
        )
    }
    
    // Rest of the code remains the same...
    private func checkForTierChange() {
        previousTier = achievement.progress.currentTier
    }
    
    private func triggerUnlockAnimation() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
            showUnlockAnimation = true
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Reset animation after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showUnlockAnimation = false
            }
        }
    }
}

// UnlockParticlesView remains the same...
struct UnlockParticlesView: View {
    let color: Color
    @State private var particles: [Particle] = []
    
    struct Particle: Identifiable {
        let id = UUID()
        var position: CGPoint
        var velocity: CGVector
        var scale: CGFloat
        var opacity: Double
    }
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(particles) { particle in
                Circle()
                    .fill(color)
                    .frame(width: 6 * particle.scale, height: 6 * particle.scale)
                    .opacity(particle.opacity)
                    .position(particle.position)
            }
        }
        .onAppear {
            createParticles()
        }
    }
    
    private func createParticles() {
        for _ in 0..<12 {
            let angle = Double.random(in: 0...(2 * .pi))
            let speed = Double.random(in: 50...100)
            
            let particle = Particle(
                position: CGPoint(x: 40, y: 40), // Start from icon position
                velocity: CGVector(
                    dx: cos(angle) * speed,
                    dy: sin(angle) * speed
                ),
                scale: CGFloat.random(in: 0.5...1.5),
                opacity: 1.0
            )
            particles.append(particle)
        }
        
        // Animate particles
        withAnimation(.easeOut(duration: 1.5)) {
            for index in particles.indices {
                particles[index].position.x += particles[index].velocity.dx
                particles[index].position.y += particles[index].velocity.dy
                particles[index].opacity = 0
                particles[index].scale *= 0.3
            }
        }
        
        // Clean up
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            particles.removeAll()
        }
    }
}
