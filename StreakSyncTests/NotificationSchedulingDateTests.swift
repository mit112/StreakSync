//
//  NotificationSchedulingDateTests.swift
//  StreakSyncTests
//
//  DST/timezone-focused tests for one-off reminder date resolution.
//

import XCTest
@testable import StreakSync

@MainActor
final class NotificationSchedulingDateTests: XCTestCase {
    private let scheduler = NotificationScheduler.shared

    private func gregorianCalendar(timeZoneID: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneID)!
        return calendar
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int,
        calendar: Calendar
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = 0
        components.timeZone = calendar.timeZone
        return calendar.date(from: components)!
    }

    func testMakeOneOffReminderDateComponents_regularDayPreservesRequestedTime() {
        let calendar = gregorianCalendar(timeZoneID: "America/Los_Angeles")
        let now = date(2026, 2, 10, 10, 0, calendar: calendar)

        let components = scheduler.makeOneOffReminderDateComponents(
            daysFromNow: 2,
            hour: 19,
            minute: 15,
            calendar: calendar,
            now: now
        )

        XCTAssertEqual(components?.year, 2026)
        XCTAssertEqual(components?.month, 2)
        XCTAssertEqual(components?.day, 12)
        XCTAssertEqual(components?.hour, 19)
        XCTAssertEqual(components?.minute, 15)
        XCTAssertEqual(components?.timeZone?.identifier, "America/Los_Angeles")
    }

    func testResolveOneOffReminderDate_springForwardNonexistentLocalTimeRollsForward() {
        let calendar = gregorianCalendar(timeZoneID: "America/New_York")
        let now = date(2026, 3, 7, 10, 0, calendar: calendar)

        let resolved = scheduler.resolveOneOffReminderDate(
            daysFromNow: 1,
            hour: 2,
            minute: 30,
            calendar: calendar,
            now: now
        )

        XCTAssertNotNil(resolved)
        guard let resolved else { return }

        let resolvedComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: resolved)
        XCTAssertEqual(resolvedComponents.year, 2026)
        XCTAssertEqual(resolvedComponents.month, 3)
        XCTAssertEqual(resolvedComponents.day, 8)
        XCTAssertNotEqual(resolvedComponents.hour, 2, "2:30 AM does not exist on DST spring-forward day")
    }

    func testResolveOneOffReminderDate_fallBackAmbiguousTimeUsesFirstOccurrence() {
        let calendar = gregorianCalendar(timeZoneID: "America/New_York")
        let now = date(2026, 10, 31, 10, 0, calendar: calendar)

        let resolved = scheduler.resolveOneOffReminderDate(
            daysFromNow: 1,
            hour: 1,
            minute: 30,
            calendar: calendar,
            now: now
        )

        XCTAssertNotNil(resolved)
        guard let resolved else { return }

        let resolvedComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: resolved)
        XCTAssertEqual(resolvedComponents.year, 2026)
        XCTAssertEqual(resolvedComponents.month, 11)
        XCTAssertEqual(resolvedComponents.day, 1)
        XCTAssertEqual(resolvedComponents.hour, 1)
        XCTAssertEqual(resolvedComponents.minute, 30)
        XCTAssertTrue(calendar.timeZone.isDaylightSavingTime(for: resolved), "Expected first 1:30 occurrence during fall-back")
    }
}
