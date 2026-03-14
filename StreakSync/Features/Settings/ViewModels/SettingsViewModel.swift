//
//  SettingsViewModel.swift
//  StreakSync
//
//  View model for the Settings screen — notification status and appearance mode
//

import SwiftUI
import UserNotifications

// MARK: - Settings View Model
@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var notificationsEnabled = false
    @Published var streakRemindersEnabled = true

    private let userDefaults = UserDefaults.standard

    init() {
        loadSettings()
    }

    func loadSettings() async {
        // Load notification authorization status
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsEnabled = settings.authorizationStatus == .authorized

        // Load saved preferences
        streakRemindersEnabled = userDefaults.bool(forKey: "streakRemindersEnabled")
    }

    private func loadSettings() {
        // Synchronous version for init
        streakRemindersEnabled = userDefaults.bool(forKey: "streakRemindersEnabled")
    }

    func saveSettings() {
        userDefaults.set(streakRemindersEnabled, forKey: "streakRemindersEnabled")
    }
}

// MARK: - Settings Extensions
extension SettingsViewModel {
    /// Current appearance mode from UserDefaults
    var appearanceMode: AppearanceMode {
        get {
            if let rawValue = UserDefaults.standard.object(forKey: "appearanceMode") as? Int,
               let mode = AppearanceMode(rawValue: rawValue) {
                return mode
            }
            return .system
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "appearanceMode")
        }
    }
}
