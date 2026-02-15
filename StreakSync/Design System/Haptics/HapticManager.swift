//
//  HapticManager.swift
//  StreakSync
//
//  Created by MiT on 7/24/25.
//

// DesignSystem/Haptics/HapticManager.swift

import UIKit
import SwiftUI
import CoreHaptics
import OSLog

/// Centralized haptic feedback management following the design spec
@MainActor
public final class HapticManager {
    // Singleton instance
    public static let shared = HapticManager()
    private let logger = Logger(subsystem: "com.streaksync.app", category: "HapticManager")
    
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
            logger.error("Failed to start haptic engine: \(error.localizedDescription)")
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
            logger.error("Failed to play custom haptic pattern: \(error.localizedDescription)")
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
