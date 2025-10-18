//
//  HapticManager.swift
//  StreakSync
//
//  Created by MiT on 7/24/25.
//

// DesignSystem/Haptics/HapticManager.swift

/*
 * HAPTICMANAGER - TACTILE FEEDBACK AND USER INTERACTION ENHANCEMENT
 * 
 * WHAT THIS FILE DOES:
 * This file provides a centralized system for managing haptic feedback throughout the app.
 * It's like a "tactile feedback coordinator" that makes interactions feel more responsive
 * and engaging by providing appropriate vibrations and tactile sensations. Think of it as
 * the "touch sensation manager" that enhances the user experience by making the app feel
 * more physical and responsive to user actions.
 * 
 * WHY IT EXISTS:
 * Haptic feedback makes apps feel more engaging and responsive by providing tactile
 * sensations that correspond to user actions. This manager ensures that all haptic
 * feedback is consistent, appropriate, and enhances the user experience without being
 * overwhelming. It provides different types of feedback for different interactions,
 * making the app feel more polished and professional.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This enhances user experience with tactile feedback
 * - Provides consistent haptic feedback across all interactions
 * - Supports different types of feedback for different actions
 * - Integrates with Core Haptics for advanced tactile patterns
 * - Ensures haptic feedback is appropriate and not overwhelming
 * - Makes the app feel more responsive and engaging
 * - Provides accessibility benefits for users with visual impairments
 * 
 * WHAT IT REFERENCES:
 * - CoreHaptics: Apple's advanced haptic feedback framework
 * - UIKit: For basic haptic feedback generators
 * - UIImpactFeedbackGenerator: For impact-based haptic feedback
 * - UISelectionFeedbackGenerator: For selection-based haptic feedback
 * - UINotificationFeedbackGenerator: For notification-based haptic feedback
 * - HapticType: Enum defining different types of haptic feedback
 * 
 * WHAT REFERENCES IT:
 * - EVERYTHING: This is used by virtually every interactive component in the app
 * - All buttons and interactive elements: Use this for tactile feedback
 * - Animation system: Uses this to enhance animations with haptics
 * - Game interactions: Use this to make games feel more engaging
 * - Achievement system: Uses this to celebrate achievements
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. HAPTIC PATTERN IMPROVEMENTS:
 *    - The current patterns are good but could be more sophisticated
 *    - Consider adding more complex haptic patterns for special events
 *    - Add support for custom haptic patterns and sequences
 *    - Implement smart haptic feedback based on user preferences
 * 
 * 2. ACCESSIBILITY IMPROVEMENTS:
 *    - The current accessibility support could be enhanced
 *    - Add support for haptic feedback customization
 *    - Implement haptic feedback for different accessibility needs
 *    - Add support for haptic feedback intensity control
 * 
 * 3. PERFORMANCE OPTIMIZATIONS:
 *    - The current implementation could be optimized
 *    - Consider implementing efficient haptic feedback queuing
 *    - Add support for haptic feedback batching
 *    - Implement smart haptic feedback scheduling
 * 
 * 4. USER EXPERIENCE IMPROVEMENTS:
 *    - The current haptic system could be more user-friendly
 *    - Add support for haptic feedback preferences
 *    - Implement smart haptic feedback based on context
 *    - Add support for haptic feedback tutorials and guidance
 * 
 * 5. TESTING IMPROVEMENTS:
 *    - Add comprehensive unit tests for haptic feedback logic
 *    - Test different haptic patterns and scenarios
 *    - Add integration tests with real haptic feedback
 *    - Test accessibility features
 * 
 * 6. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for haptic feedback features
 *    - Document the different haptic types and usage patterns
 *    - Add examples of how to use different haptic feedback
 *    - Create haptic feedback usage guidelines
 * 
 * 7. EXTENSIBILITY IMPROVEMENTS:
 *    - Make it easier to add new haptic types
 *    - Add support for custom haptic patterns
 *    - Implement haptic feedback plugins
 *    - Add support for third-party haptic integrations
 * 
 * 8. MONITORING AND OBSERVABILITY:
 *    - Add detailed logging for haptic feedback usage
 *    - Implement metrics for haptic feedback effectiveness
 *    - Add support for haptic feedback debugging
 *    - Monitor haptic feedback performance and reliability
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - Haptic feedback: Tactile sensations that make interactions feel more real
 * - Core Haptics: Apple's advanced framework for creating custom haptic patterns
 * - User experience: Making sure the app feels engaging and responsive
 * - Accessibility: Ensuring the app works for users with different needs
 * - Feedback systems: Providing users with information about their actions
 * - Interaction design: Creating engaging and intuitive user interfaces
 * - Sensory feedback: Using multiple senses to enhance user experience
 * - Performance: Making sure haptic feedback doesn't slow down the app
 * - User preferences: Allowing users to customize their experience
 * - Design systems: Standardized approaches to creating consistent experiences
 */
import UIKit
import SwiftUI
import CoreHaptics

/// Centralized haptic feedback management following the design spec
@MainActor
public final class HapticManager {
    // Singleton instance
    public static let shared = HapticManager()
    
    // Haptic generators
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let selection = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()
    
    // Core Haptics engine for custom patterns
    private var hapticEngine: CHHapticEngine?
    
    private init() {
        setupHapticEngine()
        prepareGenerators()
    }
    
