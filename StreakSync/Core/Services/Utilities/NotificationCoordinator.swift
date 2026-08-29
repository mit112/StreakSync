//
//  NotificationCoordinator.swift
//  StreakSync
//
//  Centralized notification handling and app communication
//

import OSLog
import SwiftUI
import UIKit

@MainActor
final class NotificationCoordinator: ObservableObject {
    // MARK: - Dependencies
    weak var appState: AppState?
    weak var navigationCoordinator: NavigationCoordinator?
    weak var appGroupBridge: AppGroupBridge?
    weak var gameResultSyncService: (any GameResultSyncServiceProtocol)?
    
    // MARK: - Properties
    private var observers: [NSObjectProtocol] = []
    private let logger = Logger(subsystem: "com.streaksync.app", category: "NotificationCoordinator")
    // Debounce UI refresh spam
    private var lastUIRefreshAt: Date?
    private let uiRefreshDebounceInterval: TimeInterval = 0.3
    
    // MARK: - Published State
    @Published var refreshID = UUID()
    
    // MARK: - Initialization
    init() {
        // Observers will be set up by AppContainer after dependencies are wired
    }
    
    deinit {
        // Cleanup happens automatically when observers are deallocated
        // No need to manually remove observers in deinit
    }
    
    // MARK: - Setup
    func setupObservers() {
        logger.info("Setting up notification observers")
        removeObservers()
        setupGameResultObservers()
        setupDeepLinkObservers()
        setupLifecycleObservers()
        logger.info("Set up \(self.observers.count) notification observers")
    }

    private func setupGameResultObservers() {
        observers.append(
            NotificationCenter.default.addObserver(
                forName: .gameResultReceived, object: nil, queue: .main
            ) { [weak self] notification in
                guard let result = notification.object as? GameResult else { return }
                let quiet = notification.userInfo?["quiet"] as? Bool ?? false
                Task { @MainActor [weak self] in
                    self?.handleGameResult(result, quiet: quiet)
                }
            }
        )

        observers.append(
            NotificationCenter.default.addObserver(
                forName: .init(AppConstants.Notification.shareExtensionResultAvailable),
                object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.handleShareExtensionResult()
                }
            }
        )

