//
//  AchievementUnlockCelebrationView.swift
//  StreakSync
//
//  Full-screen celebration overlay for achievement unlocks
//

import SwiftUI

struct AchievementUnlockCelebrationView: View {
    let unlock: AchievementUnlock
    @State private var isVisible = false
    @State private var phase: CelebrationPhase = .hidden
    @State private var particlesActive = false
    @State private var confettiCounter = 0
    @State private var badgePulse = false
    @Environment(\.dismiss) private var dismiss
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var isAnnouncementFocused: Bool
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    
    var celebrationCoordinator: AchievementCelebrationCoordinator?
    
    private enum CelebrationPhase: Int, Comparable {
        case hidden = 0, dimming, badgeAppearing, badgeScaling
        case particlesBursting, textRevealing, confettiExploding, complete
        
        static func < (lhs: CelebrationPhase, rhs: CelebrationPhase) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
    
    var body: some View {
        if reduceMotion {
            ReducedMotionCelebrationView(unlock: unlock, celebrationCoordinator: celebrationCoordinator)
        } else {
            fullCelebrationView
                .modifier(AccessibilityEnhancedModifier(unlock: unlock, isVisible: phase != .hidden))
        }
    }
    
    // MARK: - Full Celebration View
    private var fullCelebrationView: some View {
        ZStack {
            backgroundDimmer
            
            VStack(spacing: 32) {
                Spacer()
                achievementBadge.scaleEffect(badgeScale).opacity(badgeOpacity)
                achievementText.opacity(textOpacity)
                progressInfo.opacity(progressOpacity)
                Spacer()
                actionButtons.opacity(buttonsOpacity).padding(.bottom, 50)
            }
            .padding()
            
            if particlesActive && !UIAccessibility.isReduceTransparencyEnabled {
                EnhancedParticleSystem(tier: unlock.tier, isActive: $particlesActive)
                    .allowsHitTesting(false)
            }
            
            if !UIAccessibility.isReduceMotionEnabled {
                ConfettiExplosion(counter: $confettiCounter, tier: unlock.tier)
            }
        }
        .statusBarHidden(!voiceOverEnabled)
        .onAppear { startCelebrationSequence() }
    }
    
