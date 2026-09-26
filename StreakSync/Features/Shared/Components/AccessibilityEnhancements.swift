//
//  AccessibilityEnhancements.swift
//  StreakSync
//
//  Enhanced accessibility features and dynamic type support
//

import SwiftUI

// MARK: - Accessibility Announcements
@MainActor
enum AccessibilityAnnouncer {
    static func announce(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    static func announceDataRefreshed() {
        announce("Data refreshed successfully")
    }
}
