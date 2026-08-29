//
//  AppContainer+AccountSwitch.swift
//  StreakSync
//
//  Non-destructive account switching and the empty-new-account warning
//

import Foundation

/// What the UI needs to explain a switch that probably wasn't intended.
struct EmptyAccountSwitchWarning: Equatable, Identifiable {
    let previousUID: String
    let previousProviderLabel: String
    let newProviderLabel: String
    let archivedResultCount: Int

    var id: String { previousUID }
}

extension AppContainer {
    /// Whether to tell the user they've landed on a brand-new, empty account.
    ///
    /// Deliberately not based on `fetchSignInMethods(forEmail:)` — email enumeration
    /// protection is on by default and returns an empty array, so it can't distinguish
    /// "no such account" from "account exists". This decides after the fact instead,
    /// from facts that are always available: the outgoing session was a real signed-in
    /// account with data, the incoming one has nothing in it even after a sync, and the
    /// two don't share a sign-in provider. That last clause is what separates a genuine
    /// account switch from "I meant to sign in the same way I always do".
    ///
    /// `nonisolated internal static` for testability, matching `deriveProvider`.
    nonisolated internal static func shouldWarnAboutEmptyAccountSwitch(
        previousWasAnonymous: Bool,
        previousResultCount: Int,
        newResultCountAfterSync: Int,
        previousProviderIDs: [String],
        newProviderIDs: [String]
    ) -> Bool {
        guard !previousWasAnonymous,
              previousResultCount > 0,
              newResultCountAfterSync == 0,
              !newProviderIDs.isEmpty else {
            return false
        }
        return Set(previousProviderIDs).isDisjoint(with: Set(newProviderIDs))
    }

    /// Human-readable provider name for the warning copy.
    nonisolated internal static func providerLabel(forProviderIDs ids: [String]) -> String {
        switch deriveProvider(fromProviderIDs: ids) {
        case .apple: return "Apple"
        case .google: return "Google"
        case .anonymous: return "a guest account"
        }
    }
}
