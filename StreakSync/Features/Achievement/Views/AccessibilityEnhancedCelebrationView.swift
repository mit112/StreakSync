//
//  AccessibilityEnhancedCelebrationView.swift
//  StreakSync
//
//  Accessibility enhancements for achievement celebrations
//

import SwiftUI

// MARK: - Accessibility Enhanced Celebration Modifier
struct AccessibilityEnhancedModifier: ViewModifier {
    @AccessibilityFocusState private var isAnnouncementFocused: Bool
    let unlock: AchievementUnlock
    let isVisible: Bool
    
    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint("Double tap to dismiss")
            .accessibilityAddTraits(.isModal)
            .accessibilityAction {
                // Dismiss action
            }
            .onChange(of: isVisible) { _, visible in
                if visible {
                    announceUnlock()
                }
            }
    }
    
    private var accessibilityLabel: String {
        """
        Congratulations! You've unlocked \(unlock.tier.displayName) tier for \(unlock.achievement.displayName).
        \(unlock.achievement.description).
        Your current progress is \(unlock.achievement.progress.currentValue).
        """
    }
    
    private func announceUnlock() {
        // Post accessibility announcement
        UIAccessibility.post(
            notification: .announcement,
            argument: "Achievement unlocked! \(unlock.tier.displayName) \(unlock.achievement.displayName)"
        )
        
        // Focus on the announcement
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isAnnouncementFocused = true
        }
    }
}

// MARK: - Reduced Motion Alternative View
struct ReducedMotionCelebrationView: View {
    let unlock: AchievementUnlock
    var celebrationCoordinator: AchievementCelebrationCoordinator?
    
    @Environment(\.dismiss) private var dismiss
    @State private var opacity: Double = 0
    
    private var safeIconName: String {
        let iconName = unlock.achievement.iconSystemName
        return iconName.isEmpty ? "star.fill" : iconName
    }
    
    var body: some View {
        ZStack {
            // Simple fade background
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .opacity(opacity)
            
            // Content without animations
            VStack(spacing: 24) {
                // Icon
                Image.safeSystemName(safeIconName, fallback: "star.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(unlock.tier.color)
                
                // Text
                VStack(spacing: 12) {
                    Text("\(unlock.tier.displayName) Unlocked!")
                        .font(.title2.bold())
                        .foregroundStyle(unlock.tier.color)
                    
                    Text(unlock.achievement.displayName)
                        .font(.title3)
                    
                    Text(unlock.achievement.description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Dismiss button
                Button("Continue") {
                    dismissCelebration()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.regularMaterial)
            )
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.3)) {
                opacity = 1
            }
            
            // Play sound
            SoundManager.shared.play(.achievementUnlock)
            
            // Haptic
            HapticManager.shared.trigger(.achievement)
        }
    }
    
    private func dismissCelebration() {
        withAnimation(.easeOut(duration: 0.3)) {
            opacity = 0
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
