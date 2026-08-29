//
//  NotificationScheduler+Social.swift
//  StreakSync
//
//  Friend-activity nudge — the social counterpart to the daily streak reminder
//

import Foundation
import UserNotifications

// MARK: - Nudge

/// A friend-activity nudge that passed every eligibility gate and is ready to schedule.
struct FriendActivityNudge: Equatable {
    /// Distinct friends who posted at least one score today.
    let friendCount: Int
    /// Games those friends played, most-played first. Empty when a played game is no
    /// longer in the catalog.
    let gameNames: [String]
    let title: String
    let body: String
}

// MARK: - Decision Input

/// Everything the nudge decision needs.
///
/// All of it comes from state the app already holds — the Friends tab's loaded leaderboard,
/// local `AppState`, and `UserDefaults` — so deciding costs no extra network round trip.
/// There is no remote push in this app and none is added here.
struct FriendActivityNudgeInput {
    /// The user's opt-out toggle, resolved via `FriendActivityNudgePolicy.isEnabled`.
    let isEnabled: Bool
    /// Accepted friends' user IDs. `listFriends()` never includes the current user.
    let friendUserIds: Set<String>
    /// Today's leaderboard rows. Includes the current user, and can include former
    /// friends who are still in an `allowedReaders` array.
    let todaysLeaderboard: [LeaderboardRow]
    /// Display name per game ID, used to name games in the body copy.
    let gameNamesById: [UUID: String]
    /// True when the user has logged any result today.
    let userPlayedToday: Bool
    /// True when a streak reminder — the repeating daily one or a one-off snooze — is
    /// already pending. Both share the `STREAK_REMINDER` category.
    let streakReminderPending: Bool
    /// When the last nudge was scheduled; `nil` if one never has been.
    let lastNudgeAt: Date?
    let now: Date
    /// `var` rather than `let`, deliberately: a `let` with an assigned default is
    /// excluded from the memberwise initializer, which would make the calendar
    /// impossible to inject and the cooldown's calendar-day semantics untestable
    /// across time zones and DST boundaries.
    var calendar: Calendar = .autoupdatingCurrent
}

// MARK: - Policy

/// Pure decision logic for the friend-activity nudge.
///
/// Deliberately free of `UNUserNotificationCenter` so both the eligibility rules and the
/// copy are unit-testable without touching the notification system.
enum FriendActivityNudgePolicy {
    /// One friend playing is noise; two or more is a real "everyone is playing" signal.
    /// It also keeps the copy plural and keeps individual friends unnamed.
    static let minimumFriendsWhoPlayed = 2

    /// Minimum whole calendar days between nudges. Stricter than a one-per-day cap on
    /// purpose: someone who ignored a nudge should not be pinged again the next evening.
    static let minimumDaysBetweenNudges = 3

    static let notificationTitle = "Friends are playing"

