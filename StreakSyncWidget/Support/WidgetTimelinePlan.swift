//
//  WidgetTimelinePlan.swift
//  StreakSyncWidget
//
//  The single refresh policy both timeline providers build from
//

import Foundation

/// Widgets must not poll, so the entire refresh strategy is: one entry for now,
/// one for the next local midnight (built with `rolledForward(to:)` so the day
/// flips correctly without the app relaunching), and a reload request shortly
/// after that boundary. Both providers derive their entries from one plan so the
/// policy cannot drift between them.
enum WidgetTimelinePlan {
    /// Grace period after midnight before asking WidgetKit to rebuild, so the
    /// reload lands on the new day instead of racing the boundary.
    static let reloadGrace: TimeInterval = 60

    struct Plan {
        let now: Date
        let nextMidnight: Date
        let reloadAt: Date
        /// Snapshot as of `now`. Nil when the app has never published one.
        let current: WidgetSnapshot?
        /// The same snapshot rolled into the next day: nothing played, active
        /// streaks at risk again.
        let afterMidnight: WidgetSnapshot?
    }

    static func make(
        now: Date = Date(),
        snapshot: WidgetSnapshot?,
        calendar: Calendar = .current
    ) -> Plan {
        let midnight = nextMidnight(after: now, calendar: calendar)
        return Plan(
            now: now,
            nextMidnight: midnight,
            reloadAt: midnight.addingTimeInterval(reloadGrace),
            current: snapshot?.rolledForward(to: now, calendar: calendar),
            afterMidnight: snapshot?.rolledForward(to: midnight, calendar: calendar)
        )
    }

    static func nextMidnight(after date: Date, calendar: Calendar = .current) -> Date {
        let matched = calendar.nextDate(
            after: date,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        )
        // Unreachable for any real calendar; a fixed 24h hop still advances the
        // day rather than pinning the timeline to a stale one.
        return matched ?? date.addingTimeInterval(24 * 60 * 60)
    }
}
