//
//  AchievementUnlockCelebrationView.swift
//  StreakSync
//
//  Full-screen celebration overlay for achievement unlocks
//

import SwiftUI

// MARK: - Achievement Unlock Celebration View
struct AchievementUnlockCelebrationView: View {
    let unlock: AchievementUnlock
    @State private var isVisible = false
    @State private var phase: CelebrationPhase = .hidden
    @State private var particlesActive = false
    @State private var confettiCounter = 0
    @State private var badgePulse = false
    @Environment(\.dismiss) private var dismiss
    
    // Accessibility
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var isAnnouncementFocused: Bool
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    
    // Make coordinator optional since it might not always be available
    var celebrationCoordinator: AchievementCelebrationCoordinator?
    
    private enum CelebrationPhase: Int, Comparable {
        case hidden = 0
        case dimming = 1
        case badgeAppearing = 2
        case badgeScaling = 3
        case particlesBursting = 4
        case textRevealing = 5
        case confettiExploding = 6
        case complete = 7
        
        static func < (lhs: CelebrationPhase, rhs: CelebrationPhase) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
    
    var body: some View {
        if reduceMotion {
            ReducedMotionCelebrationView(unlock: unlock, celebrationCoordinator: celebrationCoordinator)
        } else {
            fullCelebrationView
                .modifier(AccessibilityEnhancedModifier(
                    unlock: unlock,
                    isVisible: phase != .hidden
                ))
        }
    }
    
    // MARK: - Full Celebration View
    private var fullCelebrationView: some View {
        ZStack {
            // Background dimming
            backgroundDimmer
            
            // Main celebration content
            VStack(spacing: 32) {
                Spacer()
                
                // Achievement badge
                achievementBadge
                    .scaleEffect(badgeScale)
                    .opacity(badgeOpacity)
                
                // Achievement text
                achievementText
                    .opacity(textOpacity)
                
                // Progress info
                progressInfo
                    .opacity(progressOpacity)
                
                Spacer()
                
                // Action buttons
                actionButtons
                    .opacity(buttonsOpacity)
                    .padding(.bottom, 50)
            }
            .padding()
            
            // Particle effects layer
            if particlesActive && !UIAccessibility.isReduceTransparencyEnabled {
                EnhancedParticleSystem(
                    tier: unlock.tier,
                    isActive: $particlesActive
                )
                .allowsHitTesting(false)
            }
            
            // Confetti layer
            if !UIAccessibility.isReduceMotionEnabled {
                ConfettiExplosion(
                    counter: $confettiCounter,
                    tier: unlock.tier
                )
            }
        }
        .statusBarHidden(!voiceOverEnabled) // Keep status bar for VoiceOver
        .onAppear {
            startCelebrationSequence()
        }
    }
    
    // MARK: - Background Dimmer
    private var backgroundDimmer: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(
                // Tier-specific color overlay
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                unlock.tier.color.opacity(0.15),
                                unlock.tier.color.opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .opacity(dimmerOpacity)
            .ignoresSafeArea()
            .onTapGesture {
                if phase == .complete {
                    dismissCelebration()
                }
            }
            .accessibilityHidden(true) // Background is decorative
    }
    
    private var safeIconName: String {
        let iconName = unlock.achievement.iconSystemName
        return iconName.isEmpty ? "star.fill" : iconName
    }
    
