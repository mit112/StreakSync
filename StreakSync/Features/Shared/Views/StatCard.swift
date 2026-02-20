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
    let gradientColors: [Color] // Store colors instead of gradient
    let action: (() -> Void)?
    
    @State private var isPressed = false
    @Environment(\.colorScheme) private var colorScheme
    
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
        // For backward compatibility, we'll store placeholder colors
        self.gradientColors = [Color.blue, Color.purple]
        self.action = action
    }
    
    // New initializer that takes colors directly
    init(
        icon: String,
        value: String,
        label: String,
        colors: [Color],
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.value = value
        self.label = label
        self.gradientColors = colors
        self.action = action
    }
    
    // Convenience initializers using palette colors
    static func activeStreaks(_ count: Int, action: (() -> Void)? = nil) -> StatCard {
        StatCard(
            icon: "flame.fill",
            value: "\(count)",
            label: "Active",
            colors: [PaletteColor.secondary.color, PaletteColor.primary.color],
            action: action
        )
    }
    
    static func todayCompleted(_ count: Int, action: (() -> Void)? = nil) -> StatCard {
        StatCard(
            icon: "checkmark.circle.fill",
            value: "\(count)",
            label: "Today",
            colors: [PaletteColor.primary.color],
            action: action
        )
    }
    
    static func totalGames(_ count: Int, action: (() -> Void)? = nil) -> StatCard {
        StatCard(
            icon: "gamecontroller.fill",
            value: "\(count)",
            label: "Games",
            colors: [PaletteColor.textSecondary.color, PaletteColor.cardBackground.color],
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
                Image.safeSystemName(icon, fallback: "chart.bar")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(adaptedGradient)
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
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                adaptedGradient.opacity(0.3),
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
    
    // Create gradient with adapted colors for current color scheme
    private var adaptedGradient: LinearGradient {
        let adaptedColors = gradientColors.map { color in
            adaptColorForScheme(color)
        }
        
        return LinearGradient(
            colors: adaptedColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // Adapt individual colors to color scheme
    private func adaptColorForScheme(_ color: Color) -> Color {
        // Check if this is one of our palette colors and adapt accordingly
        if color == PaletteColor.primary.color {
            return colorScheme == .dark ? PaletteColor.primary.darkVariant : PaletteColor.primary.color
        } else if color == PaletteColor.secondary.color {
            return colorScheme == .dark ? PaletteColor.secondary.darkVariant : PaletteColor.secondary.color
        } else if color == PaletteColor.textSecondary.color {
            return colorScheme == .dark ? PaletteColor.textSecondary.darkVariant : PaletteColor.textSecondary.color
        } else if color == PaletteColor.cardBackground.color {
            return colorScheme == .dark ? PaletteColor.cardBackground.darkVariant : PaletteColor.cardBackground.color
        } else if color == PaletteColor.background.color {
            return colorScheme == .dark ? PaletteColor.background.darkVariant : PaletteColor.background.color
        }
        // Return original color if not a palette color
        return color
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
        
        // Using StatCardRow with palette colors
        StatCardRow(
            stats: [
                ("flame.fill", "8", "Streak", LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)),
                ("trophy.fill", "15", "Awards", LinearGradient(
                    colors: [.yellow, .orange],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            ],
            hasAppeared: true
        )
        .padding()
    }
    .background(Color(.systemBackground))
}
