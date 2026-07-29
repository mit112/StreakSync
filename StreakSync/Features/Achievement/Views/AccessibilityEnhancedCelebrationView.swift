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

            // Content without animations. It scrolls and the dismiss controls own a
            // reserved strip below it, matching the full celebration so Accessibility XL
            // copy is never truncated or hidden behind the buttons (DESIGN_AUDIT §4.2).
            VStack(spacing: 0) {
                GeometryReader { proxy in
                    ScrollView {
                        celebrationCard
                            .frame(minHeight: proxy.size.height, alignment: .center)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }

                dismissControls
            }
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

    // MARK: - Card
    private var celebrationCard: some View {
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
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(unlock.achievement.displayName)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(unlock.achievement.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.sheet)
                .fill(.regularMaterial)
        )
    }

    // MARK: - Dismiss Controls
    /// Keeps its own material behind it: the controls now sit on the dimmed backdrop
    /// rather than inside the card, and `.secondary` on bare black is unreadable in
    /// light appearance (DESIGN_AUDIT §4.10).
    private var dismissControls: some View {
        VStack(spacing: 12) {
            Button(isBatch ? "Next" : "Continue", action: dismissCelebration)
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
        .padding(.horizontal)
        .padding(.vertical, Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
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
