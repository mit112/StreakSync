//
//  NotificationNudgeView.swift
//  StreakSync
//
//  Contextual nudge to suggest enabling notifications
//

import SwiftUI
import UserNotifications
import OSLog

// MARK: - Notification Nudge View Model
@MainActor
final class NotificationNudgeViewModel: ObservableObject {
    @Published var shouldShowNudge = false
    @Published var showingPermissionFlow = false
    
    private let logger = Logger(subsystem: "com.streaksync.app", category: "NotificationNudge")
    
    func checkShouldShowNudge() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let hasShownNudge = UserDefaults.standard.bool(forKey: "hasShownNotificationNudge")
        
        // Show nudge if:
        // 1. Notifications are not authorized
        // 2. User hasn't been shown the nudge before
        // 3. User has been using the app for at least 3 days (to avoid being pushy)
        shouldShowNudge = settings.authorizationStatus != .authorized && 
                        !hasShownNudge && 
                        shouldShowBasedOnUsage()
    }
    
    func markNudgeAsShown() {
        UserDefaults.standard.set(true, forKey: "hasShownNotificationNudge")
        shouldShowNudge = false
    }
    
    func dismissNudge() {
        markNudgeAsShown()
    }
    
    private func shouldShowBasedOnUsage() -> Bool {
        let firstLaunch = UserDefaults.standard.object(forKey: "firstLaunchDate") as? Date
        let now = Date()
        
        if firstLaunch == nil {
            UserDefaults.standard.set(now, forKey: "firstLaunchDate")
            return false
        }
        
        let daysSinceFirstLaunch = Calendar.current.dateComponents([.day], from: firstLaunch!, to: now).day ?? 0
        return daysSinceFirstLaunch >= 3
    }
}

// MARK: - Notification Nudge View
struct NotificationNudgeView: View {
    @StateObject private var viewModel = NotificationNudgeViewModel()
    @State private var isDismissed = false
    
    var body: some View {
        if viewModel.shouldShowNudge && !isDismissed {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "bell.badge")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Stay on Track")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Get gentle reminders to keep your streaks alive")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        viewModel.showingPermissionFlow = true
                    } label: {
                        Text("Enable")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    
                    Button {
                        withAnimation(.easeOut(duration: 0.3)) {
                            isDismissed = true
                            viewModel.dismissNudge()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isDismissed)
            .sheet(isPresented: $viewModel.showingPermissionFlow) {
                NotificationPermissionFlowView()
                    .onDisappear {
                        Task {
                            await viewModel.checkShouldShowNudge()
                        }
                    }
            }
            .task {
                await viewModel.checkShouldShowNudge()
            }
        }
    }
}

// MARK: - Game-Specific Nudge
struct GameNotificationNudgeView: View {
    let game: Game
    @State private var showingPermissionFlow = false
    @State private var isDismissed = false
    
    private var hasShownForGame: Bool {
        UserDefaults.standard.bool(forKey: "hasShownNotificationNudge_\(game.id.uuidString)")
    }
    
    var body: some View {
        if !hasShownForGame && !isDismissed {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    GameIcon(game: game, size: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Daily reminder for \(game.name)?")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text("Get notified when it's time to play")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Remind Me") {
                        showingPermissionFlow = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .font(.caption)
                    
                    Button {
                        withAnimation(.easeOut(duration: 0.3)) {
                            isDismissed = true
                            UserDefaults.standard.set(true, forKey: "hasShownNotificationNudge_\(game.id.uuidString)")
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isDismissed)
            .sheet(isPresented: $showingPermissionFlow) {
                NotificationPermissionFlowView()
            }
        }
    }
}

// MARK: - Streak Risk Nudge
struct StreakRiskNudgeView: View {
    let game: Game
    let streakCount: Int
    @State private var showingPermissionFlow = false
    @State private var isDismissed = false
    
    private var isAtRisk: Bool {
        // Consider streak at risk if last played more than 20 hours ago
        guard let lastResult = game.recentResults.first else { return false }
        let hoursSinceLastPlay = Date().timeIntervalSince(lastResult.date) / 3600
        return hoursSinceLastPlay > 20 && hoursSinceLastPlay < 24
    }
    
    var body: some View {
        if isAtRisk && !isDismissed {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(game.name) streak at risk")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text("Play within 4 hours to keep your \(streakCount)-day streak")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Set Reminder") {
                        showingPermissionFlow = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .font(.caption2)
                    
                    Button {
                        withAnimation(.easeOut(duration: 0.3)) {
                            isDismissed = true
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isDismissed)
            .sheet(isPresented: $showingPermissionFlow) {
                NotificationPermissionFlowView()
            }
        }
    }
}

#Preview("General Nudge") {
    VStack {
        NotificationNudgeView()
        Spacer()
    }
}

#Preview("Game Nudge") {
    VStack {
        GameNotificationNudgeView(game: Game.sample)
        Spacer()
    }
}

#Preview("Streak Risk Nudge") {
    VStack {
        StreakRiskNudgeView(game: Game.sample, streakCount: 7)
        Spacer()
    }
}
