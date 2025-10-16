//
//  NotificationSettingsView.swift
//  StreakSync
//
//  Comprehensive notification settings with per-game controls
//

import SwiftUI
import UserNotifications
import OSLog

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
        remindersEnabled = userDefaults.bool(forKey: "streakRemindersEnabled")
        reminderHour = userDefaults.object(forKey: "streakReminderHour") as? Int ?? 19
        reminderMinute = userDefaults.object(forKey: "streakReminderMinute") as? Int ?? 0
        
        Task {
            await checkPermissionStatus()
        }
    }
    
    func saveSettings() {
        userDefaults.set(remindersEnabled, forKey: "streakRemindersEnabled")
        userDefaults.set(reminderHour, forKey: "streakReminderHour")
        userDefaults.set(reminderMinute, forKey: "streakReminderMinute")
        
        // Reschedule reminders with new settings
        Task {
            if let appState = appState {
                await appState.checkAndScheduleStreakReminders()
                logger.info("🔄 Rescheduled reminders with new settings")
            }
        }
        
        logger.info("💾 Saved notification settings")
    }
    
    func checkPermissionStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsEnabled = settings.authorizationStatus == .authorized
        
        if !notificationsEnabled {
            showPermissionDenied = settings.authorizationStatus == .denied
        }
    }
    
    func requestPermission() async {
        let granted = await NotificationPermissionFlowViewModel().requestPermission()
        if granted {
            await checkPermissionStatus()
        } else {
            showPermissionDenied = true
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
//                #if DEBUG
//                        debugSection
//                #endif
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
        .onAppear {
            viewModel.setAppState(appState)
            viewModel.loadSettings()
        }
        .sheet(isPresented: $viewModel.showPermissionFlow) {
            NotificationPermissionFlowView()
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
                    .foregroundColor(.secondary)
                
                Text("Notifications Disabled")
                    .font(.headline)
                
                Text("Enable notifications to get gentle reminders about your streaks and achievements.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button("Enable Notifications") {
                    Task {
                        await viewModel.requestPermission()
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
                        .foregroundColor(.secondary)
            
            // Simulate notification appearance
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundColor(.blue)
                    Text("StreakSync")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    Text("now")
                        .font(.caption2)
                            .foregroundColor(.secondary)
                }
                
                Text("Streak Reminders")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(previewNotificationBody)
                    .font(.caption)
                        .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
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
            return "Don't lose your \(gamesAtRisk[0].name) streak"
        } else if gamesAtRisk.count <= 3 {
            let names = gamesAtRisk.map { $0.name }.joined(separator: ", ")
            return "Don't lose your streaks in \(names)"
        } else {
            let firstTwo = gamesAtRisk.prefix(2).map { $0.name }.joined(separator: ", ")
            let remaining = gamesAtRisk.count - 2
            return "Don't lose your streaks in \(firstTwo), and \(remaining) other game\(remaining > 1 ? "s" : "")"
        }
    }
    
    // MARK: - Debug Section
//    private var debugSection: some View {
//        Section("Debug") {
//            Button("Test Notification") {
//                Task {
//                    await viewModel.testNotification()
//                }
//            }
//            
//            Button("Check Current State") {
//                Task {
//                    await NotificationScheduler.shared.logCurrentNotificationState()
//                }
//            }
//        }
//    }
}

#Preview {
    NotificationSettingsView()
        .environment(AppState(persistenceService: MockPersistenceService()))
}
