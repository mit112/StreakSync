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
    @Published var quietHoursEnabled = false
    @Published var quietHoursStart = 21 // 9 PM
    @Published var quietHoursEnd = 9    // 9 AM
    @Published var enableDigest = false
    @Published var streakMaintenanceEnabled = true
    @Published var showPermissionFlow = false
    @Published var showPermissionDenied = false
    @Published var showDigestHelp = false
    @Published var showStreakMaintenanceHelp = false
    @Published var showQuietHoursHelp = false
    @Published var showTestNotification = false
    
    // Per-game settings
    @Published var gameReminderSettings: [UUID: GameReminderSettings] = [:]
    
    private let userDefaults = UserDefaults.standard
    private let logger = Logger(subsystem: "com.streaksync.app", category: "NotificationSettings")
    private weak var appState: AppState?
    
    // MARK: - Settings Keys
    private enum SettingsKeys {
        static let quietHoursEnabled = "notificationQuietHoursEnabled"
        static let quietHoursStart = "notificationQuietHoursStart"
        static let quietHoursEnd = "notificationQuietHoursEnd"
        static let enableDigest = "enableNotificationDigest"
        static let streakMaintenanceEnabled = "streakMaintenanceEnabled"
        static let gameReminderPrefix = "gameReminder_"
    }
    
    init() {
        loadSettings()
    }
    
    func setAppState(_ appState: AppState) {
        self.appState = appState
    }
    
    // MARK: - Settings Management
    func loadSettings() {
        // Load global settings
        quietHoursEnabled = userDefaults.bool(forKey: SettingsKeys.quietHoursEnabled)
        quietHoursStart = userDefaults.object(forKey: SettingsKeys.quietHoursStart) as? Int ?? 21
        quietHoursEnd = userDefaults.object(forKey: SettingsKeys.quietHoursEnd) as? Int ?? 9
        enableDigest = userDefaults.bool(forKey: SettingsKeys.enableDigest)
        streakMaintenanceEnabled = userDefaults.object(forKey: SettingsKeys.streakMaintenanceEnabled) as? Bool ?? true
        
        // Load per-game settings
        loadGameReminderSettings()
        
        // Check permission status
        Task {
            await checkPermissionStatus()
        }
    }
    
    func saveSettings() {
        userDefaults.set(quietHoursEnabled, forKey: SettingsKeys.quietHoursEnabled)
        userDefaults.set(quietHoursStart, forKey: SettingsKeys.quietHoursStart)
        userDefaults.set(quietHoursEnd, forKey: SettingsKeys.quietHoursEnd)
        userDefaults.set(enableDigest, forKey: SettingsKeys.enableDigest)
        userDefaults.set(streakMaintenanceEnabled, forKey: SettingsKeys.streakMaintenanceEnabled)
        
        // Save per-game settings
        saveGameReminderSettings()
        
        // Update scheduler settings
        NotificationScheduler.shared.setQuietHours(enabled: quietHoursEnabled, start: quietHoursStart, end: quietHoursEnd)
        NotificationScheduler.shared.setDigestEnabled(enableDigest)
        
        // Automatically check and schedule streak reminders when settings are saved
        Task {
            if let appState = appState {
                await appState.checkAndScheduleStreakReminders()
                logger.info("🔄 Auto-scheduled streak reminders after settings save")
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
    
    func sendTestNotification() async {
        guard await NotificationScheduler.shared.checkPermissionStatus() == .authorized else {
            showPermissionFlow = true
            return
        }
        
        // Create a test notification
        let content = UNMutableNotificationContent()
        content.title = "🧪 Test Notification"
        content.body = "This is a test notification from StreakSync!"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.streakReminder.identifier
        content.userInfo = [
            "type": "test",
            "gameId": UUID().uuidString,
            "gameName": "Test Game"
        ]
        
        // Schedule for 2 seconds from now
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test_notification_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ Test notification scheduled")
        } catch {
            print("❌ Failed to schedule test notification: \(error.localizedDescription)")
        }
    }
    
    func sendCustomWordleNotification() async {
        guard await NotificationScheduler.shared.checkPermissionStatus() == .authorized else {
            showPermissionFlow = true
            return
        }
        
        // Create a custom Wordle game
        let wordleGame = Game(
            name: "Wordle",
            displayName: "Wordle",
            url: URL(string: "https://www.nytimes.com/games/wordle")!,
            category: .word,
            resultPattern: "Wordle \\d+ \\d+/6",
            iconSystemName: "textformat.abc",
            backgroundColor: CodableColor(.green),
            isPopular: true,
            isCustom: false
        )
        
        // Schedule immediate streak reminder using the proper scheduler
        await NotificationScheduler.shared.scheduleImmediateStreakReminder(for: wordleGame, in: 3)
        print("✅ Custom Wordle notification scheduled for 3 seconds")
    }
    
    func checkStreakReminders() async {
        // This will trigger the streak reminder check for all games
        // You can call this to test if reminders are being scheduled
        print("🔍 Checking streak reminders...")
        
        if let appState = appState {
            // First, let's check what games and streaks we have
            print("📊 Total games: \(appState.games.count)")
            print("📊 Total streaks: \(appState.streaks.count)")
            
            for game in appState.games {
                if let streak = appState.streaks.first(where: { $0.gameId == game.id }) {
                    print("🎮 \(game.name): streak=\(streak.currentStreak), lastPlayed=\(streak.lastPlayedDate?.description ?? "none")")
                } else {
                    print("🎮 \(game.name): no streak")
                }
            }
            
            await appState.checkAndScheduleStreakReminders()
            print("✅ Streak reminder check completed")
        } else {
            print("❌ Could not access AppState")
        }
    }
    
    func forceScheduleWordle() async {
        guard await NotificationScheduler.shared.checkPermissionStatus() == .authorized else {
            print("❌ Notifications not authorized")
            return
        }
        
        // Find Wordle game
        guard let wordleGame = appState?.games.first(where: { $0.name.lowercased().contains("wordle") }) else {
            print("❌ Wordle game not found")
            return
        }
        
        // Get Wordle's reminder settings
        let reminderSettings = getGameReminderSettings(for: wordleGame.id)
        print("🔧 Wordle reminder settings: enabled=\(reminderSettings.isEnabled), time=\(reminderSettings.preferredHour):\(String(format: "%02d", reminderSettings.preferredMinute))")
        
        if !reminderSettings.isEnabled {
            print("❌ Wordle reminders are disabled")
            return
        }
        
        // Schedule for the exact time user set (today)
        let calendar = Calendar.current
        let now = Date()
        let preferredTime = calendar.date(
            bySettingHour: reminderSettings.preferredHour, 
            minute: reminderSettings.preferredMinute, 
            second: 0, 
            of: now
        ) ?? now
        
        print("⏰ Current time: \(now)")
        print("⏰ Preferred time: \(preferredTime)")
        print("⏰ Time difference: \(preferredTime.timeIntervalSince(now)) seconds")
        
        // If time has passed, schedule for tomorrow
        let finalTime = preferredTime > now ? preferredTime : calendar.date(byAdding: .day, value: 1, to: preferredTime) ?? preferredTime
        
        print("⏰ Final scheduled time: \(finalTime)")
        
        await NotificationScheduler.shared.scheduleStreakReminder(for: wordleGame, at: finalTime)
        print("✅ Force scheduled Wordle reminder for \(finalTime)")
    }
    
    // MARK: - Game Reminder Settings
    func getGameReminderSettings(for gameId: UUID) -> GameReminderSettings {
        return gameReminderSettings[gameId] ?? GameReminderSettings()
    }
    
    func updateGameReminderSettings(for gameId: UUID, settings: GameReminderSettings) {
        gameReminderSettings[gameId] = settings
        saveGameReminderSettings()
        
        // Automatically schedule reminders when individual game settings are updated
        Task {
            if let appState = appState {
                await appState.checkAndScheduleStreakReminders()
                logger.info("🔄 Auto-scheduled streak reminders after game settings update")
            }
        }
    }
    
    private func loadGameReminderSettings() {
        // Load from UserDefaults
        for key in userDefaults.dictionaryRepresentation().keys {
            if key.hasPrefix(SettingsKeys.gameReminderPrefix) {
                let gameIdString = String(key.dropFirst(SettingsKeys.gameReminderPrefix.count))
                guard let gameId = UUID(uuidString: gameIdString),
                      let data = userDefaults.data(forKey: key),
                      let settings = try? JSONDecoder().decode(GameReminderSettings.self, from: data) else {
                    continue
                }
                gameReminderSettings[gameId] = settings
            }
        }
    }
    
    private func saveGameReminderSettings() {
        for (gameId, settings) in gameReminderSettings {
            let key = SettingsKeys.gameReminderPrefix + gameId.uuidString
            if let data = try? JSONEncoder().encode(settings) {
                userDefaults.set(data, forKey: key)
            }
        }
    }
}

// MARK: - Game Reminder Settings Model
struct GameReminderSettings: Codable {
    var isEnabled: Bool = false
    var preferredHour: Int = 19 // 7 PM
    var preferredMinute: Int = 0
    var daysOfWeek: Set<Int> = Set(1...7) // All days
    var frequency: ReminderFrequency = .daily
    
    enum ReminderFrequency: String, CaseIterable, Codable {
        case daily = "daily"
        case weekdays = "weekdays"
        case weekends = "weekends"
        case custom = "custom"
        
        var displayName: String {
            switch self {
            case .daily: return "Daily"
            case .weekdays: return "Weekdays Only"
            case .weekends: return "Weekends Only"
            case .custom: return "Custom"
            }
        }
    }
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
                    globalToggleSection
                    
                    if viewModel.notificationsEnabled {
                        globalSettingsSection
                        perGameSettingsSection
                    }
                }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    viewModel.saveSettings()
                    dismiss()
                }
            }
        }
        .onAppear {
            viewModel.setAppState(appState)
        }
        .sheet(isPresented: $viewModel.showPermissionFlow) {
            NotificationPermissionFlowView()
        }
        .sheet(isPresented: $viewModel.showPermissionDenied) {
            NotificationPermissionDeniedView()
        }
        .popover(isPresented: $viewModel.showDigestHelp) {
            DigestHelpView()
        }
        .popover(isPresented: $viewModel.showStreakMaintenanceHelp) {
            StreakMaintenanceHelpView()
        }
        .popover(isPresented: $viewModel.showQuietHoursHelp) {
            QuietHoursHelpView()
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
    
    // MARK: - Global Toggle Section
    private var globalToggleSection: some View {
        Section {
            Toggle("Enable Notifications", isOn: $viewModel.notificationsEnabled)
                .font(.headline)
        }
    }
    
    // MARK: - Global Settings Section
    private var globalSettingsSection: some View {
        Section("General Settings") {
            // Streak Maintenance
            HStack {
                Toggle("Maintain Streaks", isOn: $viewModel.streakMaintenanceEnabled)
                
                Button(action: {
                    viewModel.showStreakMaintenanceHelp = true
                }) {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.secondary)
                }
            }
            
            
            
            // Quiet Hours
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Toggle("Quiet Hours", isOn: $viewModel.quietHoursEnabled)
                        .font(.headline)
                    
                    Button(action: {
                        viewModel.showQuietHoursHelp = true
                    }) {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(.secondary)
                    }
                }
                
                if viewModel.quietHoursEnabled {
                    HStack {
                        DatePicker("Start", selection: Binding(
                            get: { Calendar.current.date(bySettingHour: viewModel.quietHoursStart, minute: 0, second: 0, of: Date()) ?? Date() },
                            set: { viewModel.quietHoursStart = Calendar.current.component(.hour, from: $0) }
                        ), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        
                        Text("to")
                            .foregroundColor(.secondary)
                        
                        DatePicker("End", selection: Binding(
                            get: { Calendar.current.date(bySettingHour: viewModel.quietHoursEnd, minute: 0, second: 0, of: Date()) ?? Date() },
                            set: { viewModel.quietHoursEnd = Calendar.current.component(.hour, from: $0) }
                        ), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                    }
                }
            }
            
            // Digest Mode
            HStack {
                Toggle("Digest Mode", isOn: $viewModel.enableDigest)
                
                Button(action: {
                    viewModel.showDigestHelp = true
                }) {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.secondary)
                }
            }
            
            // Test Notification Buttons (Debug)
            #if DEBUG
            Button("Preview Digest Notification") {
                Task {
                    let gamesAtRisk = appState.streaks
                        .filter { $0.currentStreak == 1 && !Calendar.current.isDateInToday($0.lastPlayedDate ?? .distantPast) }
                        .compactMap { streak in appState.games.first { $0.id == streak.gameId } }
                    await NotificationScheduler.shared.scheduleDigestPreview(for: gamesAtRisk)
                }
            }
            .foregroundColor(.purple)
            
            Button("Test Quiet Hours Adjustment") {
                let now = Date()
                let nineThirtyPM = Calendar.current.date(bySettingHour: 21, minute: 30, second: 0, of: now) ?? now
                let adjusted = NotificationScheduler.shared.adjustedDeliveryDate(for: nineThirtyPM)
                print("🕘 Quiet Hours Test: input=\(nineThirtyPM), adjusted=\(adjusted)")
            }
            .foregroundColor(.brown)
            
            Button("Test Notification") {
                Task {
                    await viewModel.sendTestNotification()
                }
            }
            .foregroundColor(.blue)
            
            Button("Custom Wordle Notification") {
                Task {
                    await viewModel.sendCustomWordleNotification()
                }
            }
            .foregroundColor(.green)
            
            Button("Check Streak Reminders") {
                Task {
                    await viewModel.checkStreakReminders()
                }
            }
            .foregroundColor(.orange)
            
            Button("Force Schedule Wordle") {
                Task {
                    await viewModel.forceScheduleWordle()
                }
            }
            .foregroundColor(.red)
            #endif
        }
    }
    
    // MARK: - Per-Game Settings Section
    private var perGameSettingsSection: some View {
        Section("Game Reminders") {
            ForEach(appState.games) { game in
                GameReminderRow(
                    game: game,
                    settings: viewModel.getGameReminderSettings(for: game.id),
                    onSettingsChanged: { newSettings in
                        viewModel.updateGameReminderSettings(for: game.id, settings: newSettings)
                    }
                )
            }
        }
    }
}

