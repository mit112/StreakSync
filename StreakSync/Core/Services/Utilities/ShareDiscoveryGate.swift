//
//  ShareDiscoveryGate.swift
//  StreakSync
//
//  Pure decision logic for the share-discovery teaching sheet and first-share celebration
//

import Foundation

/// Pure decision logic for share-discovery surfaces. Decoupled from UserDefaults and SwiftUI
/// so it can be exercised in tests without any system dependencies.
enum ShareDiscoveryGate {
    /// Should the first-launch teaching sheet be presented?
    /// True when the user has never logged a result AND has not yet dismissed the sheet.
    static func shouldShowOnboarding(resultsCount: Int, hasSeen: Bool) -> Bool {
        resultsCount == 0 && !hasSeen
    }

    /// Should the first-share celebration fire for this `addGameResult` call?
    /// True when this insertion takes the user from 0 → 1 results, the celebration hasn't
    /// already fired, and the user is not in Guest Mode.
    static func shouldFireCelebration(preInsertCount: Int, hasSeen: Bool, isGuest: Bool) -> Bool {
        preInsertCount == 0 && !hasSeen && !isGuest
    }
}
