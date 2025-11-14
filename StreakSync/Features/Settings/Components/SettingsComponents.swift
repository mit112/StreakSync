//
//  SettingsComponents.swift
//  StreakSync
//
//  Settings-related components for the minimalist redesign
//

import SwiftUI
import UserNotifications
import OSLog

// MARK: - Settings View Model
@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var notificationsEnabled = false
    @Published var streakRemindersEnabled = true
    @Published var achievementAlertsEnabled = true
    
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
        achievementAlertsEnabled = userDefaults.bool(forKey: "achievementAlertsEnabled")
    }
    
    private func loadSettings() {
        // Synchronous version for init
        streakRemindersEnabled = userDefaults.bool(forKey: "streakRemindersEnabled")
        achievementAlertsEnabled = userDefaults.bool(forKey: "achievementAlertsEnabled")
    }
    
    func saveSettings() {
        userDefaults.set(streakRemindersEnabled, forKey: "streakRemindersEnabled")
        userDefaults.set(achievementAlertsEnabled, forKey: "achievementAlertsEnabled")
    }
}

// MARK: - About View
struct AboutView: View {
    var body: some View {
        List {
            // App Info Section
            Section {
                VStack(alignment: .center, spacing: Spacing.lg) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.blue)
                    
                    VStack(spacing: Spacing.xs) {
                        Text("StreakSync")
                            .font(.title2.weight(.bold))
                        
                        Text("Track your daily puzzle streaks")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
            }
            
            // Version Section
            Section("Version") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Build")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                        .foregroundStyle(.secondary)
                }
            }
            
            // About Section
            Section("About") {
                Text("StreakSync helps you track your daily puzzle game streaks. Simply share your game results and we'll automatically track your progress.")
                    .font(.subheadline)
                    .padding(.vertical, Spacing.xs)
            }
            
            // Features Section
            Section("Features") {
                FeatureRow(icon: "square.and.arrow.up", text: "Easy result sharing")
                FeatureRow(icon: "flame.fill", text: "Automatic streak tracking")
                FeatureRow(icon: "trophy.fill", text: "Achievement system")
                FeatureRow(icon: SFSymbolCompatibility.getSymbol("chart.line.uptrend.xyaxis"), text: "Progress tracking")
            }
            
