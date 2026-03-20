//
//  NotificationSettingsView.swift
//  StreakSync
//
//  Comprehensive notification settings with per-game controls
//

import OSLog
import SwiftUI
import UserNotifications

// MARK: - Notification Settings View Model
@MainActor
final class NotificationSettingsViewModel: ObservableObject {
    @Published var notificationsEnabled = false
    @Published var remindersEnabled = true
    @Published var reminderHour = 19 // 7 PM default
    @Published var reminderMinute = 0
    @Published var showPermissionFlow = false
    @Published var showPermissionDenied = false
    
    private let userDefaults = UserDefaults.standard
    private let logger = Logger(subsystem: "com.streaksync.app", category: "NotificationSettings")
    private weak var appState: AppState?
    
    func setAppState(_ appState: AppState) {
        self.appState = appState
    }
    
    func loadSettings() {
        remindersEnabled = userDefaults.bool(forKey: AppConstants.NotificationSettings.remindersEnabled)
        reminderHour = userDefaults.object(forKey: AppConstants.NotificationSettings.reminderHour) as? Int ?? 19
        reminderMinute = userDefaults.object(forKey: AppConstants.NotificationSettings.reminderMinute) as? Int ?? 0
        
        Task {
            await checkPermissionStatus()
        }
    }
    
    func saveSettings() {
        userDefaults.set(remindersEnabled, forKey: AppConstants.NotificationSettings.remindersEnabled)
        userDefaults.set(reminderHour, forKey: AppConstants.NotificationSettings.reminderHour)
        userDefaults.set(reminderMinute, forKey: AppConstants.NotificationSettings.reminderMinute)
        
        // Reschedule reminders with new settings
        Task {
            if let appState = appState {
                await appState.checkAndScheduleStreakReminders()
 logger.info("Rescheduled reminders with new settings")
            }
        }
        
 logger.info("Saved notification settings")
    }
    
    func checkPermissionStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsEnabled = settings.authorizationStatus == .authorized
        
        if !notificationsEnabled {
            showPermissionDenied = settings.authorizationStatus == .denied
        }
    }
    
    func presentPermissionFlowIfNeeded() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            notificationsEnabled = true
            showPermissionDenied = false
        case .denied:
            showPermissionDenied = true
        case .notDetermined, .ephemeral:
            showPermissionFlow = true
        @unknown default:
            showPermissionFlow = true
        }
    }
    
    #if DEBUG
    func testNotification() async {
        // Send immediate test notification
        let gamesAtRisk = appState?.games.filter { game in
            guard let streak = appState?.streaks.first(where: { $0.gameId == game.id }),
                  streak.currentStreak > 0 else {
                return false
            }
            return true
        }.prefix(3).map { $0 } ?? []
        
        if !gamesAtRisk.isEmpty {
            await NotificationScheduler.shared.scheduleTestDailyReminder(games: Array(gamesAtRisk))
        }
    }
    #endif
}

// MARK: - Notification Settings View
struct NotificationSettingsView: View {
    @StateObject private var viewModel: NotificationSettingsViewModel
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    init() {
        self._viewModel = StateObject(wrappedValue: NotificationSettingsViewModel())
    }
    
    var body: some View {
        List {
                if !viewModel.notificationsEnabled {
                    permissionSection
                } else {
                settingsSection
                }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    viewModel.saveSettings()
                    dismiss()
                }
            }
        }
        .task {
            viewModel.setAppState(appState)
            viewModel.loadSettings()
        }
        .sheet(isPresented: $viewModel.showPermissionFlow) {
            NotificationPermissionFlowView()
        }
        .onChange(of: viewModel.showPermissionFlow) { _, isPresented in
            guard !isPresented else { return }
            Task {
                await viewModel.checkPermissionStatus()
            }
        }
        .sheet(isPresented: $viewModel.showPermissionDenied) {
            NotificationPermissionDeniedView()
        }
    }
    
    // MARK: - Permission Section
    private var permissionSection: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "bell.slash")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                
                Text("Notifications Disabled")
                    .font(.headline)
                
                Text("Enable notifications to get gentle reminders about your streaks and achievements.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Button("Enable Notifications") {
                    Task {
                        await viewModel.presentPermissionFlowIfNeeded()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical)
        }
    }
    
    // MARK: - Settings Section
    private var settingsSection: some View {
        Section {
            Toggle("Enable Streak Reminders", isOn: $viewModel.remindersEnabled)
                .font(.headline)
            
            if viewModel.remindersEnabled {
                DatePicker(
                    "Reminder Time",
                    selection: Binding(
                        get: {
                            Calendar.current.date(
                                bySettingHour: viewModel.reminderHour,
                                minute: viewModel.reminderMinute,
                                second: 0,
                                of: Date()
                            ) ?? Date()
                        },
                        set: { date in
                            viewModel.reminderHour = Calendar.current.component(.hour, from: date)
                            viewModel.reminderMinute = Calendar.current.component(.minute, from: date)
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
                
                // Notification Preview
                notificationPreviewSection
            }
        } header: {
            Text("Daily Reminder")
        } footer: {
            if viewModel.remindersEnabled {
                Text("You'll receive one daily reminder showing all games with streaks at risk.")
            }
        }
    }
    
    // MARK: - Notification Preview Section
    private var notificationPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.subheadline)
                .fontWeight(.medium)
                        .foregroundStyle(.secondary)
            
            // Simulate notification appearance
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(.blue)
                    Text("StreakSync")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    Text("now")
                        .font(.caption2)
                            .foregroundStyle(.secondary)
                }
                
                Text("Streak Reminders")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(previewNotificationBody)
                    .font(.caption)
                        .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .accessibilityElement(children: .combine)
    }
    
    private var previewNotificationBody: String {
        let gamesAtRisk = appState.games.filter { game in
            guard let streak = appState.streaks.first(where: { $0.gameId == game.id }),
                  streak.currentStreak > 0 else {
                return false
            }
            return true
        }
        
        if gamesAtRisk.isEmpty {
            return "No games with active streaks at risk"
        } else if gamesAtRisk.count == 1 {
            return "Don't lose your \(gamesAtRisk[0].displayName) streak"
        } else if gamesAtRisk.count <= 3 {
            let names = gamesAtRisk.map { $0.displayName }.joined(separator: ", ")
            return "Don't lose your streaks in \(names)"
        } else {
            let firstTwo = gamesAtRisk.prefix(2).map { $0.displayName }.joined(separator: ", ")
            let remaining = gamesAtRisk.count - 2
            return "Don't lose your streaks in \(firstTwo), and \(remaining) other game\(remaining > 1 ? "s" : "")"
        }
    }
}

#Preview {
    NotificationSettingsView()
        .environment(AppState(persistenceService: MockPersistenceService()))
}
