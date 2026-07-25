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
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint("Double tap to dismiss")
            .accessibilityAddTraits(.isModal)
            .accessibilityAction {
                dismiss()
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
        Task {
            try? await Task.sleep(nanoseconds: UInt64(0.5 * 1_000_000_000))
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

    // Batch progress mirrors the full celebration view (DESIGN_AUDIT §4.10) so
    // Reduce Motion users also see "N of M" and get a Skip-all escape hatch.
    private var celebrationTotal: Int { celebrationCoordinator?.celebrationTotal ?? 0 }
    private var celebrationIndex: Int { celebrationCoordinator?.celebrationIndex ?? 0 }
    private var isBatch: Bool { celebrationTotal > 1 }

    var body: some View {
        ZStack {
            // Simple fade background
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .opacity(opacity)

            // Content without animations
            VStack(spacing: 24) {
                if isBatch {
                    Text("\(celebrationIndex) of \(celebrationTotal)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.regularMaterial))
                        .accessibilityLabel("Achievement \(celebrationIndex) of \(celebrationTotal)")
                }

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
                
                // Dismiss button(s)
                VStack(spacing: 12) {
                    Button(isBatch ? "Next" : "Continue") {
                        dismissCelebration()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    if isBatch {
                        Button("Skip all") {
                            celebrationCoordinator?.dismissAll()
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.sheet)
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
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(0.3 * 1_000_000_000))
            // Check if we have a coordinator
            if let coordinator = celebrationCoordinator {
                coordinator.dismissCurrentCelebration()
            } else {
                dismiss()
            }
        }
    }
}
