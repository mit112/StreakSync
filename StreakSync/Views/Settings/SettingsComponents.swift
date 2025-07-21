//
//  SettingsComponents.swift
//  StreakSync
//
//  Settings-related components for the minimalist redesign
//

import SwiftUI
import UserNotifications

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
                FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Progress tracking")
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
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.blue)
                .frame(width: 28)
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
        }
    }
}

// MARK: - Data Management View
struct DataManagementView: View {
    @Environment(AppState.self) private var appState
    @State private var showExportSheet = false
    @State private var showImportPicker = false
    @State private var showClearDataAlert = false
    @State private var exportURL: URL?
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        List {
            // Export Section
            Section {
                Button {
                    exportData()
                } label: {
                    HStack {
                        Label("Export Data", systemImage: "square.and.arrow.up")
                        Spacer()
                        Text("JSON")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Button {
                    showImportPicker = true
                } label: {
                    Label("Import Data", systemImage: "square.and.arrow.down")
                }
            } header: {
                Text("Backup")
            } footer: {
                Text("Export your streak data or import from a previous backup.")
            }
            
            // Clear Data Section
            Section {
                Button(role: .destructive) {
                    showClearDataAlert = true
                } label: {
                    Label("Clear All Data", systemImage: "trash")
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Danger Zone")
            } footer: {
                Text("This will permanently delete all your streak data. This action cannot be undone.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Data & Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showExportSheet) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .alert("Clear All Data?", isPresented: $showClearDataAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                Task {
                    await appState.clearAllData()
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
    }
    
    private func exportData() {
        // Implement export functionality
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            
            let exportData = ExportData(
                version: 1,
                exportDate: Date(),
                gameResults: appState.recentResults,
                achievements: appState.achievements,
                streaks: appState.streaks
            )
            
            let data = try encoder.encode(exportData)
            
            let fileName = "StreakSync_Backup_\(Date().ISO8601Format()).json"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            
            try data.write(to: url)
            
            exportURL = url
            showExportSheet = true
            
        } catch {
            errorMessage = "Failed to export data: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func handleImport(_ result: Result<[URL], Error>) {
        // Implement import functionality
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                let _ = try decoder.decode(ExportData.self, from: data)
                
                // TODO: Implement actual import logic
                errorMessage = "Import functionality coming soon!"
                showError = true
                
            } catch {
                errorMessage = "Failed to import data: \(error.localizedDescription)"
                showError = true
            }
            
        case .failure(let error):
            errorMessage = "Failed to select file: \(error.localizedDescription)"
            showError = true
        }
    }
}

// MARK: - Export Data Model
private struct ExportData: Codable {
    let version: Int
    let exportDate: Date
    let gameResults: [GameResult]
    let achievements: [Achievement]
    let streaks: [GameStreak]
}

// MARK: - Share Sheet
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
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