// MARK: - Game Reminder Row
struct GameReminderRow: View {
    let game: Game
    let settings: GameReminderSettings
    let onSettingsChanged: (GameReminderSettings) -> Void
    
    @State private var showingDetail = false
    @State private var currentSettings: GameReminderSettings
    
    init(game: Game, settings: GameReminderSettings, onSettingsChanged: @escaping (GameReminderSettings) -> Void) {
        self.game = game
        self.settings = settings
        self.onSettingsChanged = onSettingsChanged
        self._currentSettings = State(initialValue: settings)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                GameIcon(game: game, size: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(game.name)
                        .font(.headline)
                    
                    Text(settingsDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { currentSettings.isEnabled },
                    set: { newValue in
                        currentSettings.isEnabled = newValue
                        onSettingsChanged(currentSettings)
                    }
                ))
            }
            
            if currentSettings.isEnabled {
                Button("Customize") {
                    showingDetail = true
                }
                .font(.caption)
                .foregroundColor(.accentColor)
            }
        }
        .sheet(isPresented: $showingDetail) {
            GameReminderDetailView(
                game: game,
                settings: $currentSettings,
                onSave: {
                    onSettingsChanged(currentSettings)
                    showingDetail = false
                }
            )
        }
    }
    
    private var settingsDescription: String {
        if !currentSettings.isEnabled {
            return "Reminders disabled"
        }
        
        let timeString = String(format: "%02d:%02d", currentSettings.preferredHour, currentSettings.preferredMinute)
        return "\(currentSettings.frequency.displayName) at \(timeString)"
    }
}

