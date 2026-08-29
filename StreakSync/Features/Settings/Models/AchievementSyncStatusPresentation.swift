//
//  AchievementSyncStatusPresentation.swift
//  StreakSync
//
//  Pure mapping from achievement sync status to what the Data & Privacy row says
//

import Foundation

/// What the Data & Privacy row tells the user about their achievement backup.
///
/// Split out as a pure value for two reasons. The wording is the part a user actually
/// reads when their backup is broken, so it needs tests that don't require Firestore.
/// And by always carrying a `symbolName` and a `title`, a failure can never be signalled
/// by colour alone — `severity` only tints the glyph (WCAG 2.2 AA, 1.4.1 Use of Colour).
struct AchievementSyncStatusPresentation: Equatable {
    enum Severity: Equatable {
        /// Nothing is wrong and nothing is owed by the user.
        case neutral
        case inProgress
        case ok
        /// Something failed and the user has a decision to make.
        case warning
    }

    let symbolName: String
    let title: String
    /// Nil when the title already says everything (`.syncing`) or a date does (`.success`).
    let detail: String?
    /// Formatted by the view in the user's locale; kept as a `Date` so this type stays
    /// deterministic under test.
    let relativeDate: Date?
    let severity: Severity

    /// One sentence for VoiceOver. The row is a single accessibility element and its
    /// glyph is decorative, so everything meaningful has to be spoken here.
    ///
    /// - Parameter relativeDescription: the locale-formatted stand-in for `relativeDate`,
    ///   supplied by the view so this stays a pure function.
    func accessibilityLabel(relativeDescription: String?) -> String {
        var parts = ["Achievement backup", title]
        if let relativeDescription { parts.append(relativeDescription) }
        if let detail { parts.append(detail) }
        return parts.joined(separator: ". ")
    }

    /// Precedence: the Cloud Sync switch outranks the status. `syncIfEnabled` returns
    /// early when sync is off without touching `status`, so the last failure would
    /// otherwise stay on screen accusing a feature the user has already turned off.
    static func resolve(status: AchievementSyncStatus, isSyncEnabled: Bool) -> Self {
        guard isSyncEnabled else { return Self.backupOff }
        switch status {
        case .idle: return Self.notBackedUpYet
        case .syncing: return Self.inFlight
        case .success(let date): return Self.backedUp(at: date)
        case .error(let failure): return Self.failureRow(failure)
        }
    }

    private static func failureRow(_ failure: AchievementSyncFailure) -> Self {
        switch failure {
        case .notSignedIn: return Self.signedOut
        case .networkUnavailable: return Self.waitingForNetwork
        case .serviceBusy: return Self.serviceBusy
        case .permissionDenied: return Self.permissionDenied
        case .payloadTooLarge(let kilobytes): return Self.tooLarge(kilobytes: kilobytes)
        case .unknown(let message): return Self.unknownFailure(message)
        }
    }
}

// MARK: - Healthy States

private extension AchievementSyncStatusPresentation {
    static var backupOff: Self {
        .init(
            symbolName: "icloud.slash",
            title: "Backup is off",
            detail: "Achievements stay on this device. Turn Cloud Sync on to back them up.",
            relativeDate: nil,
            severity: .neutral
        )
    }

    static var notBackedUpYet: Self {
        .init(
            symbolName: "icloud",
            title: "Not backed up yet",
            detail: "Achievements back up in the background. Tap Sync Now to start one now.",
            relativeDate: nil,
            severity: .neutral
        )
    }

    static var inFlight: Self {
        .init(
            symbolName: "arrow.triangle.2.circlepath",
            title: "Backing up…",
            detail: nil,
            relativeDate: nil,
            severity: .inProgress
        )
    }

    static func backedUp(at date: Date) -> Self {
        .init(
            symbolName: "checkmark.icloud",
            title: "Backed up",
            detail: nil,
            relativeDate: date,
            severity: .ok
        )
    }
}

// MARK: - Failure States

/// Every failure names what broke and what the user can do about it. Transient
/// failures stay `.neutral` and promise an automatic retry; failures that need a
/// decision are `.warning` and say which one.
private extension AchievementSyncStatusPresentation {
    static var signedOut: Self {
        .init(
            symbolName: "exclamationmark.icloud",
            title: "Not backed up — you're signed out",
            detail: """
                Nothing on this device was lost. Sign in again from Account and your \
                achievements will back up on the next sync.
                """,
            relativeDate: nil,
            severity: .warning
        )
    }

    static var waitingForNetwork: Self {
        .init(
            symbolName: "icloud.slash",
            title: "Waiting for a connection",
            detail: """
                Your achievements are safe on this device and will back up on their own \
                once you're online.
                """,
            relativeDate: nil,
            severity: .neutral
        )
    }

    static var serviceBusy: Self {
        .init(
            symbolName: "icloud.slash",
            title: "Backup is busy right now",
            detail: """
                The server asked StreakSync to slow down. Your achievements are safe on \
                this device and the next sync will pick them up.
                """,
            relativeDate: nil,
            severity: .neutral
        )
    }

    static var permissionDenied: Self {
        .init(
            symbolName: "exclamationmark.icloud",
            title: "Backup was refused",
            detail: """
                This account isn't allowed to write achievement data. Sign out and back \
                in from Account; if that doesn't fix it, contact support.
                """,
            relativeDate: nil,
            severity: .warning
        )
    }

    static func tooLarge(kilobytes: Int) -> Self {
        .init(
            symbolName: "exclamationmark.icloud",
            title: "Achievements are too large to back up",
            detail: """
                Your achievement data is \(kilobytes) KB, over the \
                \(AchievementSyncFailure.payloadLimitKilobytes) KB limit for one backup. \
                It stays safe on this device and rebuilds from your game results, but it \
                won't reach your other devices. Syncing again won't help — use Export \
                Data under Backup to keep a copy, then contact support.
                """,
            relativeDate: nil,
            severity: .warning
        )
    }

    static func unknownFailure(_ message: String) -> Self {
        .init(
            symbolName: "exclamationmark.icloud",
            title: "Backup failed",
            detail: """
                Your achievements are safe on this device but aren't backed up. Tap Sync \
                Now to try again. If it keeps failing, contact support and quote: \(message)
                """,
            relativeDate: nil,
            severity: .warning
        )
    }
}