            // Links Section
            Section {
                Link(destination: URL(string: "https://streaksync.app")!) {
                    HStack {
                        Label("Website", systemImage: "globe")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Link(destination: URL(string: "https://streaksync.app/privacy")!) {
                    HStack {
                        Label("Privacy Policy", systemImage: "hand.raised")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Link(destination: URL(string: "mailto:support@streaksync.app")!) {
                    HStack {
                        Label("Contact Support", systemImage: "envelope")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Feature Row
private struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            Image.safeSystemName(icon, fallback: "gear")
                .font(.body)
                .foregroundStyle(.blue)
                .frame(width: 28)
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
        }
    }
}

// MARK: - Data Management View (FIXED)
struct DataManagementView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var container: AppContainer  // Add this!
    @State private var showExportSheet = false
    @State private var showImportPicker = false
    @State private var showClearDataAlert = false
    @State private var exportURL: URL?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var showImportSuccess = false
    @State private var importedItemsCount = 0
    @State private var showTestAlert = false
    @State private var testMessage = ""
    
    var body: some View {
        List {
            // Cloud Sync Section
            Section("Cloud Sync") {
                Toggle(isOn: Binding(
                    get: { AppConstants.Flags.cloudSyncEnabled },
                    set: {
                        AppConstants.Flags.cloudSyncEnabled = $0
                        if $0 {
                            Task { @MainActor in
                                await container.achievementSyncService.syncIfEnabled()
                            }
                        }
                    }
                )) {
                    Label("iCloud Sync (Private)", systemImage: "icloud")
                }
                Text("Sync tiered achievements privately via iCloud across your devices. Requires iCloud account; safe to leave off.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                // Status
                if let svc = container.achievementSyncService as AchievementSyncService? {
                    let statusText: String = {
                        switch svc.status {
                        case .idle:
                            return "Status: Idle"
                        case .syncing:
                            return "Status: Syncing…"
                        case .success(let date):
                            let formatter = RelativeDateTimeFormatter()
                            formatter.unitsStyle = .short
                            let rel = formatter.localizedString(for: date, relativeTo: Date())
                            return "Last synced: \(rel)"
                        case .error(let message):
                            return "Sync paused: \(message)"
                        }
                    }()
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        Button {
                            Task { @MainActor in
                                await container.achievementSyncService.syncIfEnabled()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Sync Now")
                            }
                        }
                        #if DEBUG
                        Button {
                            Task { @MainActor in
                                testMessage = await container.achievementSyncService.runConnectivityTest()
                                showTestAlert = true
                            }
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.icloud")
                                Text("Test Connection")
                            }
                        }
                        #endif
                    }
                }
            }
            // Export Section
            Section {
                Button {
                    exportData()
                } label: {
                    HStack {
                        Label("Export Data", systemImage: "square.and.arrow.up")
                        Spacer()
                        if isExporting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("JSON")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .disabled(isExporting || appState.games.isEmpty)
                
                Button {
                    showImportPicker = true
                } label: {
                    HStack {
                        Label("Import Data", systemImage: "square.and.arrow.down")
                        Spacer()
                        if isImporting {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                }
                .disabled(isImporting)
                
            } header: {
                Text("Backup")
            } footer: {
                Text("Export your streak data or import from a previous backup.")
            }
            
            // Storage Info Section
            Section {
                HStack {
                    Label("Total Games", systemImage: "gamecontroller")
                    Spacer()
                    Text("\(appState.games.count)")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Label("Game Results", systemImage: "list.bullet")
                    Spacer()
                    Text("\(appState.recentResults.count)")  // Fixed: recentResults
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Label("Tiered Achievements", systemImage: "trophy")
                    Spacer()
                    let unlockedTieredCount = appState.tieredAchievements.filter { $0.isUnlocked }.count
                    Text("\(unlockedTieredCount)")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Data Summary")
            }
            
            // Clear Data Section
            Section {
                Button(role: .destructive) {
                    showClearDataAlert = true
                } label: {
                    Label("Clear All Data", systemImage: "trash")
                        .foregroundStyle(.red)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Data & Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .sheet(isPresented: $showExportSheet) {
            if let exportURL = exportURL {
                ShareSheet(activityItems: [exportURL])
                    .ignoresSafeArea()
            }
        }
        .alert("Clear All Data?", isPresented: $showClearDataAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                Task {
                    await appState.clearAllData()
                    HapticManager.shared.trigger(.error)
                }
            }
        } message: {
                    Text("This will permanently delete all your streaks, achievements, and game data. This action cannot be undone.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .alert("Import Successful", isPresented: $showImportSuccess) {
            Button("OK") { }
        } message: {
            Text("Successfully imported \(importedItemsCount) items.")
        }
        .alert("CloudKit Connection", isPresented: $showTestAlert) {
            Button("OK") { }
        } message: {
            Text(testMessage)
        }
    }
    
    private func exportData() {
        guard !isExporting else { return }
        
        isExporting = true
        
        Task {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                
                // Gather all data - FIXED property names
                    let exportData = ExportData(
                    version: 1,
                    exportDate: Date(),
                    appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
                    gameResults: appState.recentResults,  // Fixed: recentResults
                    achievements: [],
                    streaks: appState.streaks,
                    favoriteGameIds: Array(container.gameCatalog.favoriteGameIDs),  // Fixed: use container
                    customGames: [] // For future use
                )
                
                let jsonData = try encoder.encode(exportData)
                
                // Create filename with timestamp
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd_HHmmss"
                let timestamp = formatter.string(from: Date())
                let fileName = "StreakSync_Backup_\(timestamp).json"
                
                // Save to temporary directory
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(fileName)
                
                try jsonData.write(to: tempURL)
                
                await MainActor.run {
                    self.exportURL = tempURL
                    self.showExportSheet = true
                    self.isExporting = false
                    HapticManager.shared.trigger(.achievement)
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to export data: \(error.localizedDescription)"
                    self.showError = true
                    self.isExporting = false
                    HapticManager.shared.trigger(.error)
                }
            }
        }
    }
    
    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            isImporting = true
            
            Task {
                await performImport(from: url)
            }
            
        case .failure(let error):
            errorMessage = "Failed to select file: \(error.localizedDescription)"
            showError = true
            HapticManager.shared.trigger(.error)
        }
    }
    
    private func performImport(from url: URL) async {
        do {
            // Start accessing the security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                throw ImportError.cannotAccessFile
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            // Read the data
            let jsonData = try Data(contentsOf: url)
            
            // Try to parse as JSON first to check validity
            if let jsonObject = try? JSONSerialization.jsonObject(with: jsonData),
               let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
               let jsonString = String(data: prettyData, encoding: .utf8) {
                print("JSON Preview: \(String(jsonString.prefix(500)))")
            }
            
            // Decode the data
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            do {
                let importedData = try decoder.decode(ExportData.self, from: jsonData)
                
                // Validate the data
                try validateImportData(importedData)
                
                // Import the data
                await importDataToAppState(importedData)
                
                await MainActor.run {
                    self.isImporting = false
                    self.importedItemsCount = importedData.gameResults.count +
                                             importedData.achievements.count
                    self.showImportSuccess = true
                    HapticManager.shared.trigger(.achievement)
                }
                
            } catch let decodingError as DecodingError {
                // Specific decoding error handling
                switch decodingError {
                case .keyNotFound(let key, let context):
                    await showImportError("Missing required field: \(key.stringValue)\n\nDetails: \(context.debugDescription)")
                case .typeMismatch(let type, let context):
                    await showImportError("Type mismatch for \(type)\n\nDetails: \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    await showImportError("Missing value for \(type)\n\nDetails: \(context.debugDescription)")
                case .dataCorrupted(let context):
                    await showImportError("Corrupted data\n\nDetails: \(context.debugDescription)")
                @unknown default:
                    await showImportError("Unknown decoding error: \(decodingError.localizedDescription)")
                }
            }
            
        } catch ImportError.invalidVersion {
            await showImportError("This backup was created with a newer version of StreakSync.")
        } catch ImportError.corruptedData {
            await showImportError("The backup file appears to be corrupted.")
        } catch ImportError.cannotAccessFile {
            await showImportError("Cannot access the selected file.")
        } catch {
            await showImportError("Import failed: \(error.localizedDescription)")
        }
    }
    
    private func validateImportData(_ data: ExportData) throws {
        // Check version compatibility
        if data.version > 1 {
            throw ImportError.invalidVersion
        }
        
        // Validate data integrity
        for result in data.gameResults {
            if result.gameName.isEmpty || result.date > Date() {
                throw ImportError.corruptedData
            }
        }
    }
    
    private func importDataToAppState(_ data: ExportData) async {
        var importCount = 0
        
        // Import game results (merge, don't duplicate)
        for result in data.gameResults {
            if !appState.recentResults.contains(where: { $0.id == result.id }) {
                appState.addGameResult(result)
                importCount += 1
//                logger.info("Imported game result: \(result.gameName) - \(result.date)")
            }
        }
        
        // Import achievements
                // Legacy achievements import removed (tiered-only system)
        
        // Update favorite games
        for gameId in data.favoriteGameIds {
            container.gameCatalog.addFavorite(gameId)
//            logger.info("Added favorite: \(gameId)")
        }
        
        // Rebuild streaks from imported results
        await appState.rebuildStreaksFromResults()
        
        // Save everything
        await appState.saveAllData()
        
        // Update the count to show actual imported items
        await MainActor.run {
            self.importedItemsCount = importCount
        }
        // Ensure games are still loaded
        if appState.games.isEmpty {
            
            // Re-initialize games
            appState.games = Game.allAvailableGames
        }
    }
    
    private func showImportError(_ message: String) async {
        await MainActor.run {
            self.isImporting = false
            self.errorMessage = message
            self.showError = true
            HapticManager.shared.trigger(.error)
        }
    }
}

// MARK: - Import Errors
private enum ImportError: LocalizedError {
    case invalidVersion
    case corruptedData
    case cannotAccessFile
    
    var errorDescription: String? {
        switch self {
        case .invalidVersion:
            return "Incompatible backup version"
        case .corruptedData:
            return "Corrupted backup data"
        case .cannotAccessFile:
            return "Cannot access file"
        }
    }
}

// MARK: - Enhanced Export Data Model
struct ExportData: Codable {
    let version: Int
    let exportDate: Date
    let appVersion: String
    let gameResults: [GameResult]
    let achievements: [Achievement]
    let streaks: [GameStreak]
    let favoriteGameIds: [UUID]
    let customGames: [Game] // For future use
}

// MARK: - Share Sheet (for Export)
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
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
