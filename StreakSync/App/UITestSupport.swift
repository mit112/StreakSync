//
//  UITestSupport.swift
//  StreakSync
//
//  Launch-argument seams that let UI tests enter journeys with no in-app entry point.
//

#if DEBUG
import Foundation
import OSLog

/// Test-only entry points into the three riskiest journeys. Compiled out of Release.
///
/// Share-extension import, friend-request accept and notification deep link all
/// *begin* outside the app — in an extension process, in Firestore, and in
/// SpringBoard. A UI test can reach none of them: it cannot run the extension,
/// cannot write to the App Group (the runner has no such entitlement), and cannot
/// dismiss a SpringBoard alert. Each seam below therefore starts its journey one
/// step in, at the first point the app itself owns, so that everything downstream
/// of that point is the real production pipeline rather than a simulation.
///
/// What each seam does NOT cover is stated on the seam, and repeated in the tests.
enum UITestSupport {
    private static let logger = Logger(subsystem: "com.streaksync.app", category: "UITestSupport")

    private static var arguments: [String] { ProcessInfo.processInfo.arguments }

    static var isActive: Bool { arguments.contains("--uitesting") }

    /// Display name of a game to import as though the Share Extension had queued it.
    static var seededShareResultGame: String? { value(after: "--uitest-share-import") }

    /// A `streaksync://` URL to feed through the real URL handler once launch completes.
    static var seededDeepLink: URL? {
        value(after: "--uitest-deeplink").flatMap { URL(string: $0) }
    }

    /// Seeds one incoming friend request into the social service.
    static var seedsPendingFriendRequest: Bool { arguments.contains("--uitest-friend-request") }

    /// Wipes local state before the first load, so a test asserting "this result
    /// arrived" cannot be satisfied by a result an earlier run left behind.
    static var resetsState: Bool { arguments.contains("--uitest-reset") }

    /// True when any seam wants the deterministic in-memory social service instead of Firestore.
    static var usesStubSocialService: Bool { isActive && seedsPendingFriendRequest }

    private static func value(after flag: String) -> String? {
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    // MARK: - Seams

    /// Clears persisted app state and the App Group queue. Must run before
    /// `loadPersistedData()`, or the wipe races the load it is meant to precede.
    ///
    /// Without this, `testSharedResultReachesTheDashboard` passes on a simulator
    /// that merely still holds a result from an earlier run — verified: with every
    /// seam disabled it was the one test that stayed green, for exactly that reason.
    @MainActor
    static func resetStateIfRequested(appState: AppState) async {
        guard isActive, resetsState else { return }

        // Wipe the whole defaults domain first, not just the persistence keys.
        // Unit tests run INSIDE this app as the test host, so a combined
        // `-only-testing:StreakSyncTests -only-testing:StreakSyncUITests` invocation —
        // which is exactly what CI runs — leaves their seeded onboarding flags,
        // achievement state and analytics scope behind for the UI tests to trip over.
        // That is why two tests passed on a UI-only run and failed on CI.
        let defaults = UserDefaults.standard
        if let bundleId = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: bundleId)
        }

        // Then put the app back into a post-onboarding steady state. A clean data slate
        // is wanted; a first-run app is not. Wiping the domain also cleared these flags,
        // which on a simulator whose notification authorization is still `.notDetermined`
        // put a permission SHEET over the whole UI — so the tests could see the tab bar
        // and nothing under it. That reproduced only on a fresh machine like CI, because
        // a simulator that has answered the prompt once never shows it again.
        defaults.set(true, forKey: AppConstants.NotificationSettings.firstLaunchPromptShown)
        defaults.set(true, forKey: AppConstants.Onboarding.hasSeenShareOnboarding)
        defaults.set(true, forKey: AppConstants.Onboarding.hasSeenFirstShareCelebration)
        defaults.set(true, forKey: "hasSeenEmptyStateGuidance")

        await appState.clearAllData()
        // Home is streak-derived, not result-derived, so clearing results is not
        // enough — the streaks have to be rebuilt from the now-empty set.
        await appState.rebuildStreaksFromResults()
        AppGroupDataManager().clearAll()
        logger.info("UI test: cleared local state")
    }

    /// Applies every seed requested on the command line. Called once, after the app
    /// has finished its local-first load, so seeded state lands on a painted UI.
    @MainActor
    static func applyLaunchSeeds(handleURL: (URL) -> Void) async {
        guard isActive else { return }

        if let gameName = seededShareResultGame {
            await seedShareExtensionResult(named: gameName)
        }

        if let url = seededDeepLink {
            logger.info("UI test: replaying deep link")
            handleURL(url)
        }
    }

    /// Writes a result into the App Group queue in exactly the shape the Share
    /// Extension writes it, then posts the notification `AppGroupBridge` already
    /// observes.
    ///
    /// Covered from here on, for real: queue read, duplicate detection, the
    /// `.gameResultReceived` route through `NotificationCoordinator`,
    /// `AppState.addGameResult`, streak recalculation, persistence and the UI.
    ///
    /// NOT covered: the extension's own write, and the Darwin notification that
    /// normally wakes the app. Those need two processes.
    @MainActor
    private static func seedShareExtensionResult(named displayName: String) async {
        guard let game = Game.allAvailableGames.first(where: {
            $0.displayName.caseInsensitiveCompare(displayName) == .orderedSame
        }) else {
            logger.error("UI test: no game named \(displayName, privacy: .public)")
            return
        }

        // Deliberately a legal fixture for .lowerAttempts: GameResult's initializer
        // asserts the score matches the game's scoring model, and a bad one aborts
        // the whole host process rather than failing a test.
        let result = GameResult(
            gameId: game.id,
            gameName: game.name,
            date: Date(),
            score: 3,
            maxAttempts: 6,
            completed: true,
            sharedText: "\(game.displayName) 1,234 3/6",
            parsedData: ["puzzleNumber": "1234"]
        )

        let key = "uitest_\(result.id.uuidString)"
        let manager = AppGroupDataManager()
        do {
            // Reuse the app's own writer so the encoding cannot drift from the reader.
            try await manager.saveGameResult(result, forKey: key)
        } catch {
            logger.error("UI test: failed to queue result — \(error.localizedDescription)")
            return
        }

        guard let defaults = UserDefaults(suiteName: AppConstants.AppGroup.identifier),
              let keysData = try? JSONSerialization.data(withJSONObject: [key]) else {
            logger.error("UI test: App Group unavailable")
            return
        }
        defaults.set(keysData, forKey: "gameResultKeys")

        logger.info("UI test: queued \(game.displayName, privacy: .public), waking the bridge")
        NotificationCenter.default.post(name: .appHandleNewGameResult, object: nil)
    }
}
#endif
