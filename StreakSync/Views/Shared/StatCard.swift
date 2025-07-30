//
//  StatCard.swift
//  StreakSync
//
//  Reusable stat card component for displaying metrics
//

import SwiftUI

// MARK: - Generic Stat Card
struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let gradient: LinearGradient
    let action: (() -> Void)?
    
    @State private var isPressed = false
    
    init(
        icon: String,
        value: String,
        label: String,
        gradient: LinearGradient,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.value = value
        self.label = label
        self.gradient = gradient
        self.action = action
    }
    
    // Convenience initializers for common stat types
    static func activeStreaks(_ count: Int, action: (() -> Void)? = nil) -> StatCard {
        StatCard(
            icon: "flame.fill",
            value: "\(count)",
            label: "Active",
            gradient: LinearGradient(
                colors: [Color.orange, Color.red],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            action: action
        )
    }
    
    static func todayCompleted(_ count: Int, action: (() -> Void)? = nil) -> StatCard {
        StatCard(
            icon: "checkmark.circle.fill",
            value: "\(count)",
            label: "Today",
            gradient: LinearGradient(
                colors: [Color.green, Color.mint],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            action: action
        )
    }
    
    static func totalGames(_ count: Int, action: (() -> Void)? = nil) -> StatCard {
        StatCard(
            icon: "gamecontroller.fill",
            value: "\(count)",
            label: "Games",
            gradient: LinearGradient(
                colors: [Color.blue, Color.purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            action: action
        )
    }
    
    var body: some View {
        Button {
            if let action = action {
                action()
            } else {
                // Default animation when no action
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    isPressed.toggle()
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(gradient)
                    .symbolEffect(.bounce, value: isPressed)
                
                VStack(alignment: .leading, spacing: 0) {
                    Text(value)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                    
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                gradient.opacity(0.3),
                                lineWidth: 1
                            )
                    )
            )
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPressed)
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Enhanced Quick Stat Pill (Legacy wrapper for compatibility)
struct EnhancedQuickStatPill: View {
    let icon: String
    let value: String
    let label: String
    let gradient: LinearGradient
    let hasAppeared: Bool
    let animationIndex: Int
    
    var body: some View {
        StatCard(
            icon: icon,
            value: value,
            label: label,
            gradient: gradient
        )
        .modifier(InitialAnimationModifier(
            hasAppeared: hasAppeared,
            index: animationIndex,
            totalCount: 4
        ))
    }
}

// MARK: - Stat Card Row
struct StatCardRow: View {
    let stats: [(icon: String, value: String, label: String, gradient: LinearGradient)]
    let hasAppeared: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            ForEach(Array(stats.enumerated()), id: \.offset) { index, stat in
                StatCard(
                    icon: stat.icon,
                    value: stat.value,
                    label: stat.label,
                    gradient: stat.gradient
                )
                .modifier(InitialAnimationModifier(
                    hasAppeared: hasAppeared,
                    index: index + 2,
                    totalCount: stats.count + 2
                ))
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        // Individual stat cards
        HStack(spacing: 16) {
            StatCard.activeStreaks(5)
            StatCard.todayCompleted(3)
            StatCard.totalGames(12)
        }
        .padding()
        
        // Using StatCardRow
        StatCardRow(
            stats: [
                ("flame.fill", "8", "Streak", LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)),
                ("trophy.fill", "15", "Awards", LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
            ],
            hasAppeared: true
        )
        .padding()
    }
    .background(Color(.systemBackground))
}