        observers.append(
            NotificationCenter.default.addObserver(
                forName: .appGameDataUpdated, object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.triggerUIRefresh()
                }
            }
        )
    }

    private func setupDeepLinkObservers() {
        observers.append(
            NotificationCenter.default.addObserver(
                forName: .openGameRequested, object: nil, queue: .main
            ) { [weak self] notification in
                guard let payload = notification.object as? [String: Any] else { return }
                // Pull the Sendable values out here: `[String: Any]` can't cross into the
                // @MainActor Task under Swift 6 strict concurrency.
                let gameId = payload[AppConstants.DeepLinkKeys.gameId] as? UUID
                // AppGroupURLSchemeHandler posts this for `streaksync://game?name=…`
                // and reported success, but nothing consumed it.
                let gameName = payload[AppConstants.DeepLinkKeys.name] as? String
                guard gameId != nil || gameName != nil else { return }
                Task { @MainActor [weak self] in
                    if let gameId {
                        self?.handleGameDeepLinkWithId(gameId)
                    } else if let gameName {
                        self?.handleGameDeepLinkWithName(gameName)
                    }
                }
            }
        )

        observers.append(
            NotificationCenter.default.addObserver(
                forName: .openAchievementRequested, object: nil, queue: .main
            ) { [weak self] notification in
                guard let payload = notification.object as? [String: Any],
                      let achievementId = payload[AppConstants.DeepLinkKeys.achievementId] as? UUID
                else { return }
                Task { @MainActor [weak self] in
                    self?.handleAchievementDeepLinkWithId(achievementId)
                }
            }
        )
    }

    private func setupLifecycleObservers() {
        observers.append(
            NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.handleAppDidBecomeActive()
                }
            }
        )

        observers.append(
            NotificationCenter.default.addObserver(
                forName: UIApplication.willResignActiveNotification,
                object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleAppWillResignActive()
                }
            }
        )
    }
    
    private func removeObservers() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }
    
    // MARK: - Cleanup
    func cleanup() {
        removeObservers()
        logger.info("NotificationCoordinator cleaned up")
    }
    
    // MARK: - Notification Handlers
    
    private func handleGameResult(_ result: GameResult, quiet: Bool) {
        // Expected flow when a result arrives (Share Extension or in-app):
        //   1. Route through gameResultSyncService.addResult so it's persisted locally
        //      AND uploaded to Firestore immediately (falls back to appState.addGameResult
        //      for preview/test where no sync service is wired).
        //   2. Await a CONFIRMED durable local write, then acknowledgeIngestedResult(id:)
        //      to release it from the App Group queue — the queue is the durable buffer
        //      until this point, so a crash mid-ingest can't lose the result (T1-2).
        //   3. triggerUIRefresh() to update observing views.
        //   4. If app is active + result was added + not quiet: fire streak haptic.
        //   5. If app is backgrounded + result was added: schedule local notification
        //      via NotificationScheduler.scheduleResultImportedNotification.
        logger.info("Handling game result: \(result.gameName) - \(result.displayScore)")

        Task { @MainActor [weak self] in
            guard let self = self else { return }

            let added: Bool
            if let svc = self.gameResultSyncService {
                // Route via sync service: adds locally AND uploads to Firestore immediately.
                // addResult returns the authoritative Bool from addGameResult, so a duplicate
                // re-share (added == false) no longer fires a bogus "result imported"
                // notification. Falls back to appState.addGameResult if no sync service is
                // wired (preview/test).
                added = svc.addResult(result)
            } else {
                added = self.appState?.addGameResult(result) ?? false
            }

            // Confirm a durable local write BEFORE releasing the result from the App
            // Group queue. addGameResult persists asynchronously; awaiting here
            // guarantees the result is on disk (or in the durable retry queue) first.
            // A duplicate/invalid result (added == false) is already persisted or
            // unpersistable, so a confirmed save of current state is still a safe ack.
            if let appState = self.appState {
                await appState.saveStreaks()
                if await appState.saveGameResultsConfirmingDurability() {
                    self.appGroupBridge?.acknowledgeIngestedResult(id: result.id)
                }
            } else {
                // Preview/test: nothing to persist — ack so the queue can't lock up.
                self.appGroupBridge?.acknowledgeIngestedResult(id: result.id)
            }

            // Trigger UI refresh
            self.triggerUIRefresh()

            // Gate haptics: only when app is active and the result was added
            let isActive = UIApplication.shared.applicationState == .active
            if isActive && added && !quiet {
                HapticManager.shared.trigger(.streakUpdate)
            } else {
                let reason = !isActive ? "app not active" : !added ? "duplicate/invalid result" : "quiet batch"
                self.logger.debug("Haptics suppressed: \(reason)")

                // Notify the user via local notification when the app is backgrounded
                // and the result was successfully added (e.g. from Share Extension).
                // Suppressed for quiet batch imports so a backlog of shared results
                // drains without firing one "result imported" notification per result.
                if !isActive && added && !quiet {
                    await NotificationScheduler.shared.scheduleResultImportedNotification(
                        gameName: result.gameName,
                        gameId: result.gameId
                    )
                }
            }
        }
    }
    
    private func handleGameDeepLinkWithId(_ gameId: UUID) {
        if let game = appState?.games.first(where: { $0.id == gameId }) {
            logger.info("Handling game deep link by id: \(gameId)")
            // `navigateTo` appends to whichever tab is showing, so a deep link arriving
            // while the user sits on Friends/Settings pushed game detail onto that stack.
            navigationCoordinator?.switchToTabAndNavigate(.home, destination: .gameDetail(game))
        } else {
            logger.error("Game not found for id: \(gameId)")
        }
    }
    
    private func handleGameDeepLinkWithName(_ name: String) {
        if let game = Self.resolveGame(named: name, in: appState?.games ?? []) {
            handleGameDeepLinkWithId(game.id)
        } else {
            logger.error("Game not found for name: \(name)")
        }
    }

    /// Resolves a `streaksync://game?name=…` payload against the game catalog.
    ///
    /// The slug match on `Game.name` (e.g. "minicrossword") is tried FIRST and is
    /// byte-for-byte the old behaviour, so internal callers that already pass slugs
    /// are unaffected. Only when that misses do we fall back to the human-readable
    /// `displayName` — which is what an external caller actually types, e.g.
    /// `streaksync://game?name=Mini%20Crossword`.
    ///
    /// Deliberately not `private` so the matching rule can be unit-tested directly
    /// instead of through a NotificationCenter round trip and a NavigationPath.
    static func resolveGame(named name: String, in games: [Game]) -> Game? {
        let slugTarget = name.lowercased()
        if let game = games.first(where: { $0.name.lowercased() == slugTarget }) {
            return game
        }

        // Lowercase + drop whitespace on BOTH sides so "Mini Crossword",
        // "mini crossword" and "MINI CROSSWORD" all land on the same game.
        // Verified unambiguous: no two entries in Game.allAvailableGames share a
        // normalised display name (see DeepLinkNameMatchingTests).
        let displayTarget = normalizedDisplayName(name)
        guard !displayTarget.isEmpty else { return nil }
        return games.first(where: { normalizedDisplayName($0.displayName) == displayTarget })
    }

    /// Case- and whitespace-insensitive form of a display name.
    private static func normalizedDisplayName(_ value: String) -> String {
        value.lowercased().filter { !$0.isWhitespace }
    }

    private func handleAchievementDeepLinkWithId(_ achievementId: UUID) {
        logger.info("Handling achievement deep link: \(achievementId)")
        
        // Navigate to achievements
        navigationCoordinator?.navigateTo(.achievements)
        
        // Present tiered achievement detail if found
        if let tiered = appState?.tieredAchievements.first(where: { $0.id == achievementId }) {
            navigationCoordinator?.presentSheet(.tieredAchievementDetail(tiered))
        }
    }
    
    // MARK: - App Lifecycle
    
    private func handleAppDidBecomeActive() async {
        logger.info("App became active (via notification)")
        
        // Skip expensive operations if navigating from notification
        if appState?.isNavigatingFromNotification == true {
            logger.info("Skipping share extension check - navigating from notification")
            return
        }
        
        // No-op: AppGroupBridge owns lifecycle share checks to avoid duplicates
    }
    
    private func handleAppWillResignActive() {
        // Downgrade to debug to avoid duplicate lifecycle noise; AppContainer handles monitoring stop.
        logger.debug("App will resign active (NotificationCoordinator)")
    }
    
    private func handleShareExtensionResult() async {
        // No-op: AppGroupBridge's Darwin observer triggers the check; avoid duplicate processing here.
        logger.info("Received Share Extension notification (handled by bridge)")
    }
    
    // MARK: - UI Updates
    
    func triggerUIRefresh() {
        // Debounce to avoid rapid repeated refreshes from batch operations
        let now = Date()
        if let last = lastUIRefreshAt, now.timeIntervalSince(last) < uiRefreshDebounceInterval {
            logger.debug("Skipping UI refresh (debounced)")
            return
        }
        lastUIRefreshAt = now
        
        logger.info("Triggering UI refresh")
        refreshID = UUID()
        
        // Post dedicated UI refresh notification (not .gameResultReceived, which
        // carries a GameResult payload and has different semantics)
        NotificationCenter.default.post(
            name: .appUIRefreshNeeded,
            object: nil
        )
    }
    
    // MARK: - Public Methods
    
    func handleURLScheme(_ url: URL) -> Bool {
        logger.info("NotificationCoordinator handling URL: \(url.absoluteString)")
        return appGroupBridge?.handleURLScheme(url) ?? false
    }
}
