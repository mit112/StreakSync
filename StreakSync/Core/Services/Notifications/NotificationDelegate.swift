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
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    // MARK: - Dependencies
    weak var appState: AppState?
    weak var navigationCoordinator: NavigationCoordinator?
    
    private let logger = Logger(subsystem: "com.streaksync.app", category: "NotificationDelegate")
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    /// Called when a notification is delivered while the app is in the foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        logger.info("📱 Received notification while app is active: \(notification.request.identifier)")
        
        // Show banner, alert, and play sound so notifications stay in notification center
        completionHandler([.banner, .alert, .sound])
    }
    
    /// Called when user interacts with a notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        logger.info("👆 User interacted with notification: \(response.actionIdentifier)")
        
        let userInfo = response.notification.request.content.userInfo
        let categoryIdentifier = response.notification.request.content.categoryIdentifier
        
        Task {
            await handleNotificationResponse(
                actionIdentifier: response.actionIdentifier,
                categoryIdentifier: categoryIdentifier,
                userInfo: userInfo
            )
            
            // Call completion handler on main thread
            await MainActor.run {
                completionHandler()
            }
        }
    }
    
    // MARK: - Response Handling
    
    private func handleNotificationResponse(
        actionIdentifier: String,
        categoryIdentifier: String,
        userInfo: [AnyHashable: Any]
    ) async {
        switch actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification itself
            await handleDefaultAction(categoryIdentifier: categoryIdentifier, userInfo: userInfo)
            
        case NotificationAction.openGame.identifier:
            await handleOpenGame(userInfo: userInfo)
            
        case NotificationAction.snooze1Day.identifier:
            await handleSnooze(days: 1, userInfo: userInfo)
            
        case NotificationAction.snooze3Days.identifier:
            await handleSnooze(days: 3, userInfo: userInfo)
            
        case NotificationAction.markPlayed.identifier:
            await handleMarkPlayed(userInfo: userInfo)
            
        case NotificationAction.viewAchievement.identifier:
            await handleViewAchievement(userInfo: userInfo)
            
        default:
            logger.info("🤷 Unknown notification action: \(actionIdentifier)")
        }
    }
    
    private func handleDefaultAction(categoryIdentifier: String, userInfo: [AnyHashable: Any]) async {
        switch categoryIdentifier {
        case NotificationCategory.streakReminder.identifier:
            await handleOpenGame(userInfo: userInfo)
            
        case NotificationCategory.achievementUnlocked.identifier:
            await handleViewAchievement(userInfo: userInfo)
            
        case NotificationCategory.resultImported.identifier:
            await handleOpenGame(userInfo: userInfo)
            
        default:
            logger.info("🤷 Unknown notification category: \(categoryIdentifier)")
        }
    }
    
    private func handleOpenGame(userInfo: [AnyHashable: Any]) async {
        guard let gameIdString = userInfo["gameId"] as? String,
              let gameId = UUID(uuidString: gameIdString) else {
            logger.warning("⚠️ Missing or invalid gameId in notification userInfo")
            return
        }
        
        logger.info("🎮 Opening game: \(gameId)")
        
        // Set flag to indicate we're navigating from notification
        await MainActor.run {
            appState?.isNavigatingFromNotification = true
            navigationCoordinator?.navigateToGame(gameId: gameId)
        }
    }
    
    private func handleSnooze(days: Int, userInfo: [AnyHashable: Any]) async {
        logger.info("😴 Snoozing reminder for \(days) days")
        
        // In the simplified system, we just cancel the daily reminder
        // The next check will reschedule it if there are still games at risk
        await NotificationScheduler.shared.cancelDailyStreakReminder()
        
        // The reminder will be automatically rescheduled at the next app check
        // if there are still games with streaks at risk
    }
    
    private func handleMarkPlayed(userInfo: [AnyHashable: Any]) async {
        guard let gameIdString = userInfo["gameId"] as? String,
              let gameId = UUID(uuidString: gameIdString) else {
            logger.warning("⚠️ Missing or invalid gameId in mark played action")
            return
        }
        
        logger.info("✅ Marking game as played: \(gameId)")
        
        // In the simplified system, we just cancel the daily reminder
        // The next check will reschedule it if there are still other games at risk
        await NotificationScheduler.shared.cancelDailyStreakReminder()
        
        // Could potentially add a placeholder result here if needed
        // For now, just cancel the reminder and let the system reschedule if needed
    }
    
    private func handleViewAchievement(userInfo: [AnyHashable: Any]) async {
        guard let achievementIdString = userInfo["achievementId"] as? String,
              let achievementId = UUID(uuidString: achievementIdString) else {
            logger.warning("⚠️ Missing or invalid achievementId in notification userInfo")
            return
        }
        
        logger.info("🏆 Opening achievement: \(achievementId)")
        
        // Navigate to achievements tab and highlight the specific achievement
        await MainActor.run {
            navigationCoordinator?.navigateToAchievements(highlightId: achievementId)
        }
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
