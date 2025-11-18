//
//  BetaFeatureFlags.swift
//  StreakSync
//
//  Lightweight runtime feature toggles for the simplified beta rollout.
//

import Foundation

@MainActor
final class BetaFeatureFlags: ObservableObject {
    static let shared = BetaFeatureFlags()

    // MARK: - Core Features (Enabled for Beta)
    let coreLeaderboard = true
    let shareLinks = true
    let basicScoring = true

    // MARK: - Disabled for Beta
    @Published var multipleCircles = false
    @Published var reactions = false
    @Published var activityFeed = false
    @Published var granularPrivacy = false
    @Published var contactDiscovery = false
    @Published var usernameAddition = false
    @Published var rankDeltas = false

    // MARK: - Beta Controls
    @Published var betaFeedbackButton = true
    @Published var debugInfo = false

    var isMinimalBeta: Bool {
        !multipleCircles &&
        !reactions &&
        !activityFeed &&
        !granularPrivacy &&
        !contactDiscovery &&
        !usernameAddition &&
        !rankDeltas
    }

    func enableForInternalTesting() {
        multipleCircles = true
        reactions = true
        activityFeed = true
        granularPrivacy = true
        contactDiscovery = true
        usernameAddition = true
        rankDeltas = true
    }
}

