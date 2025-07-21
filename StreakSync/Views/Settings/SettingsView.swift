//
//  SettingsView.swift
//  StreakSync
//
//  Standard iOS settings using grouped list style
//  NOTE: Requires SettingsComponents.swift for SettingsViewModel, AboutView, and AppearanceMode
//

import SwiftUI
import UserNotifications

// MARK: - Settings View
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(AppState.self) private var appState
    
    var body: some View {
        List {
            // Notifications section
            Section {
                NavigationLink {
                    NotificationSettingsView(viewModel: viewModel)
                } label: {
                    SettingsRow(
                        icon: "bell",
                        title: "Notifications",
                        subtitle: viewModel.notificationsEnabled ? "Enabled" : "Disabled"
                    )
                }
            }
            
            // Appearance section
            Section {
                NavigationLink {
                    AppearanceSettingsView()
                } label: {
                    SettingsRow(
                        icon: "moon",
                        title: "Appearance",
                        subtitle: viewModel.appearanceMode.displayName
                    )
                }
            }
            
            // Data section
            Section {
                NavigationLink {
                    DataManagementView()
                } label: {
                    SettingsRow(
                        icon: "square.and.arrow.down",
                        title: "Data & Privacy",
                        subtitle: "Export, import, or clear data"
                    )
                }
            }
            
            // About section
            Section {
                NavigationLink {
                    AboutView()
                } label: {
                    SettingsRow(
                        icon: "info.circle",
                        title: "About",
                        subtitle: "Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")"
                    )
                }
                
                Link(destination: URL(string: "https://streaksync.app/privacy")!) {
                    SettingsRow(
                        icon: "hand.raised",
                        title: "Privacy Policy",
                        subtitle: nil
                    )
                }
                
                Link(destination: URL(string: "mailto:support@streaksync.app")!) {
                    SettingsRow(
                        icon: "envelope",
                        title: "Contact Support",
                        subtitle: nil
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .task {
            await viewModel.loadSettings()
        }
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.blue)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
    }
}

// MARK: - Notification Settings View
struct NotificationSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        List {
            Section {
                Toggle("Streak Reminders", isOn: $viewModel.streakRemindersEnabled)
                    .disabled(!viewModel.notificationsEnabled)
                
                Toggle("Achievement Alerts", isOn: $viewModel.achievementAlertsEnabled)
                    .disabled(!viewModel.notificationsEnabled)
            } footer: {
                if !viewModel.notificationsEnabled {
                    Text("Enable notifications in iOS Settings to receive alerts.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}


// MARK: - Preview
#Preview {
    NavigationStack {
        SettingsView()
            .environment(NavigationCoordinator())
    }
}