    /// Resolves the user's opt-out toggle.
    ///
    /// Default ON, matching `remindersEnabled` — the streak reminder is opt-out and this
    /// is its counterpart. Read through `object(forKey:)` rather than `bool(forKey:)` so
    /// an unset key resolves to the default instead of `bool`'s implicit `false`; that
    /// keeps installs which already ran `migrateNotificationSettings` consistent with
    /// fresh ones. Mirrors how `reminderHour` defaults to 19.
    static func isEnabled(defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: AppConstants.NotificationSettings.friendActivityNudgeEnabled) as? Bool ?? true
    }

    /// The single entry point. Returns `nil` — schedule nothing — unless every gate passes.
    /// `nil` is the common case by design.
    static func decide(_ input: FriendActivityNudgeInput) -> FriendActivityNudge? {
        guard input.isEnabled,
              !input.friendUserIds.isEmpty,
              !input.userPlayedToday,
              !input.streakReminderPending,
              isPastCooldown(lastNudgeAt: input.lastNudgeAt, now: input.now, calendar: input.calendar)
        else { return nil }

        let activity = summarize(
            leaderboard: input.todaysLeaderboard,
            friendUserIds: input.friendUserIds,
            gameNamesById: input.gameNamesById
        )
        guard activity.friendCount >= minimumFriendsWhoPlayed else { return nil }

        return FriendActivityNudge(
            friendCount: activity.friendCount,
            gameNames: activity.gameNames,
            title: notificationTitle,
            body: makeBody(friendCount: activity.friendCount, gameNames: activity.gameNames)
        )
    }

    /// True when enough whole calendar days have passed since the last nudge.
    /// Compared at start-of-day, so 23:00 one night and 07:00 the next morning are one
    /// day apart rather than zero.
    static func isPastCooldown(lastNudgeAt: Date?, now: Date, calendar: Calendar) -> Bool {
        guard let lastNudgeAt else { return true }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: lastNudgeAt),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        return days >= minimumDaysBetweenNudges
    }

    /// Distinct friends who played today, plus the games they played, most-played first.
    ///
    /// A game ID present in `perGameBreakdown` means a score was posted for it — even a
    /// failed one worth zero points, because a failed attempt is still playing. That is
    /// why this checks key presence rather than `points > 0` the way the leaderboard
    /// ranking does.
    static func summarize(
        leaderboard: [LeaderboardRow],
        friendUserIds: Set<String>,
        gameNamesById: [UUID: String]
    ) -> (friendCount: Int, gameNames: [String]) {
        var friendsWhoPlayed: Set<String> = []
        var friendsPerGame: [UUID: Int] = [:]
        for row in leaderboard where friendUserIds.contains(row.userId) {
            guard !row.perGameBreakdown.isEmpty else { continue }
            friendsWhoPlayed.insert(row.userId)
            for gameId in row.perGameBreakdown.keys {
                friendsPerGame[gameId, default: 0] += 1
            }
        }

        let names = friendsPerGame
            .compactMap { gameId, count -> (name: String, count: Int)? in
                guard let name = gameNamesById[gameId] else { return nil }
                return (name: name, count: count)
            }
            .sorted { $0.count == $1.count ? $0.name < $1.name : $0.count > $1.count }
            .map(\.name)

        return (friendCount: friendsWhoPlayed.count, gameNames: names)
    }

    /// Body copy. Mirrors `buildStreakReminderContent`'s shape: name up to three games,
    /// then collapse the tail into an "and N other games" count.
    static func makeBody(friendCount: Int, gameNames: [String]) -> String {
        let lead = friendCount == 1
            ? "1 friend has played today"
            : "\(friendCount) friends have played today"

        if gameNames.isEmpty {
            return lead
        }
        if gameNames.count <= 3 {
            return "\(lead) — \(gameNames.joined(separator: ", "))"
        }
        let firstTwo = gameNames.prefix(2).joined(separator: ", ")
        let remaining = gameNames.count - 2
        return "\(lead) — \(firstTwo), and \(remaining) other game\(remaining > 1 ? "s" : "")"
    }
}

// MARK: - Scheduling

extension NotificationScheduler {
    /// Fixed identifier: adding a second request under it replaces the first, so at most
    /// one friend-activity nudge can ever be pending.
    static let friendActivityNudgeIdentifier = "friend_activity_nudge"

    /// Never fire a nudge that lands within five minutes of the evaluation — a
    /// notification arriving the instant the user closes the app reads as surveillance.
    static let friendActivityMinimumLeadTime: TimeInterval = 5 * 60

