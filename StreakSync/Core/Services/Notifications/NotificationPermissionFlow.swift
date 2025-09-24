//
//  NotificationPermissionFlow.swift
//  StreakSync
//
//  In-app permission flow with clear benefits and user control
//

import SwiftUI
import UserNotifications
import OSLog

// MARK: - Permission Flow View Model
@MainActor
final class NotificationPermissionFlowViewModel: ObservableObject {
    @Published var showingPermissionFlow = false
    @Published var permissionStatus: UNAuthorizationStatus = .notDetermined
    
    private let logger = Logger(subsystem: "com.streaksync.app", category: "NotificationPermission")
    
    func checkPermissionStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        permissionStatus = settings.authorizationStatus
    }
    
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            
            await checkPermissionStatus()
            
            if granted {
                logger.info("✅ Notification permission granted")
                // Register notification categories
                await NotificationScheduler.shared.registerCategories()
            } else {
                logger.warning("⚠️ Notification permission denied")
            }
            
            return granted
        } catch {
            logger.error("❌ Failed to request notification permission: \(error.localizedDescription)")
            return false
        }
    }
    
    func openSystemSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

// MARK: - Permission Flow View
struct NotificationPermissionFlowView: View {
    @StateObject private var viewModel = NotificationPermissionFlowViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "bell.badge")
                        .font(.system(size: 60))
                        .foregroundColor(.accentColor)
                    
                    Text("Stay on Track")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Get gentle reminders to keep your streaks alive")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                // Benefits
                VStack(spacing: 16) {
                    BenefitRow(
                        icon: "clock",
                        title: "Smart Timing",
                        description: "Reminders based on when you usually play"
                    )
                    
                    BenefitRow(
                        icon: "shield.checkered",
                        title: "Streak Protection",
                        description: "Gentle nudge when your streak is at risk"
                    )
                    
                    BenefitRow(
                        icon: "slider.horizontal.3",
                        title: "Full Control",
                        description: "Customize per game, quiet hours, and frequency"
                    )
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Controls
                VStack(spacing: 12) {
                    Button("Enable Notifications") {
                        Task {
                            let granted = await viewModel.requestPermission()
                            if granted {
                                dismiss()
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button("Not Now") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await viewModel.checkPermissionStatus()
        }
    }
}

// MARK: - Benefit Row
struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Permission Denied View
struct NotificationPermissionDeniedView: View {
    @StateObject private var viewModel = NotificationPermissionFlowViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.slash")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("Notifications Disabled")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("To enable reminders, please allow notifications in Settings")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Open Settings") {
                viewModel.openSystemSettings()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
}

#Preview {
    NotificationPermissionFlowView()
}
