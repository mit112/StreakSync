////
//  GlassComponents.swift
//  StreakSync
//
//  Glassmorphic UI components following Design System.pdf specifications
//

//
//  GlassComponents.swift
//  StreakSync
//
//  FIXED: Updated to use new StreakSyncColors system
//

import SwiftUI

// MARK: - Glass Effect Depths
enum GlassDepth {
    case subtle
    case medium
    case prominent
    
    var blurRadius: CGFloat {
        switch self {
        case .subtle: return 8
        case .medium: return 16
        case .prominent: return 24
        }
    }
    
    var opacity: Double {
        switch self {
        case .subtle: return 0.6
        case .medium: return 0.7
        case .prominent: return 0.8
        }
    }
    
    var shadowRadius: CGFloat {
        switch self {
        case .subtle: return 4
        case .medium: return 8
        case .prominent: return 12
        }
    }
    
    var shadowY: CGFloat {
        switch self {
        case .subtle: return 2
        case .medium: return 4
        case .prominent: return 8
        }
    }
}

// MARK: - Glass Card
struct GlassCard: ViewModifier {
    let depth: GlassDepth
    let cornerRadius: CGFloat
    let tintColor: Color?
    
    @Environment(\.colorScheme) private var colorScheme
    
    init(depth: GlassDepth = .medium, cornerRadius: CGFloat = 20, tintColor: Color? = nil) {
        self.depth = depth
        self.cornerRadius = cornerRadius
        self.tintColor = tintColor
    }
    
    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    // Base glass layer
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                        .opacity(depth.opacity)
                    
                    // Add subtle gradient overlay
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            StreakSyncColors.accentGradient(for: colorScheme)
                                .opacity(colorScheme == .dark ? 0.05 : 0.03)
                        )
                    
                    // Inner shadow for depth
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.1 : 0.3),
                                    Color.white.opacity(0.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            }
            .shadow(
                color: tintColor?.opacity(0.15) ??
                       StreakSyncColors.primary(for: colorScheme).opacity(0.1),
                radius: depth.shadowRadius,
                x: 0,
                y: depth.shadowY
            )
    }
}

// MARK: - Glass Button
struct GlassButton: ButtonStyle {
    let isProminent: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    
    init(isProminent: Bool = false) {
        self.isProminent = isProminent
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    if isProminent {
                        // Prominent button with gradient
                        RoundedRectangle(cornerRadius: 12)
                            .fill(StreakSyncColors.accentGradient(for: colorScheme))
                            .opacity(configuration.isPressed ? 0.8 : 1.0)
                    } else {
                        // Subtle glass button
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .opacity(0.8)
                        
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                configuration.isPressed ?
                                    Color.primary.opacity(0.1) :
                                    Color.clear
                            )
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        Color.white.opacity(isProminent ? 0.2 : 0.1),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: colorScheme == .dark ?
                    Color.black.opacity(0.3) :
                    Color.black.opacity(0.1),
                radius: configuration.isPressed ? 2 : 4,
                y: configuration.isPressed ? 1 : 2
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Glass Tab Bar
struct GlassTabBar: View {
    @Binding var selectedTab: Int
    let tabs: [(icon: String, label: String)]
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs.indices, id: \.self) { index in
                TabButton(
                    icon: tabs[index].icon,
                    label: tabs[index].label,
                    isSelected: selectedTab == index,
                    colorScheme: colorScheme
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = index
                    }
                    
                    // Haptic feedback
                    HapticManager.shared.trigger(.buttonTap)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            Color.white.opacity(0.1),
                            lineWidth: 1
                        )
                )
        )
        .shadow(
            color: Color.black.opacity(0.15),
            radius: 8,
            y: -2
        )
    }
    
    private struct TabButton: View {
        let icon: String
        let label: String
        let isSelected: Bool
        let colorScheme: ColorScheme
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                VStack(spacing: 4) {
                    Image.safeSystemName(icon, fallback: "button")
                        .font(.system(size: 20))
                        .symbolVariant(isSelected ? .fill : .none)
                    
                    Text(label)
                        .font(.caption2)
                }
                .foregroundStyle(
                    isSelected ?
                        AnyShapeStyle(StreakSyncColors.accentGradient(for: colorScheme)) :
                        AnyShapeStyle(Color.secondary)
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    isSelected ?
                        RoundedRectangle(cornerRadius: 12)
                            .fill(StreakSyncColors.primary(for: colorScheme).opacity(0.15))
                            .padding(.horizontal, 4) :
                        nil
                )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - View Extensions
extension View {
    /// Apply glass card effect with optional tint color
    func glassCard(depth: GlassDepth = .medium, cornerRadius: CGFloat = 20, tintColor: Color? = nil) -> some View {
        self.modifier(GlassCard(depth: depth, cornerRadius: cornerRadius, tintColor: tintColor))
    }
    
    /// Apply glass button style
    func glassButton(isProminent: Bool = false) -> some View {
        self.buttonStyle(GlassButton(isProminent: isProminent))
    }
}