    /// Tap-only, like `resultImported`: the nudge is about the leaderboard as a whole and
    /// has no per-item action worth surfacing. Computed rather than stored so it needs no
    /// `Sendable` conformance from `UNNotificationCategory`.
    static var friendActivityCategory: UNNotificationCategory {
        UNNotificationCategory(
            identifier: NotificationCategory.friendActivity.identifier,
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
    }

    /// Schedules at most one friend-activity nudge for today, or — far more often —
    /// nothing at all.
    ///
    /// Expected flow once the Friends tab holds today's leaderboard:
    ///   1. Bail unless notifications are authorized — the same guard every other
    ///      scheduling entry point in `NotificationScheduler` opens with.
    ///   2. Read the opt-out toggle, the last-nudge stamp and the pending request list,
    ///      and pair them with the caller's already-loaded friends / leaderboard /
    ///      played-today facts. No network call is made here.
    ///   3. `FriendActivityNudgePolicy.decide` applies every gate and builds the copy.
    ///      `nil` means schedule nothing.
    ///   4. Resolve today's fire time from the user's existing reminder hour/minute via
    ///      the DST-safe `resolveOneOffReminderDate`; skip if it has already passed, and
    ///      leave the cooldown stamp untouched so tomorrow can try again.
    ///   5. Add one non-repeating `UNCalendarNotificationTrigger` under a fixed
    ///      identifier, then stamp `friendActivityLastNudgeAt` to start the cooldown.
    ///   6. A tap goes to `NotificationDelegate.handleDefaultAction` (category
    ///      `FRIEND_ACTIVITY`) → `NavigationCoordinator.navigateToFriends()` → the
    ///      Friends tab, popped to root → `FriendsView.task` reloads the leaderboard.
    func scheduleFriendActivityNudgeIfNeeded(
        friends: [UserProfile],
        todaysLeaderboard: [LeaderboardRow],
        userPlayedToday: Bool,
        now: Date = Date()
    ) async {
        guard await checkPermissionStatus() == .authorized else {
            logger.debug("Friend activity nudge skipped: notifications not authorized")
            return
        }

        let defaults = UserDefaults.standard
        let lastNudgeKey = AppConstants.NotificationSettings.friendActivityLastNudgeAt
        let streakCategory = NotificationCategory.streakReminder.identifier
        let pending = await center.pendingNotificationRequests()

        let input = FriendActivityNudgeInput(
            isEnabled: FriendActivityNudgePolicy.isEnabled(defaults: defaults),
            friendUserIds: Set(friends.map(\.id)),
            todaysLeaderboard: todaysLeaderboard,
            gameNamesById: Self.gameDisplayNames(),
            userPlayedToday: userPlayedToday,
            streakReminderPending: pending.contains { $0.content.categoryIdentifier == streakCategory },
            lastNudgeAt: defaults.object(forKey: lastNudgeKey) as? Date,
            now: now
        )

        guard let nudge = FriendActivityNudgePolicy.decide(input) else { return }
        await deliverFriendActivityNudge(nudge, now: now, defaults: defaults)
    }

    /// Cancels a pending nudge. Called when the user turns the setting off.
    func cancelFriendActivityNudge() async {
        center.removePendingNotificationRequests(withIdentifiers: [Self.friendActivityNudgeIdentifier])
        logger.info("Cancelled friend activity nudge")
    }

    /// Builds the notification payload. Internal for `@testable import` in unit tests.
    func buildFriendActivityContent(_ nudge: FriendActivityNudge) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = nudge.title
        content.body = nudge.body
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.friendActivity.identifier
        content.userInfo = ["type": "friend_activity"]
        return content
    }

    // MARK: - Private

    private func deliverFriendActivityNudge(
        _ nudge: FriendActivityNudge,
        now: Date,
        defaults: UserDefaults
    ) async {
        let hour = defaults.object(forKey: AppConstants.NotificationSettings.reminderHour) as? Int ?? 19
        let minute = defaults.object(forKey: AppConstants.NotificationSettings.reminderMinute) as? Int ?? 0
        let calendar = Calendar.autoupdatingCurrent
        let resolved = resolveOneOffReminderDate(
            daysFromNow: 0,
            hour: hour,
            minute: minute,
            calendar: calendar,
            now: now
        )

        guard let fireDate = resolved,
              fireDate.timeIntervalSince(now) >= Self.friendActivityMinimumLeadTime else {
            logger.info("Friend activity nudge skipped: today's reminder time has already passed")
            return
        }

        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second, .timeZone],
            from: fireDate
        )
        let request = UNNotificationRequest(
            identifier: Self.friendActivityNudgeIdentifier,
            content: buildFriendActivityContent(nudge),
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )

        do {
            try await center.add(request)
            defaults.set(now, forKey: AppConstants.NotificationSettings.friendActivityLastNudgeAt)
            let timeText = "\(hour):\(String(format: "%02d", minute))"
            logger.info("Scheduled friend activity nudge for \(nudge.friendCount) friends at \(timeText)")
        } catch {
            logger.error("Failed to schedule friend activity nudge: \(error.localizedDescription)")
        }
    }

    /// Display name per game ID, sourced from the same catalog the leaderboard is keyed
    /// against. `reduce(into:)` rather than `Dictionary(uniqueKeysWithValues:)` so a
    /// duplicate ID can never trap in production.
    private static func gameDisplayNames() -> [UUID: String] {
        Game.allAvailableGames.reduce(into: [:]) { names, game in
            names[game.id] = game.displayName
        }
    }
}
