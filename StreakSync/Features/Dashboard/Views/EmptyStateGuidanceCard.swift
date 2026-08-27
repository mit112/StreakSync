//
//  EmptyStateGuidanceCard.swift
//  StreakSync
//
//  Friendly onboarding card for users with no active streaks
//

import SwiftUI

struct EmptyStateGuidanceCard: View {
    let isReturningUser: Bool // Has played games before
    let onDismiss: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isVisible = false
    
    private var cardContent: (icon: String, title: String, message: String) {
        if isReturningUser {
            return (
                icon: "arrow.clockwise",
                title: "Reignite Your Streaks!",
                message: "Play a quick game. Tap Share inside the game, then pick StreakSync to log it."
            )
        } else {
            return (
                icon: "sparkles",
                title: "Start Your First Streak!",
                message: "Finish a Wordle. Tap Share inside the game, then pick StreakSync."
            )
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            ZStack {
                if isReturningUser {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image.safeSystemName(cardContent.icon, fallback: "questionmark.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.blue)
                } else {
                    StreakSyncBrandMark(size: 40, showsBackground: false, accessibilityLabel: nil)
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(cardContent.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Text(cardContent.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    // Height gate (audit item 9): at accessibility sizes this tip's copy
                    // otherwise wraps unbounded and pushes "Your Games" and the whole game
                    // list below the fold. It's a dismissible, supplementary tip, so cap
                    // it and let it scale slightly rather than let it own the viewport.
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : nil)
                    .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 0.8 : 1)
            }
            
            Spacer(minLength: 8)
            
            // Dismiss button
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isVisible = false
                }

                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(300))
                    onDismiss()
                }

                HapticManager.shared.trigger(.buttonTap)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.tertiary)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .minTapTarget()
            .accessibilityLabel("Dismiss tip")
        }
        .padding(16)
        // Shared card chrome — same hairline surface as the game cards, and drops the
        // resting drop shadow the audit flagged (§5.1 / §7.2 / §7 #2).
        .cardStyle()
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.9, anchor: .top)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.2)) {
                isVisible = true
            }
        }
    }
}

// MARK: - Preview
#Preview("New User") {
    VStack(spacing: 20) {
        EmptyStateGuidanceCard(isReturningUser: false) {
            // preview action
        }
        .padding()
        
        Spacer()
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Returning User") {
    VStack(spacing: 20) {
        EmptyStateGuidanceCard(isReturningUser: true) {
            // preview action
        }
        .padding()
        
        Spacer()
    }
    .background(Color(.systemGroupedBackground))
}
