//
//  HapticManager.swift
//  StreakSync
//
//  Created by MiT on 7/24/25.
//

import OSLog
import SwiftUI
// DesignSystem/Haptics/HapticManager.swiftimport UIKit

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
    
    private init() {
        prepareGenerators()
    }

    // MARK: - Setup

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
