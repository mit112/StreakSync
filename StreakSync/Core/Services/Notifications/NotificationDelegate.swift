//
//  NotificationDelegate.swift
//  StreakSync
//
//  Handles notification interactions and foreground display
//

import Foundation
import UserNotifications
import OSLog
import SwiftUI

// MARK: - Notification Delegate
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationDelegate()
    
    // MARK: - Dependencies
    @MainActor weak var appState: AppState?
    @MainActor weak var navigationCoordinator: NavigationCoordinator?
    
    private let logger = Logger(subsystem: "com.streaksync.app", category: "NotificationDelegate")

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    /// Called when a notification is delivered while the app is in the foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        logger.info("📱 Received notification while app is active: \(notification.request.identifier)")
        
        // Show banner, list, and play sound so notifications stay in notification center
        completionHandler([.banner, .list, .sound])
    }
    
    /// Called when user interacts with a notification
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionIdentifier = response.actionIdentifier
        let categoryIdentifier = response.notification.request.content.categoryIdentifier
        // Extract Sendable values before crossing isolation boundary
        let gameIdString = response.notification.request.content.userInfo["gameId"] as? String
        let achievementIdString = response.notification.request.content.userInfo["achievementId"] as? String
        
        logger.info("👆 User interacted with notification: \(actionIdentifier)")
        
        Task { @MainActor in
            await handleNotificationResponse(
                actionIdentifier: actionIdentifier,
                categoryIdentifier: categoryIdentifier,
                gameIdString: gameIdString,
                achievementIdString: achievementIdString
            )
        }
        
        // Call completion handler immediately (doesn't need to wait for async work)
        completionHandler()
    }
    
    // MARK: - Response Handling
    
    @MainActor private func handleNotificationResponse(
        actionIdentifier: String,
        categoryIdentifier: String,
        gameIdString: String?,
        achievementIdString: String?
    ) async {
        switch actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification itself
            await handleDefaultAction(categoryIdentifier: categoryIdentifier, gameIdString: gameIdString, achievementIdString: achievementIdString)
            
        case NotificationAction.openGame.identifier:
            await handleOpenGame(gameIdString: gameIdString)
            
        case NotificationAction.snooze1Day.identifier:
            await handleSnooze(days: 1)
            
        case NotificationAction.snooze3Days.identifier:
            await handleSnooze(days: 3)
            
        case NotificationAction.markPlayed.identifier:
            await handleMarkPlayed(gameIdString: gameIdString)
            
        case NotificationAction.viewAchievement.identifier:
            await handleViewAchievement(achievementIdString: achievementIdString)
            
        default:
            logger.info("🤷 Unknown notification action: \(actionIdentifier)")
        }
    }
    
    @MainActor private func handleDefaultAction(categoryIdentifier: String, gameIdString: String?, achievementIdString: String?) async {
        switch categoryIdentifier {
        case NotificationCategory.streakReminder.identifier:
            await handleOpenGame(gameIdString: gameIdString)
            
        case NotificationCategory.achievementUnlocked.identifier:
            await handleViewAchievement(achievementIdString: achievementIdString)
            
        case NotificationCategory.resultImported.identifier:
            await handleOpenGame(gameIdString: gameIdString)
            
        default:
            logger.info("🤷 Unknown notification category: \(categoryIdentifier)")
        }
    }
    
    @MainActor private func handleOpenGame(gameIdString: String?) async {
        guard let gameIdString = gameIdString,
              let gameId = UUID(uuidString: gameIdString) else {
            logger.warning("⚠️ Missing or invalid gameId in notification")
            return
        }
        
        logger.info("🎮 Opening game: \(gameId)")
        
        // Set flag to indicate we're navigating from notification
        appState?.isNavigatingFromNotification = true
        navigationCoordinator?.navigateToGame(gameId: gameId)
    }
    
    @MainActor private func handleSnooze(days: Int) async {
        logger.info("😴 Snoozing reminder for \(days) days")
        
        // Cancel the repeating daily reminder and schedule a one-off for +days
        await NotificationScheduler.shared.cancelDailyStreakReminder()
        
        // Compute user's preferred time
        let hour = UserDefaults.standard.object(forKey: "streakReminderHour") as? Int ?? 19
        let minute = UserDefaults.standard.object(forKey: "streakReminderMinute") as? Int ?? 0
        
        // Build content from today's at-risk games if available
        let gamesAtRisk = appState?.getGamesAtRisk() ?? []
        await NotificationScheduler.shared.scheduleOneOffSnoozeReminder(
            games: gamesAtRisk,
            daysFromNow: days,
            hour: hour,
            minute: minute
        )
    }
    
    @MainActor private func handleMarkPlayed(gameIdString: String?) async {
        guard let gameIdString = gameIdString,
              let gameId = UUID(uuidString: gameIdString) else {
            logger.warning("⚠️ Missing or invalid gameId in mark played action")
            return
        }
        
        logger.info("✅ Marking game as played: \(gameId)")
        
        // Re-evaluate schedules immediately (will cancel or reschedule as needed)
        await appState?.checkAndScheduleStreakReminders()
    }
    
    @MainActor private func handleViewAchievement(achievementIdString: String?) async {
        guard let achievementIdString = achievementIdString,
              let achievementId = UUID(uuidString: achievementIdString) else {
            logger.warning("⚠️ Missing or invalid achievementId in notification")
            return
        }
        
        logger.info("🏆 Opening achievement: \(achievementId)")
        
        // Navigate to achievements tab and highlight the specific achievement
        navigationCoordinator?.navigateToAchievements(highlightId: achievementId)
    }
}

// MARK: - In-App Notification Banner
struct InAppNotificationBanner: View {
    let title: String
    let message: String
    let action: (() -> Void)?
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "bell.fill")
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let action = action {
                    Button("View") {
                        action()
                        isPresented = false
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            
            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isPresented)
    }
}

#Preview {
    InAppNotificationBanner(
        title: "Streak Reminder",
        message: "Keep your Wordle streak alive!",
        action: { print("View tapped") },
        isPresented: .constant(true)
    )
}