    // MARK: - Setup
    
    private func setupHapticEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("Failed to start haptic engine: \(error)")
        }
    }
    
    private func prepareGenerators() {
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        selection.prepare()
        notification.prepare()
    }
    
    // MARK: - Public Interface
    
    /// Trigger haptic feedback based on interaction type
    public func trigger(_ type: HapticType) {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        
        switch type {
        case .buttonTap:
            impactLight.impactOccurred()
            
        case .toggleSwitch:
            selection.selectionChanged()
            
        case .cardSwipe:
            impactMedium.impactOccurred()
            
        case .streakUpdate:
            notification.notificationOccurred(.success)
            
        case .achievement:
            // Complex pattern: success notification + heavy impact
            notification.notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.impactHeavy.impactOccurred()
            }
            
        case .error:
            notification.notificationOccurred(.error)
            
        case .scrollLimit:
            impactLight.impactOccurred(intensity: 0.5)
            
        case .pickerChange:
            selection.selectionChanged()
            
        case .pullToRefresh:
            impactMedium.impactOccurred(intensity: 0.7)
            
        case .longPress:
            impactMedium.impactOccurred()
            
        case .cardSnap:
            impactLight.impactOccurred(intensity: 0.8)
        }
    }
    
    /// Play a custom haptic pattern
    public func playCustomPattern(_ pattern: HapticPattern) {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = hapticEngine else { return }
        
        do {
            let pattern = try pattern.createCHHapticPattern()
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play custom haptic pattern: \(error)")
        }
    }
    
    // MARK: - Haptic Types
    
    public enum HapticType: Sendable {
        case buttonTap
        case toggleSwitch
        case cardSwipe
        case streakUpdate
        case achievement
        case error
        case scrollLimit
        case pickerChange
        case pullToRefresh
        case longPress
        case cardSnap
    }
}

// MARK: - Custom Haptic Patterns
public struct HapticPattern: Sendable {
    let events: [HapticEvent]
    
    public struct HapticEvent: Sendable {
        let time: TimeInterval
        let intensity: Float
        let sharpness: Float
        let duration: TimeInterval
    }
    
    /// Creates a CHHapticPattern from our custom structure
    fileprivate func createCHHapticPattern() throws -> CHHapticPattern {
        let hapticEvents = events.map { event in
            CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: event.intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: event.sharpness)
                ],
                relativeTime: event.time,
                duration: event.duration
            )
        }
        
        return try CHHapticPattern(events: hapticEvents, parameters: [])
    }
    
    // MARK: - Predefined Patterns
    
    /// Celebration pattern for achievements
    public static let celebration = HapticPattern(events: [
        HapticEvent(time: 0.0, intensity: 0.8, sharpness: 0.8, duration: 0.1),
        HapticEvent(time: 0.15, intensity: 0.6, sharpness: 0.6, duration: 0.1),
        HapticEvent(time: 0.3, intensity: 1.0, sharpness: 1.0, duration: 0.2)
    ])
    
    /// Streak flame pattern
    public static let streakFlame = HapticPattern(events: [
        HapticEvent(time: 0.0, intensity: 0.3, sharpness: 0.2, duration: 0.5),
        HapticEvent(time: 0.1, intensity: 0.5, sharpness: 0.4, duration: 0.3),
        HapticEvent(time: 0.2, intensity: 0.7, sharpness: 0.6, duration: 0.2),
        HapticEvent(time: 0.3, intensity: 0.4, sharpness: 0.3, duration: 0.4)
    ])
    
    /// Card shuffle pattern
    public static let cardShuffle = HapticPattern(events: [
        HapticEvent(time: 0.0, intensity: 0.4, sharpness: 0.8, duration: 0.05),
        HapticEvent(time: 0.1, intensity: 0.4, sharpness: 0.8, duration: 0.05),
        HapticEvent(time: 0.2, intensity: 0.4, sharpness: 0.8, duration: 0.05)
    ])
}

// MARK: - Convenience Extensions
extension HapticManager {
    /// Quick access for common haptics
    public static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        Task { @MainActor in
            switch style {
            case .light:
                shared.trigger(.buttonTap)
            case .medium:
                shared.trigger(.cardSwipe)
            case .heavy:
                shared.trigger(.achievement)
            default:
                shared.trigger(.buttonTap)
            }
        }
    }
    
    static func selection() {
        HapticManager.shared.trigger(.toggleSwitch)
    }
    
    public static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        Task { @MainActor in
            switch type {
            case .success:
                shared.trigger(.streakUpdate)
            case .error:
                shared.trigger(.error)
            case .warning:
                shared.trigger(.scrollLimit)
            default:
                break
            }
        }
    }
}

// MARK: - SwiftUI View Modifier
struct HapticModifier: ViewModifier {
    let type: HapticManager.HapticType
    let trigger: Bool
    
    func body(content: Content) -> some View {
        content
            .onChange(of: trigger) {
                if trigger {
                    Task { @MainActor in
                        HapticManager.shared.trigger(type)
                    }
                }
            }
    }
}

extension View {
    /// Trigger haptic feedback when a boolean value changes
    public func hapticFeedback(_ type: HapticManager.HapticType, trigger: Bool) -> some View {
        self.modifier(HapticModifier(type: type, trigger: trigger))
    }
}