// MARK: - Game Reminder Detail View
struct GameReminderDetailView: View {
    let game: Game
    @Binding var settings: GameReminderSettings
    let onSave: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Reminder Time") {
                    DatePicker("Preferred Time", selection: Binding(
                        get: { Calendar.current.date(bySettingHour: settings.preferredHour, minute: settings.preferredMinute, second: 0, of: Date()) ?? Date() },
                        set: { date in
                            settings.preferredHour = Calendar.current.component(.hour, from: date)
                            settings.preferredMinute = Calendar.current.component(.minute, from: date)
                        }
                    ), displayedComponents: .hourAndMinute)
                }
                
                Section("Frequency") {
                    Picker("Frequency", selection: $settings.frequency) {
                        ForEach(GameReminderSettings.ReminderFrequency.allCases, id: \.self) { frequency in
                            Text(frequency.displayName).tag(frequency)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                if settings.frequency == .custom {
                    Section("Days of Week") {
                        ForEach(1...7, id: \.self) { day in
                            let dayName = Calendar.current.weekdaySymbols[day - 1]
                            Toggle(dayName, isOn: Binding(
                                get: { settings.daysOfWeek.contains(day) },
                                set: { isOn in
                                    if isOn {
                                        settings.daysOfWeek.insert(day)
                                    } else {
                                        settings.daysOfWeek.remove(day)
                                    }
                                }
                            ))
                        }
                    }
                }
            }
            .navigationTitle(game.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave()
                    }
                }
            }
        }
    }
}

