//
//  NotificationDelegate.swift
//  StreakSync
//
//  Handles notification interactions and foreground display
//

import Foundation
import OSLog
import SwiftUI
import UserNotifications

// MARK: - Notification Delegate
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationDelegate()
    
    // MARK: - Dependencies
    @MainActor weak var appState: AppState?
    @MainActor weak var navigationCoordinator: NavigationCoordinator?
    
    private let logger = Logger(subsystem: "com.streaksync.app", category: "NotificationDelegate")

    /// A response that arrived before `appState`/`navigationCoordinator` were wired.
    ///
    /// The delegate is claimed in `didFinishLaunchingWithOptions` because UNUserNotificationCenter
    /// requires it by then, but the dependencies are wired later from the app's async setup.
    /// iOS delivers `didReceive` exactly once, so a cold-launch tap landing in that window has to
    /// be replayed rather than silently no-op'd against nil.
    private struct PendingResponse {
        let actionIdentifier: String
        let categoryIdentifier: String
        let gameIdString: String?
        let achievementIdString: String?
    }

    @MainActor private var pendingResponse: PendingResponse?

    /// Wires the dependencies and replays a response that arrived before they existed.
    @MainActor
    func setDependencies(appState: AppState, navigationCoordinator: NavigationCoordinator) {
        self.appState = appState
        self.navigationCoordinator = navigationCoordinator

        guard let pending = pendingResponse else { return }
        pendingResponse = nil
        logger.info("Replaying notification response deferred until dependencies were ready")
        Task { @MainActor in
            await handleNotificationResponse(
                actionIdentifier: pending.actionIdentifier,
                categoryIdentifier: pending.categoryIdentifier,
                gameIdString: pending.gameIdString,
                achievementIdString: pending.achievementIdString
            )
        }
    }

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
        logger.info("Received notification while app is active: \(notification.request.identifier)")
        
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
        
        logger.info("User interacted with notification: \(actionIdentifier)")
        
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
        guard appState != nil, navigationCoordinator != nil else {
            logger.info("Notification response arrived before dependencies were wired — deferring")
            pendingResponse = PendingResponse(
                actionIdentifier: actionIdentifier,
                categoryIdentifier: categoryIdentifier,
                gameIdString: gameIdString,
                achievementIdString: achievementIdString
            )
            return
        }

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
            await handleDismissAndReschedule(gameIdString: gameIdString)
            
        case NotificationAction.viewAchievement.identifier:
            await handleViewAchievement(achievementIdString: achievementIdString)
            
        default:
            logger.info("Unknown notification action: \(actionIdentifier)")
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

        case NotificationCategory.friendActivity.identifier:
            await handleOpenFriends()

        default:
            logger.info("Unknown notification category: \(categoryIdentifier)")
        }
    }
    
    @MainActor private func handleOpenGame(gameIdString: String?) async {
        guard let gameIdString = gameIdString,
              let gameId = UUID(uuidString: gameIdString) else {
            // Multi-game streak reminders (2+ games at risk) carry no single gameId.
            // Route to the dashboard so the tap / "Play Now" isn't a dead no-op.
            logger.info("No gameId in notification - routing to dashboard")
            appState?.isNavigatingFromNotification = true
            navigationCoordinator?.navigateToDashboard()
            return
        }
        
        logger.info("Opening game: \(gameId)")
        
        // Set flag to indicate we're navigating from notification
        appState?.isNavigatingFromNotification = true
        navigationCoordinator?.navigateToGame(gameId: gameId)
    }
    
    @MainActor private func handleOpenFriends() async {
        // Expected flow when a friend-activity nudge is tapped:
        //   1. Set isNavigatingFromNotification so AppContainer.handleAppBecameActive
        //      takes the lightweight refreshDataForNotification path (and clears the
        //      flag a second later) instead of a full refresh.
        //   2. navigationCoordinator.navigateToFriends() switches to the Friends tab and
        //      pops it to root, so the leaderboard — not a stale pushed detail — is what
        //      the user lands on.
        //   3. FriendsView.task runs viewModel.load(), which refetches friends and
        //      today's leaderboard and re-arms the Firestore listeners.
        //   4. That load reassigns viewModel.leaderboard, which re-runs the nudge
        //      evaluation — the cooldown stamp written at schedule time is what keeps it
        //      from immediately scheduling another one.
        // The nudge carries no gameId, so there is deliberately no handleOpenGame here.
        logger.info("Opening Friends tab from friend activity notification")
        appState?.isNavigatingFromNotification = true
        navigationCoordinator?.navigateToFriends()
    }

    @MainActor private func handleSnooze(days: Int) async {
        logger.info("Snoozing reminder for \(days) days")
        
        // Compute user's preferred time
        let hour = UserDefaults.standard.object(forKey: AppConstants.NotificationSettings.reminderHour) as? Int ?? 19
        let minute = UserDefaults.standard.object(forKey: AppConstants.NotificationSettings.reminderMinute) as? Int ?? 0
        
        // Build content from today's at-risk games if available
        let gamesAtRisk = appState?.getGamesAtRisk() ?? []

        // Persist the snooze deadline so the daily reminder stays suppressed until it
        // elapses (checkAndScheduleStreakReminders reads this). Resumes automatically
        // on the next reschedule after the window passes.
        if let snoozedUntil = Self.snoozeDeadline(daysFromNow: days, hour: hour, minute: minute) {
            UserDefaults.standard.set(snoozedUntil, forKey: AppConstants.NotificationSettings.snoozedUntil)
        }

        // Clean up existing reminders (including the daily) before rescheduling
        await NotificationScheduler.shared.cleanupAndRescheduleNotifications()

        // Schedule a one-off snooze reminder for the requested day
        await NotificationScheduler.shared.scheduleOneOffSnoozeReminder(
            games: gamesAtRisk,
            daysFromNow: days,
            hour: hour,
            minute: minute
        )

        // Intentionally do NOT re-arm the daily reminder here. Re-arming would fire the
        // daily every day during the snooze window and duplicate on the target day,
        // defeating the snooze. The daily resumes via checkAndScheduleStreakReminders
        // once snoozedUntil elapses.
    }

    /// The moment a `days`-from-now snooze elapses, at the user's preferred reminder time.
    private static func snoozeDeadline(daysFromNow days: Int, hour: Int, minute: Int) -> Date? {
        let calendar = Calendar.current
        guard let dayStart = calendar.date(byAdding: .day, value: days, to: Date()) else { return nil }
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: dayStart)
    }
    
    @MainActor private func handleDismissAndReschedule(gameIdString: String?) async {
        guard let gameIdString = gameIdString,
              let gameId = UUID(uuidString: gameIdString) else {
            logger.warning("Missing or invalid gameId in mark played action")
            return
        }
        
        logger.info("Marking game as played: \(gameId)")
        
        // Re-evaluate schedules immediately (will cancel or reschedule as needed)
        await appState?.checkAndScheduleStreakReminders()
    }
    
    @MainActor private func handleViewAchievement(achievementIdString: String?) async {
        guard let achievementIdString = achievementIdString,
              let achievementId = UUID(uuidString: achievementIdString) else {
            logger.warning("Missing or invalid achievementId in notification")
            return
        }
        
        logger.info("Opening achievement: \(achievementId)")
        
        // Navigate to achievements tab and highlight the specific achievement
        navigationCoordinator?.navigateToAchievements(highlightId: achievementId)
    }
}
