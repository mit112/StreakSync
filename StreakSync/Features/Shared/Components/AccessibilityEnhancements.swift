//
//  AccessibilityEnhancements.swift
//  StreakSync
//
//  Enhanced accessibility features and dynamic type support
//

import SwiftUI

// MARK: - Accessibility Announcements
struct AccessibilityAnnouncer {
    static func announce(_ message: String) {
        DispatchQueue.main.async {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }

    static func announceDataRefreshed() {
        announce("Data refreshed successfully")
    }
}
