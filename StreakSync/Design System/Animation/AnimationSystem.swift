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

// MARK: - Shake Modifier
struct ShakeModifier: ViewModifier {
    let shakes: Int
    let amplitude: CGFloat
    
    @State private var shakesRemaining = 0
    
    func body(content: Content) -> some View {
        content
            .offset(x: shakesRemaining > 0 ? amplitude : 0)
            .animation(
                shakesRemaining > 0 ?
                Animation.linear(duration: 0.05).repeatCount(shakes * 2, autoreverses: true) :
                .default,
                value: shakesRemaining
            )
            .onReceive(NotificationCenter.default.publisher(for: .shake)) { _ in
                shakesRemaining = shakes
                Task { @MainActor in HapticManager.shared.trigger(.error) }
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(shakes) * 0.1) {
                    shakesRemaining = 0
                }
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
    
    /// Adds shake animation capability
    func shakeable(shakes: Int = 3, amplitude: CGFloat = 5) -> some View {
        modifier(ShakeModifier(shakes: shakes, amplitude: amplitude))
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let shake = Notification.Name("shakeAnimation")
}

// MARK: - Animation Utilities
struct AnimationUtility {
    /// Triggers a shake animation on any view with the shake modifier
    static func triggerShake() {
        NotificationCenter.default.post(name: .shake, object: nil)
    }
    
    /// Performs an action with haptic feedback
    @MainActor static func performWithHaptic(_ type: HapticManager.HapticType, action: () -> Void) {
        HapticManager.shared.trigger(type)
        action()
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

// MARK: - Card Swipe Modifier
struct SwipeableCardModifier: ViewModifier {
    @GestureState private var dragOffset = CGSize.zero
    @State private var finalOffset = CGSize.zero
    let onSwipe: ((SwipeDirection) -> Void)?
    
    enum SwipeDirection {
        case left, right
    }
    
    func body(content: Content) -> some View {
        GeometryReader { geometry in
            content
                .offset(x: dragOffset.width + finalOffset.width)
                .animation(SpringPreset.snappy, value: dragOffset)
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            state = value.translation
                        }
                        .onEnded { value in
                            let threshold: CGFloat = 100
                            
                            if value.translation.width > threshold {
                                Task { @MainActor in HapticManager.shared.trigger(.cardSwipe) }
                                onSwipe?(.right)
                                withAnimation(SpringPreset.bouncy) {
                                    finalOffset.width = geometry.size.width
                                }
                            } else if value.translation.width < -threshold {
                                Task { @MainActor in HapticManager.shared.trigger(.cardSwipe) }
                                onSwipe?(.left)
                                withAnimation(SpringPreset.bouncy) {
                                    finalOffset.width = -geometry.size.width
                                }
                            } else {
                                // Snap back
                                Task { @MainActor in HapticManager.shared.trigger(.cardSnap) }
                                withAnimation(SpringPreset.snappy) {
                                    finalOffset = .zero
                                }
                            }
                        }
                )
        }
    }
}

// MARK: - Pull to Refresh Modifier
struct PullToRefreshModifier: ViewModifier {
    @Binding var isRefreshing: Bool
    let onRefresh: () async -> Void
    
    func body(content: Content) -> some View {
        content
            .refreshable {
                Task { @MainActor in HapticManager.shared.trigger(.pullToRefresh) }
                await onRefresh()
            }
    }
}

extension View {
    /// Adds staggered appearance animation
    func staggeredAppearance(index: Int, totalCount: Int) -> some View {
        modifier(StaggeredAnimationModifier(index: index, totalCount: totalCount))
    }
    
    /// Makes a card swipeable with haptic feedback
    func swipeableCard(onSwipe: ((SwipeableCardModifier.SwipeDirection) -> Void)? = nil) -> some View {
        modifier(SwipeableCardModifier(onSwipe: onSwipe))
    }
    
    /// Adds pull to refresh with haptic feedback
    func pullToRefreshWithHaptic(isRefreshing: Binding<Bool>, onRefresh: @escaping () async -> Void) -> some View {
        modifier(PullToRefreshModifier(isRefreshing: isRefreshing, onRefresh: onRefresh))
    }
}

// MARK: - Scroll Phase Watcher (compat wrapper)
/// Wraps `.onScrollPhaseChange` with a two-argument closure while compiling on iOS versions where the API may not be available at callsite.
struct ScrollPhaseWatcher: ViewModifier {
    let onChange: (ScrollPhase, ScrollPhase) -> Void
    
    func body(content: Content) -> some View {
        #if swift(>=6.0)
        if #available(iOS 17.0, *) {
            content.onScrollPhaseChange { oldPhase, newPhase in
                onChange(oldPhase, newPhase)
            }
        } else {
            content
        }
        #else
        content
        #endif
    }
}
