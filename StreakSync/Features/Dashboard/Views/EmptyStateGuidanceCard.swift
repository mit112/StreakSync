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
    @Environment(\.colorScheme) private var colorScheme
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
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image.safeSystemName(cardContent.icon, fallback: "questionmark.circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.blue)
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
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                        // One neutral hairline, not a blue→purple gradient border (§5.1).
                        .strokeBorder(Color(.separator), lineWidth: 1)
                }
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08),
                       radius: 12, x: 0, y: 4)
        }
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
