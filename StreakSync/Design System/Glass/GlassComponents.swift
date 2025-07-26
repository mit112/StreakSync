////
//  GlassComponents.swift
//  StreakSync
//
//  Glassmorphic UI components following Design System.pdf specifications
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
    
    @Environment(\.colorScheme) var colorScheme
    private let theme = ThemeManager.shared
    
    init(depth: GlassDepth = .medium, cornerRadius: CGFloat = 20) {
        self.depth = depth
        self.cornerRadius = cornerRadius
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Base glass layer
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                        .opacity(depth.opacity)
                    
                    // Gradient overlay
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(theme.subtleBackgroundGradient)
                        .opacity(0.3)
                    
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
            )
            .shadow(
                color: colorScheme == .dark ?
                    Color.black.opacity(0.5) :
                    Color.black.opacity(0.15),
                radius: depth.shadowRadius,
                x: 0,
                y: depth.shadowY
            )
    }
}

// MARK: - Glass Button
struct GlassButton: ButtonStyle {
    let isProminent: Bool
    
    @Environment(\.colorScheme) var colorScheme
    private let theme = ThemeManager.shared
    
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
                            .fill(theme.accentGradient)
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
    
    private let theme = ThemeManager.shared
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs.indices, id: \.self) { index in
                TabButton(
                    icon: tabs[index].icon,
                    label: tabs[index].label,
                    isSelected: selectedTab == index,
                    theme: theme
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = index
                    }
                    
                    // Haptic feedback
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
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
        let theme: ThemeManager
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                VStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .symbolVariant(isSelected ? .fill : .none)
                    
                    Text(label)
                        .font(.caption2)
                }
                .foregroundStyle(
                    isSelected ?
                        AnyShapeStyle(theme.accentGradient) :
                        AnyShapeStyle(Color.secondary)
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    isSelected ?
                        RoundedRectangle(cornerRadius: 12)
                            .fill(theme.primaryAccent.opacity(0.15))
                            .padding(.horizontal, 4) :
                        nil
                )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Animated Gradient Text
struct AnimatedGradientText: View {
    let text: String
    let font: Font
    
    @State private var animationOffset: CGFloat = 0
    private let theme = ThemeManager.shared
    
    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(
                LinearGradient(
                    colors: theme.isDarkMode ?
                        theme.colors.accentDark.map { Color(hex: $0) } :
                        theme.colors.accentLight.map { Color(hex: $0) },
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .opacity(0.9)
            )
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.4),
                        Color.white.opacity(0.0),
                        Color.white.opacity(0.4)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .mask(
                    Text(text)
                        .font(font)
                )
                .offset(x: animationOffset)
                .mask(
                    Text(text)
                        .font(font)
                )
            )
            .onAppear {
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    animationOffset = 300
                }
            }
    }
}

// MARK: - View Extensions
extension View {
    func glassCard(depth: GlassDepth = .medium, cornerRadius: CGFloat = 20) -> some View {
        self.modifier(GlassCard(depth: depth, cornerRadius: cornerRadius))
    }
    
    func glassButton(isProminent: Bool = false) -> some View {
        self.buttonStyle(GlassButton(isProminent: isProminent))
    }
}
