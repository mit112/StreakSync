//
//  AchievementGridComponents.swift
//  StreakSync
//
//  Reusable components for the achievements grid: stat cards, category chips, achievement cards
//

import SwiftUI

// MARK: - Stat Card
struct AchievementStatCard: View {
    let icon: String
    let value: String
    let label: String
    let accentColor: Color
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 8) {
            Image.safeSystemName(icon, fallback: "star.fill")
                .font(.title2)
                .foregroundStyle(accentColor)
                .symbolEffect(.pulse, options: .repeating.speed(0.5), value: isHovered)
            
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.thinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            accentColor.opacity(colorScheme == .dark ? 0.2 : 0.35),
                            lineWidth: 1
                        )
                }
                .shadow(color: accentColor.opacity(colorScheme == .dark ? 0.1 : 0.12), radius: 6, x: 0, y: 2)
                .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.04), radius: 12, x: 0, y: 6)
        }
        .hoverEffect(.lift)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Category Chip
struct AchievementCategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image.safeSystemName(icon, fallback: "star.fill")
                    .font(.caption)
                    .symbolEffect(.bounce, value: isSelected)
                Text(title)
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.accentColor)
                        .shadow(color: .accentColor.opacity(0.3), radius: 4, x: 0, y: 2)
                } else {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Capsule()
                                .stroke(.quaternary, lineWidth: 0.5)
                        }
                }
            }
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.smooth(duration: 0.2), value: isSelected)
        .hoverEffect(.highlight)
    }
}

// MARK: - Achievement Card
struct AchievementCard: View {
    let achievement: TieredAchievement
    let onTap: () -> Void
    
    @State private var isHovered = false
    @State private var showUnlockAnimation = false
    
    private var progressPercentage: Double {
        guard let nextRequirement = achievement.nextTierRequirement else { return 1.0 }
        return min(Double(achievement.progress.currentValue) / Double(nextRequirement.threshold), 1.0)
    }
    
    private var safeIconName: String {
        let iconName = achievement.iconSystemName
        return iconName.isEmpty ? "star.fill" : iconName
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Icon with tier indicator
                ZStack {
                    if achievement.isUnlocked {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        achievement.displayColor.opacity(0.3),
                                        achievement.displayColor.opacity(0)
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 30
                                )
                            )
                            .frame(width: 60, height: 60)
                            .blur(radius: isHovered ? 8 : 4)
                    }
                    
                    Circle()
                        .fill(achievement.displayColor.opacity(0.15))
                        .frame(width: 52, height: 52)
                        .overlay {
                            Circle()
                                .stroke(achievement.displayColor.opacity(0.3), lineWidth: 1)
                        }
                    
                    Image.safeSystemName(safeIconName, fallback: "star.fill")
                        .font(.title)
                        .foregroundStyle(
                            achievement.isUnlocked ?
                            achievement.displayColor :
                            Color(.systemGray3)
                        )
                        .symbolEffect(.bounce, value: showUnlockAnimation)
                }
                
                VStack(spacing: 6) {
                    Text(achievement.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    Text(achievement.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .padding(.horizontal, 8)
                
                Spacer()
                
                VStack(spacing: 8) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(.quaternary)
                            
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            achievement.displayColor,
                                            achievement.displayColor.opacity(0.7)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * progressPercentage)
                                .animation(.smooth, value: progressPercentage)
                        }
                    }
                    .frame(height: 6)
                    
                    Text(achievement.progressDescription)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
            }
            .padding()
            .frame(height: 220)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                achievement.isUnlocked ?
                                    achievement.displayColor.opacity(0.3) :
                                    Color(.separator).opacity(0.5),
                                lineWidth: 1
                            )
                    }
                    .shadow(
                        color: achievement.isUnlocked ?
                            achievement.displayColor.opacity(0.12) :
                            .black.opacity(0.07),
                        radius: isHovered ? 10 : 6,
                        x: 0,
                        y: isHovered ? 5 : 2
                    )
                    .shadow(
                        color: .black.opacity(0.04),
                        radius: 14,
                        x: 0,
                        y: 6
                    )
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .animation(.smooth(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
            if hovering && achievement.isUnlocked {
                showUnlockAnimation = true
            }
        }
        .hoverEffect(.lift)
    }
}

// MARK: - Header Animation Modifier
struct AchievementHeaderAnimation: ViewModifier {
    let hasAppeared: Bool
    
    func body(content: Content) -> some View {
        content
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : -20)
            .animation(
                .smooth(duration: 0.6)
                .delay(0.1),
                value: hasAppeared
            )
    }
}