    // MARK: - Achievement Badge
    private var achievementBadge: some View {
        ZStack {
            // Glow effect
            if !UIAccessibility.isReduceTransparencyEnabled {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                unlock.tier.color.opacity(0.6),
                                unlock.tier.color.opacity(0.0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 100
                        )
                    )
                    .frame(width: 250, height: 250)
                    .blur(radius: 20)
                    .scaleEffect(glowScale)
                    .accessibilityHidden(true)
            }
            
            // Badge container
            ZStack {
                // Background circle with tier color
                Circle()
                    .fill(unlock.tier.color.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .scaleEffect(badgePulse ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: badgePulse)
                
                // Glass effect circle
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 120, height: 120)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        unlock.tier.color,
                                        unlock.tier.color.opacity(0.5)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                    )
                
                // Achievement icon
                Image.safeSystemName(safeIconName, fallback: "star.fill")
                    .font(.system(size: 50, weight: .medium))
                    .foregroundStyle(unlock.tier.color)
                    .symbolEffect(.bounce, value: phase == .badgeScaling)
                
                // Tier badge overlay
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        TierMiniatureBadge(tier: unlock.tier)
                            .scaleEffect(1.2)
                            .offset(x: 10, y: 10)
                    }
                }
                .frame(width: 120, height: 120)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(unlock.tier.displayName) tier badge for \(unlock.achievement.displayName)")
    }
    
    // MARK: - Achievement Text (Enhanced with Typewriter)
    private var achievementText: some View {
        VStack(spacing: 12) {
            // Tier unlock label with typewriter effect
            if phase >= .textRevealing {
                if voiceOverEnabled {
                    // Simple text for VoiceOver
                    Text("\(unlock.tier.displayName) Unlocked!")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(unlock.tier.color)
                        .textCase(.uppercase)
                        .tracking(1.5)
                } else {
                    TypewriterText(
                        "\(unlock.tier.displayName) Unlocked!",
                        font: .caption.weight(.semibold),
                        color: unlock.tier.color,
                        characterDelay: 0.05
                    )
                    .textCase(.uppercase)
                    .tracking(1.5)
                }
            }
            
            // Achievement name
            if phase >= .textRevealing {
                Text(unlock.achievement.displayName)
                    .font(.title.weight(.bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .transition(.scale.combined(with: .opacity))
            }
            
            // Achievement description with fade in
            if phase >= .textRevealing {
                Text(unlock.achievement.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
                    .transition(.opacity.animation(.easeIn(duration: 0.5).delay(0.3)))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityFocused($isAnnouncementFocused)
    }
    
    // MARK: - Progress Info
    private var progressInfo: some View {
        VStack(spacing: 8) {
            // Progress value
            HStack(spacing: 4) {
                Image.compatibleSystemName("chart.line.uptrend.xyaxis")
                    .font(.caption)
                Text("Progress: \(unlock.achievement.progress.currentValue)")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(unlock.tier.color)
            
            // Next tier hint
            if let nextTier = unlock.achievement.progress.nextTier,
               let nextRequirement = unlock.achievement.nextTierRequirement {
                Text("Next: \(nextTier.displayName) at \(nextRequirement.threshold)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(unlock.tier.color.opacity(0.3), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 16) {
            // Share button
            ShareLink(
                item: "I just unlocked \(unlock.tier.displayName) \(unlock.achievement.displayName) in StreakSync! 🎉",
                label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
            )
            .buttonStyle(GlassButton(isProminent: true))
            
            // Continue button
            Button {
                dismissCelebration()
            } label: {
                Label("Continue", systemImage: "arrow.forward")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(GlassButton())
        }
        .padding(.horizontal)
    }
    
    // MARK: - Animation Properties
    private var dimmerOpacity: Double {
        phase >= .dimming ? 0.95 : 0
    }
    
    private var badgeScale: Double {
        switch phase {
        case .hidden: return 0
        case .dimming: return 0.5
        case .badgeAppearing: return 1.2
        case .badgeScaling, .particlesBursting, .textRevealing, .confettiExploding, .complete: return 1.0
        }
    }
    
    private var badgeOpacity: Double {
        phase >= .badgeAppearing ? 1 : 0
    }
    
    private var glowScale: Double {
        phase == .badgeScaling ? 1.5 : 1.0
    }
    
    private var textOpacity: Double {
        phase >= .textRevealing ? 1 : 0
    }
    
    private var progressOpacity: Double {
        phase >= .confettiExploding ? 1 : 0
    }
    
    private var buttonsOpacity: Double {
        phase == .complete ? 1 : 0
    }
    
    // MARK: - Animation Sequence
    private func startCelebrationSequence() {
        Task {
            // Start dimming
            withAnimation(.easeOut(duration: 0.3)) {
                phase = .dimming
            }
            
            // Sound effect
            SoundManager.shared.play(.woosh)
            
            // Haptic feedback
            HapticManager.shared.trigger(.achievement)
            
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
            
            // Badge appears with sound
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                phase = .badgeAppearing
            }
            SoundManager.shared.play(.pop)
            
            // Start pulse animation
            badgePulse = true
            
            try? await Task.sleep(nanoseconds: 400_000_000) // 0.4s
            
            // Badge scales and particles burst
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                phase = .badgeScaling
                particlesActive = true
            }
            
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
            
            // Text reveals
            withAnimation(.easeOut(duration: 0.4)) {
                phase = .textRevealing
            }
            
            // VoiceOver announcement
            if voiceOverEnabled {
                announceAchievement()
            }
            
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            
            // Confetti explodes with sound
            withAnimation(.spring()) {
                phase = .confettiExploding
                confettiCounter += 1
            }
            SoundManager.shared.play(.confetti)
            
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s
            
            // Show action buttons with success sound
            withAnimation(.easeOut(duration: 0.3)) {
                phase = .complete
            }
            SoundManager.shared.play(.success)
            
            // VoiceOver announcement for completion
            if voiceOverEnabled {
                announceCompletion()
            }
            
            // Auto-dismiss after delay (increased for VoiceOver)
            let dismissDelay = voiceOverEnabled ? 8_000_000_000 : 5_000_000_000
            try? await Task.sleep(nanoseconds: UInt64(dismissDelay))
            dismissCelebration()
        }
    }
    
    // MARK: - VoiceOver Announcements
    private func announceAchievement() {
        let announcement = """
        Congratulations! You've unlocked \(unlock.tier.displayName) tier for \(unlock.achievement.displayName).
        \(unlock.achievement.description).
        Your current progress is \(unlock.achievement.progress.currentValue).
        """
        
        UIAccessibility.post(
            notification: .announcement,
            argument: announcement
        )
        
        // Focus on the text
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isAnnouncementFocused = true
        }
    }
    
    private func announceCompletion() {
        let announcement = """
        Celebration complete. You can share your achievement or tap continue to dismiss.
        Next tier: \(unlock.achievement.progress.nextTier?.displayName ?? "Maximum tier reached").
        """
        
        UIAccessibility.post(
            notification: .announcement,
            argument: announcement
        )
    }
    
    // MARK: - Dismiss
    private func dismissCelebration() {
        withAnimation(.easeIn(duration: 0.3)) {
            isVisible = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Check if we have a coordinator
            if let coordinator = celebrationCoordinator {
                coordinator.dismissCurrentCelebration()
            } else {
                dismiss()
            }
        }
    }
}

// MARK: - Tier Miniature Badge
private struct TierMiniatureBadge: View {
    let tier: AchievementTier
    
    var body: some View {
        ZStack {
            Circle()
                .fill(tier.color)
                .frame(width: 32, height: 32)
            
            Image.safeSystemName(tier.iconSystemName, fallback: "trophy.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
        }
        .shadow(color: tier.color.opacity(0.5), radius: 4, x: 0, y: 2)
        .accessibilityHidden(true) // Decorative element
    }
}

// MARK: - Enhanced Particle System
private struct EnhancedParticleSystem: View {
    let tier: AchievementTier
    @Binding var isActive: Bool
    @State private var particles: [Particle] = []
    
    struct Particle: Identifiable {
        let id = UUID()
        var position: CGPoint
        var velocity: CGVector
        var scale: CGFloat
        var opacity: Double
        var rotation: Double
        let shape: ParticleShape
        
        enum ParticleShape: CaseIterable {
            case circle, star, plus, diamond
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(particles) { particle in
                ParticleView(particle: particle, color: tier.color)
                    .position(particle.position)
                    .scaleEffect(particle.scale)
                    .opacity(particle.opacity)
                    .rotationEffect(Angle(degrees: particle.rotation))
            }
        }
        .onAppear {
            createParticles()
            animateParticles()
        }
        .accessibilityHidden(true) // Decorative animation
    }
    
    private func createParticles() {
        let centerX = UIScreen.main.bounds.width / 2
        let centerY = UIScreen.main.bounds.height / 2
        
        // Reduce particle count for older devices
        let particleCount = ProcessInfo.processInfo.processorCount > 4 ? 30 : 15
        
        for _ in 0..<particleCount {
            let angle = Double.random(in: 0...(2 * .pi))
            let speed = Double.random(in: 100...300)
            
            let particle = Particle(
                position: CGPoint(x: centerX, y: centerY),
                velocity: CGVector(
                    dx: cos(angle) * speed,
                    dy: sin(angle) * speed
                ),
                scale: CGFloat.random(in: 0.5...1.5),
                opacity: 1.0,
                rotation: Double.random(in: 0...360),
                shape: Particle.ParticleShape.allCases.randomElement()!
            )
            particles.append(particle)
        }
    }
    
    private func animateParticles() {
        withAnimation(.easeOut(duration: 2.0)) {
            for index in particles.indices {
                particles[index].position.x += particles[index].velocity.dx
                particles[index].position.y += particles[index].velocity.dy
                particles[index].opacity = 0
                particles[index].scale *= 0.3
                particles[index].rotation += Double.random(in: -180...180)
            }
        }
        
        // Clean up
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isActive = false
        }
    }
}

// MARK: - Particle View
private struct ParticleView: View {
    let particle: EnhancedParticleSystem.Particle
    let color: Color
    
    var body: some View {
        Group {
            switch particle.shape {
            case .circle:
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
            case .star:
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(color)
            case .plus:
                Image(systemName: "plus")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(color)
            case .diamond:
                Image.compatibleSystemName("diamond.fill")
                    .font(.caption2)
                    .foregroundStyle(color)
            }
        }
    }
}

// MARK: - Confetti Explosion
private struct ConfettiExplosion: View {
    @Binding var counter: Int
    let tier: AchievementTier
    @State private var confettiPieces: [ConfettiPiece] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    struct ConfettiPiece: Identifiable {
        let id = UUID()
        var position: CGPoint
        var velocity: CGVector
        var rotation: Double
        var scale: CGFloat
        var opacity: Double
        let color: Color
        let shape: ShapeType
        
        enum ShapeType: CaseIterable {
            case rectangle, circle, triangle
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(confettiPieces) { piece in
                ConfettiShapeView(shape: piece.shape, color: piece.color)
                    .frame(width: 10, height: 10)
                    .scaleEffect(piece.scale)
                    .rotationEffect(Angle(degrees: piece.rotation))
                    .position(piece.position)
                    .opacity(piece.opacity)
            }
        }
        .onChange(of: counter) { _, _ in
            if !reduceMotion {
                createConfetti()
                animateConfetti()
            }
        }
        .accessibilityHidden(true) // Decorative animation
    }
    
    private func createConfetti() {
        confettiPieces.removeAll()
        
        // Reduce confetti count for performance
        let confettiCount = ProcessInfo.processInfo.processorCount > 4 ? 100 : 50
        
        let colors: [Color] = [
            tier.color,
            tier.color.opacity(0.8),
            .white,
            .yellow,
            .orange
        ]
        
        let centerX = UIScreen.main.bounds.width / 2
        let topY = UIScreen.main.bounds.height * 0.3
        
        for _ in 0..<confettiCount {
            let angle = Double.random(in: -(.pi/3)...(.pi/3)) - .pi/2
            let speed = Double.random(in: 200...500)
            
            let confetti = ConfettiPiece(
                position: CGPoint(x: centerX, y: topY),
                velocity: CGVector(
                    dx: cos(angle) * speed,
                    dy: sin(angle) * speed
                ),
                rotation: Double.random(in: 0...360),
                scale: CGFloat.random(in: 0.8...1.2),
                opacity: 1.0,
                color: colors.randomElement()!,
                shape: ConfettiPiece.ShapeType.allCases.randomElement()!
            )
            confettiPieces.append(confetti)
        }
    }
    
    private func animateConfetti() {
        // Initial burst
        withAnimation(.easeOut(duration: 0.5)) {
            for index in confettiPieces.indices {
                confettiPieces[index].position.x += confettiPieces[index].velocity.dx * 0.3
                confettiPieces[index].position.y += confettiPieces[index].velocity.dy * 0.3
            }
        }
        
        // Gravity fall
        withAnimation(.easeIn(duration: 2.5).delay(0.5)) {
            for index in confettiPieces.indices {
                confettiPieces[index].position.y = UIScreen.main.bounds.height + 50
                confettiPieces[index].rotation += Double.random(in: -720...720)
                confettiPieces[index].opacity = 0.8
            }
        }
        
        // Clean up
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            confettiPieces.removeAll()
        }
    }
}

// MARK: - Confetti Shape View
private struct ConfettiShapeView: View {
    let shape: ConfettiExplosion.ConfettiPiece.ShapeType
    let color: Color
    
    var body: some View {
        switch shape {
        case .rectangle:
            Rectangle()
                .fill(color)
        case .circle:
            Circle()
                .fill(color)
        case .triangle:
            Triangle()
                .fill(color)
        }
    }
}

// MARK: - Triangle Shape
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview
#Preview {
    AchievementUnlockCelebrationView(
        unlock: AchievementUnlock(
            achievement: AchievementFactory.createStreakMasterAchievement(),
            tier: .gold,
            timestamp: Date()
        )
    )
}
