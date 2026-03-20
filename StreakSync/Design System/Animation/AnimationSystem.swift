//
//  AnimationSystem.swift
//  StreakSync
//
//  Created by MiT on 7/24/25.
//

import SwiftUI

// MARK: - Spring Animation Presets
enum SpringPreset {
    /// Quick, responsive animation for UI feedback (0.3s, 0.8 damping)
    static let snappy = Animation.spring(response: 0.3, dampingFraction: 0.8)
    
    /// Playful animation with bounce (0.4s, 0.6 damping)
    static let bouncy = Animation.spring(response: 0.4, dampingFraction: 0.6)
    
    /// Smooth, balanced animation (0.5s, 0.8 damping)
    static let smooth = Animation.spring(response: 0.5, dampingFraction: 0.8)
    
    /// Slow, gentle animation for subtle effects (0.6s, 1.0 damping)
    static let gentle = Animation.spring(response: 0.6, dampingFraction: 1.0)
}

// MARK: - Animation System uses HapticManager from DesignSystem/Haptics/HapticManager.swift

// MARK: - Pressable Modifier
struct PressableModifier: ViewModifier {
    @State private var isPressed = false
    
    let hapticType: HapticManager.HapticType
    let hapticEnabled: Bool
    let scaleAmount: CGFloat
    
    init(hapticType: HapticManager.HapticType = .buttonTap, hapticEnabled: Bool = true, scaleAmount: CGFloat = 0.95) {
        self.hapticType = hapticType
        self.hapticEnabled = hapticEnabled
        self.scaleAmount = scaleAmount
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scaleAmount : 1.0)
            .animation(SpringPreset.snappy, value: isPressed)
            .onTapGesture {
                // Empty - actual action handled by button
            }
            .onLongPressGesture(
                minimumDuration: 0,
                maximumDistance: .infinity,
                pressing: { pressing in
                    withAnimation(SpringPreset.snappy) {
                        isPressed = pressing
                    }
                    if pressing && hapticEnabled {
                        Task { @MainActor in HapticManager.shared.trigger(hapticType) }
                    }
                },
                perform: {}
            )
    }
}

// MARK: - Hoverable Modifier (for iPad cursor support)
struct HoverableModifier: ViewModifier {
    @State private var isHovered = false
    
    let scaleAmount: CGFloat
    
    init(scaleAmount: CGFloat = 1.05) {
        self.scaleAmount = scaleAmount
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? scaleAmount : 1.0)
            .animation(SpringPreset.smooth, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - View Extensions
extension View {
    /// Makes any view pressable with haptic feedback
    func pressable(hapticType: HapticManager.HapticType = .buttonTap, hapticEnabled: Bool = true, scaleAmount: CGFloat = 0.95) -> some View {
        modifier(PressableModifier(hapticType: hapticType, hapticEnabled: hapticEnabled, scaleAmount: scaleAmount))
    }

    /// Adds hover effect for iPad cursor support
    func hoverable(scaleAmount: CGFloat = 1.05) -> some View {
        modifier(HoverableModifier(scaleAmount: scaleAmount))
    }
}

// MARK: - Staggered Animation Helper
struct StaggeredAnimationModifier: ViewModifier {
    let index: Int
    let totalCount: Int
    @State private var appeared = false
    
    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(
                SpringPreset.smooth.delay(Double(index) * 0.05),
                value: appeared
            )
            .onAppear {
                appeared = true
            }
            .onDisappear {
                appeared = false
            }
    }
}

extension View {
    /// Adds staggered appearance animation
    func staggeredAppearance(index: Int, totalCount: Int) -> some View {
        modifier(StaggeredAnimationModifier(index: index, totalCount: totalCount))
    }
}

// MARK: - Initial Animation Modifier
/// Drives staggered entrance animations on first appearance. Shared by StatCard and DashboardGamesContent.
struct InitialAnimationModifier: ViewModifier {
    let hasAppeared: Bool
    let index: Int
    let totalCount: Int

    func body(content: Content) -> some View {
        content
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 20)
            .animation(
                .smooth(duration: 0.5)
                .delay(Double(index) * 0.05),
                value: hasAppeared
            )
    }
}

// MARK: - Scroll Phase Watcher (compat wrapper)
/// Wraps `.onScrollPhaseChange` with a two-argument closure while compiling on iOS versions where the API may not be available at callsite.
struct ScrollPhaseWatcher: ViewModifier {
    let onChange: (ScrollPhase, ScrollPhase) -> Void
    
    func body(content: Content) -> some View {
        content.onScrollPhaseChange { oldPhase, newPhase in
            onChange(oldPhase, newPhase)
        }
    }
}