    // MARK: - Background
    private var backgroundDimmer: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(
                Rectangle().fill(
                    LinearGradient(
                        colors: [unlock.tier.color.opacity(0.15), unlock.tier.color.opacity(0.05)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            )
            .opacity(dimmerOpacity)
            .ignoresSafeArea()
            .onTapGesture { if phase == .complete { dismissCelebration() } }
            .accessibilityHidden(true)
    }
    
    private var safeIconName: String {
        let iconName = unlock.achievement.iconSystemName
        return iconName.isEmpty ? "star.fill" : iconName
    }
    
    // MARK: - Badge
    private var achievementBadge: some View {
        ZStack {
            if !UIAccessibility.isReduceTransparencyEnabled {
                Circle()
                    .fill(RadialGradient(
                        colors: [unlock.tier.color.opacity(0.6), unlock.tier.color.opacity(0.0)],
                        center: .center, startRadius: 0, endRadius: 100
                    ))
                    .frame(width: 250, height: 250)
                    .blur(radius: 20)
                    .scaleEffect(glowScale)
                    .accessibilityHidden(true)
            }
            
            ZStack {
                Circle()
                    .fill(unlock.tier.color.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .scaleEffect(badgePulse ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: badgePulse)
                
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 120, height: 120)
                    .overlay(
                        Circle().stroke(
                            LinearGradient(
                                colors: [unlock.tier.color, unlock.tier.color.opacity(0.5)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ), lineWidth: 3
                        )
                    )
                
                Image.safeSystemName(safeIconName, fallback: "star.fill")
                    .font(.system(size: 50, weight: .medium))
                    .foregroundStyle(unlock.tier.color)
                    .symbolEffect(.bounce, value: phase == .badgeScaling)
                
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
    
    // MARK: - Text
    private var achievementText: some View {
        VStack(spacing: 12) {
            if phase >= .textRevealing {
                if voiceOverEnabled {
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
            
            if phase >= .textRevealing {
                Text(unlock.achievement.displayName)
                    .font(.title.weight(.bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .transition(.scale.combined(with: .opacity))
            }
            
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
            HStack(spacing: 4) {
                Image.compatibleSystemName("chart.line.uptrend.xyaxis")
                    .font(.caption)
                Text("Progress: \(unlock.achievement.progress.currentValue)")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(unlock.tier.color)
            
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
            Capsule().fill(.ultraThinMaterial)
                .overlay(Capsule().stroke(unlock.tier.color.opacity(0.3), lineWidth: 1))
        )
        .accessibilityElement(children: .combine)
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 16) {
            ShareLink(
                item: "I just unlocked \(unlock.tier.displayName) \(unlock.achievement.displayName) in StreakSync! 🎉",
                label: { Label("Share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }
            )
            .buttonStyle(.borderedProminent)
            
            Button { dismissCelebration() } label: {
                Label("Continue", systemImage: "arrow.forward").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Animation Properties
    private var dimmerOpacity: Double { phase >= .dimming ? 0.95 : 0 }
    private var badgeScale: Double {
        switch phase {
        case .hidden: 0
        case .dimming: 0.5
        case .badgeAppearing: 1.2
        default: 1.0
        }
    }
    private var badgeOpacity: Double { phase >= .badgeAppearing ? 1 : 0 }
    private var glowScale: Double { phase == .badgeScaling ? 1.5 : 1.0 }
    private var textOpacity: Double { phase >= .textRevealing ? 1 : 0 }
    private var progressOpacity: Double { phase >= .confettiExploding ? 1 : 0 }
    private var buttonsOpacity: Double { phase == .complete ? 1 : 0 }
    
    // MARK: - Animation Sequence
    private func startCelebrationSequence() {
        Task {
            if UIApplication.shared.applicationState != .active {
                var waited: UInt64 = 0
                while UIApplication.shared.applicationState != .active && waited < 5_000_000_000 {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    waited += 200_000_000
                }
            }

            withAnimation(.easeOut(duration: 0.3)) { phase = .dimming }
            SoundManager.shared.play(.woosh)
            HapticManager.shared.trigger(.achievement)
            
            try? await Task.sleep(nanoseconds: 200_000_000)
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { phase = .badgeAppearing }
            SoundManager.shared.play(.pop)
            badgePulse = true
            
            try? await Task.sleep(nanoseconds: 400_000_000)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                phase = .badgeScaling
                particlesActive = true
            }
            
            try? await Task.sleep(nanoseconds: 300_000_000)
            withAnimation(.easeOut(duration: 0.4)) { phase = .textRevealing }
            if voiceOverEnabled { announceAchievement() }
            
            try? await Task.sleep(nanoseconds: 500_000_000)
            withAnimation(.spring()) {
                phase = .confettiExploding
                confettiCounter += 1
            }
            SoundManager.shared.play(.confetti)
            
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            withAnimation(.easeOut(duration: 0.3)) { phase = .complete }
            SoundManager.shared.play(.success)
            if voiceOverEnabled { announceCompletion() }
            
            let autoDismissEnabled = UserDefaults.standard.bool(forKey: "achievementAutoDismissEnabled")
            if autoDismissEnabled {
                let dismissDelay = voiceOverEnabled ? 8_000_000_000 : 5_000_000_000
                try? await Task.sleep(nanoseconds: UInt64(dismissDelay))
                if UIApplication.shared.applicationState == .active { dismissCelebration() }
            }
        }
    }
    
    // MARK: - VoiceOver
    private func announceAchievement() {
        UIAccessibility.post(notification: .announcement, argument: """
        Congratulations! You've unlocked \(unlock.tier.displayName) tier for \(unlock.achievement.displayName).
        \(unlock.achievement.description).
        Your current progress is \(unlock.achievement.progress.currentValue).
        """)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isAnnouncementFocused = true }
    }
    
    private func announceCompletion() {
        UIAccessibility.post(notification: .announcement, argument: """
        Celebration complete. You can share your achievement or tap continue to dismiss.
        Next tier: \(unlock.achievement.progress.nextTier?.displayName ?? "Maximum tier reached").
        """)
    }
    
    // MARK: - Dismiss
    private func dismissCelebration() {
        withAnimation(.easeIn(duration: 0.3)) { isVisible = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let coordinator = celebrationCoordinator {
                coordinator.dismissCurrentCelebration()
            } else {
                dismiss()
            }
        }
    }
}

#Preview {
    AchievementUnlockCelebrationView(
        unlock: AchievementUnlock(
            achievement: AchievementFactory.createStreakMasterAchievement(),
            tier: .gold,
            timestamp: Date()
        )
    )
}
