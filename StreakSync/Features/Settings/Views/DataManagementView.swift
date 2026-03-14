//
//  DataManagementView.swift
//  StreakSync
//
//  Data management — cloud sync, export/import, storage info, guest mode, clear data
//

import OSLog
import SwiftUI

// MARK: - Data Management View
struct DataManagementView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var guestSessionManager: GuestSessionManager
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
    @State private var showGuestModeConfirmation = false
    @State private var showExitGuestModeConfirmation = false

    var body: some View {
        List {
            cloudSyncSection
            exportSection
            storageInfoSection
            guestModeSection
            clearDataSection
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
        .alert("Start Guest Mode?", isPresented: $showGuestModeConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Start") {
                guestSessionManager.enterGuestMode()
            }
        } message: {
            Text("Your data will be hidden until you exit Guest Mode. The guest's data will not be synced to the cloud.")
        }
        .alert("Exit Guest Mode?", isPresented: $showExitGuestModeConfirmation) {
            Button("Discard Guest Data", role: .destructive) {
                Task {
                    _ = await guestSessionManager.exitGuestMode(exportGuestData: false)
                }
            }
            Button("Export Guest Data") {
                Task {
                    _ = await guestSessionManager.exitGuestMode(exportGuestData: true)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("What would you like to do with the guest's data?")
        }
        .alert("Connection Test", isPresented: $showTestAlert) {
            Button("OK") { }
        } message: {
            Text(testMessage)
        }
    }
}

// MARK: - Body Sections

private extension DataManagementView {

    @ViewBuilder
    var cloudSyncSection: some View {
        Section("Cloud Sync") {
            Toggle(isOn: Binding(
                get: { container.achievementSyncService.isSyncEnabled },
                set: {
                    container.achievementSyncService.enableSync($0)
                    if $0 {
                        Task {
                            await container.achievementSyncService.syncIfEnabled()
                        }
                    }
                }
            )) {
                Label("Cloud Sync", systemImage: "arrow.triangle.2.circlepath.icloud")
            }
            Text("Sync tiered achievements across your devices. Requires sign-in; safe to leave off.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Status
            do {
                let svc = container.achievementSyncService
                let statusText: String = {
                    switch svc.status {
                    case .idle:
                        return "Status: Idle"
                    case .syncing:
                        return "Status: Syncing..."
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
                        Task {
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
                        Task {
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

                // User data (GameResult) sync status
                HStack {
                    Label("Game Results Sync", systemImage: "arrow.up.arrow.down.circle")
                    Spacer()
                    switch container.gameResultSyncService.syncState {
                    case .syncing:
                        ProgressView()
                            .scaleEffect(0.8)
                    case .synced(let date):
                        Text(date.formatted(.relative(presentation: .named)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    case .offline:
                        Text("Offline")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    case .failed:
                        Text("Failed")
                            .font(.caption)
                            .foregroundStyle(.red)
                    case .notStarted:
                        Text("Not started")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Game results sync automatically across your devices. Data is private to your account.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    var exportSection: some View {
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
    }

    @ViewBuilder
    var storageInfoSection: some View {
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
                Text("\(appState.recentResults.count)")
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
    }

    @ViewBuilder
    var guestModeSection: some View {
        Section("Guest Mode") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Guest Mode")
                    .font(.headline)
                Text("Let someone else use StreakSync temporarily without touching your streaks or stats.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                DisclosureGroup("How Guest Mode Works") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your data is hidden while Guest Mode is active and restored when you exit.")
                        Text("Guest results stay local only \u{2013} they never sync to the cloud or other devices.")
                        Text("When exiting, you can discard guest data or export it as a JSON file.")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }
            }

            if guestSessionManager.isGuestMode {
                Button {
                    showExitGuestModeConfirmation = true
                } label: {
                    Label("Exit Guest Mode", systemImage: "person.crop.circle.badge.checkmark")
                }
                .tint(.orange)
            } else {
                Button {
                    showGuestModeConfirmation = true
                } label: {
                    Label("Start Guest Mode", systemImage: "person.crop.circle.badge.clock")
                }
            }
        }
    }

    @ViewBuilder
    var clearDataSection: some View {
        Section {
            Button(role: .destructive) {
                showClearDataAlert = true
            } label: {
                Label("Clear All Data", systemImage: "trash")
                    .foregroundStyle(.red)
            }
        }
    }
}

// MARK: - Export / Import Logic
private extension DataManagementView {
    func exportData() {
        guard !isExporting else { return }
        isExporting = true

        Task {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601

                let exportPayload = ExportData(
                    version: 1,
                    exportDate: Date(),
                    appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
                    gameResults: appState.recentResults,
                    achievements: appState.tieredAchievements,
                    streaks: appState.streaks,
                    favoriteGameIds: Array(container.gameCatalog.favoriteGameIDs),
                    customGames: []
                )

                let jsonData = try encoder.encode(exportPayload)

                // Create filename with timestamp
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd_HHmmss"
                let timestamp = formatter.string(from: Date())
                let fileName = "StreakSync_Backup_\(timestamp).json"

                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(fileName)

                try jsonData.write(to: tempURL)

                self.exportURL = tempURL
                self.showExportSheet = true
                self.isExporting = false
                HapticManager.shared.trigger(.achievement)

            } catch {
                self.errorMessage = "Failed to export data: \(error.localizedDescription)"
                self.showError = true
                self.isExporting = false
                HapticManager.shared.trigger(.error)
            }
        }
    }

    func handleImport(_ result: Result<[URL], Error>) {
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

    func performImport(from url: URL) async {
        do {
            guard url.startAccessingSecurityScopedResource() else {
                throw ImportError.cannotAccessFile
            }
            defer { url.stopAccessingSecurityScopedResource() }

            let jsonData = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            do {
                let importedData = try decoder.decode(ExportData.self, from: jsonData)

                try validateImportData(importedData)

                let actualCount = await importDataToAppState(importedData)

                self.isImporting = false
                self.importedItemsCount = actualCount
                self.showImportSuccess = true
                HapticManager.shared.trigger(.achievement)

            } catch let decodingError as DecodingError {
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

    func validateImportData(_ data: ExportData) throws {
        if data.version > 1 {
            throw ImportError.invalidVersion
        }

        for result in data.gameResults {
            if result.gameName.isEmpty || result.date > Date() {
                throw ImportError.corruptedData
            }
        }
    }

    func importDataToAppState(_ data: ExportData) async -> Int {
        var importCount = 0

        // Import game results (merge, don't duplicate)
        for result in data.gameResults {
            if !appState.recentResults.contains(where: { $0.id == result.id }) {
                if appState.addGameResult(result) {
                    importCount += 1
                }
            }
        }

        // Update favorite games
        for gameId in data.favoriteGameIds {
            container.gameCatalog.addFavorite(gameId)
        }

        // Rebuild streaks from imported results
        await appState.rebuildStreaksFromResults()

        // Save everything
        await appState.saveAllData()

        // Ensure games are still loaded
        if appState.games.isEmpty {
            appState.games = Game.allAvailableGames
        }

        return importCount
    }

    func showImportError(_ message: String) async {
        self.isImporting = false
        self.errorMessage = message
        self.showError = true
        HapticManager.shared.trigger(.error)
    }
}