// MARK: - Help Views
struct DigestHelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Digest Mode")
                .font(.headline)
                .fontWeight(.bold)
            
            Text("When enabled, multiple notifications will be grouped into a single daily summary instead of sending individual notifications throughout the day.")
                .font(.body)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Example:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Instead of receiving 3 separate notifications:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("• Wordle streak reminder")
                    Text("• Connections streak reminder") 
                    Text("• Achievement unlocked!")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 8)
                
                Text("You'll receive one summary:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                
                Text("📧 Daily Summary: 2 streak reminders, 1 achievement")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.leading, 8)
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 300, height: 400)
    }
}

struct StreakMaintenanceHelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Maintain Streaks")
                .font(.headline)
                .fontWeight(.bold)
            
            Text("Get notified for ALL games when your streaks are at risk of being lost. This is a global setting that enables streak reminders for every game you play.")
                .font(.body)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("When you'll be notified:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("• For ALL games with active streaks")
                    Text("• When you haven't played in 20+ hours")
                    Text("• At your preferred play time for each game")
                    Text("• Only if individual game reminders are enabled")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 8)
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 300, height: 300)
    }
}

// FavoriteGamesHelpView removed

struct QuietHoursHelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quiet Hours")
                .font(.headline)
                .fontWeight(.bold)
            
            Text("Set specific hours when you don't want to receive notifications. Notifications scheduled during quiet hours will be delayed until the quiet period ends.")
                .font(.body)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Example:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("If you set quiet hours from 10 PM to 8 AM:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("• Notifications at 11 PM → delayed to 8 AM")
                    Text("• Notifications at 2 PM → sent immediately")
                    Text("• Notifications at 7 AM → delayed to 8 AM")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 8)
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 300, height: 350)
    }
}

#Preview {
    NotificationSettingsView()
        .environment(AppState(persistenceService: MockPersistenceService()))
}
