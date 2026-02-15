StreakSync Architecture Overview

Layers
- App entry: `StreakSync/App` bootstraps the app, requests permissions, and injects the `AppContainer`.
- Dependency container: `AppContainer` wires all services (state, navigation, notifications, sync, design system singletons).
- State: `Core/State/AppState*` holds domain data (games, streaks, results, tiered achievements) and coordinates persistence, streak logic, and achievements.
- Persistence: `Core/Services/Persistence` (UserDefaults/App Group JSON) with ISO8601 dates.
- Sync & Deep Links: `Core/Services/Sync` bridges the Share Extension, Darwin notifications, and `streaksync://` URL scheme.
- Navigation: `Core/Services/Navigation` provides tabbed stacks and routing helpers.
- Design System: `Design System/*` defines colors, haptics, animations.

 Key flows
- Share → App: Share Extension saves to App Group → `AppGroupBridge` detects → `NotificationCoordinator` → `AppState.addGameResult` → UI refresh.
- Deep links: `AppGroupURLSchemeHandler` parses scheme and posts typed payloads → `NotificationCoordinator` navigates.
- App lifecycle: `StreakSyncApp.initializeApp()` loads state once; `AppContainer` forwards lifecycle to services and is the single owner of foreground refreshes (no duplicate reloads from other components).

Decisions
- Duplicate achievement helpers removed from `AppState+GameLogic`; single source lives in `AppState+TieredAchievements`.
- NotificationCoordinator focuses on internal app notifications (share results, deep links) and does not trigger full data reloads; `AppGroupBridge` posts `gameResultReceived` and `AppContainer` coordinates refresh when appropriate.
- URL payload keys centralized under `AppConstants.DeepLinkKeys`.
- Notification names exposed as typed `Notification.Name` static constants.
- Avoid `UserDefaults.synchronize()` for performance; rely on the system.

## Account & Identity Model

- **Local data (streaks, results, achievements)**: Persisted in UserDefaults + App Group, synced to CloudKit private database.
  - Container: `iCloud.com.mitsheth.StreakSync2`
  - Custom zones: `AchievementsZone` (tiered achievements via `AchievementSyncService`), `UserDataZone` (game results via `UserDataSyncService`).
- **Social identity (friends, leaderboards)**: Firebase Auth + Firestore.
  - `FirebaseAuthStateManager` handles anonymous auth (auto-created) and Apple Sign-In with credential linking (anonymous → Apple, preserves UID).
  - `AccountView` in Settings provides sign-in/sign-out UI.
  - Google Sign-In deferred (needs separate SPM dep + OAuth client).
- Guest Mode:
  - A local-only mode that lets someone temporarily use StreakSync without syncing.
  - While Guest Mode is active, CloudKit sync and leaderboard publishing are disabled and host data is kept isolated.

## Achievements (Tiered-Only)

- Tiered achievements are the single source of truth. Legacy `Achievement` is deprecated at runtime.
- Models: `TieredAchievement`, `AchievementTier`, `AchievementCategory`, `TierRequirement`, `AchievementProgress`.
- Persistence: `tieredAchievements` under `UserDefaults` via `PersistenceService`.
- Flow: `AppState.checkAchievements` -> `TieredAchievementChecker` -> post `AppConstants.Notification.tieredAchievementUnlocked` -> `AchievementCelebrationCoordinator` shows `AchievementUnlockCelebrationView`.
- Migration: `AppState+Persistence.migrateLegacyAchievementsIfNeeded()` seeds tiered from legacy payloads once and clears legacy key.
- Analytics: `AnalyticsService` computes `AchievementAnalytics` using tiered data only (tier distribution, category progress, recent unlocks).
- **ID Consistency**: Each achievement category has a deterministic UUID via `AchievementCategory.consistentID` to prevent duplicates during recalculation and CloudKit sync. The `recalculateAllTieredAchievementProgress()` method preserves existing IDs when recalculating progress.
- **Deduplication**: The `tieredAchievements` getter and setter include deduplication logic to remove any duplicate achievements by category that may exist in persisted data.

## Smart Reminder Engine

All computation runs locally on device.

Algorithm
- Build a 24h histogram of completed results from the last 30 days.
- Slide a 2-hour window to find the best coverage window and compute coverage%.
- Suggest a reminder 30 minutes before the window start, clamped to 06:00–22:00.

Modes
- Smart OFF: user-selected time is respected; no auto changes.
- Smart ON: recomputes at most every 2 days on day change and reschedules.

Lifecycle
- Day change triggers `updateSmartRemindersIfNeeded()`; if 2+ days have elapsed since last computation, `applySmartReminderNow()` updates the time and reschedules.

Persistence Keys
- `smartRemindersEnabled` (Bool)
- `smartRemindersLastComputed` (Date)
- `smartReminderWindowStartHour` (Int), `smartReminderWindowEndHour` (Int)
- `smartReminderCoveragePercent` (Int)
- `streakRemindersEnabled` (Bool)
- `streakReminderHour` (Int), `streakReminderMinute` (Int)

## Analytics: Deep Dives, Weekly Recap, CSV

Deep Dives
- Wordle/Nerdle: guess distribution, fail rate, average guesses.
- Pips: per-difficulty best/avg times (mm:ss).
- Pinpoint: guess distribution (1–5).
- Strands: hints distribution (0–10).

Weekly Recap
- ISO-week grouping; shows total/completed, completion rate, average current streak, longest streak, and consistency% (active days / 7).

CSV Export
- Toolbar button exports the current analytics scope as CSV with headers: `date,game,score,maxAttempts,completed`.

Refresh Model
- Dashboard listens for: `GameDataUpdated`, `GameResultAdded`, `RefreshGameData`.
- **Display Logic**: `DashboardGamesContent` iterates over `filteredGames` (not `filteredStreaks`) to ensure all games are visible, even those without streaks. Missing streaks are created on-the-fly using `GameStreak.empty(for:)` to prevent games from being hidden on first load.

Developer (DEBUG)
- Lightweight analytics self-tests live in `Core/Services/Analytics/AnalyticsSelfTests.swift` and can be called at startup in DEBUG to verify overview, trends, per-game stats, and achievements analytics.

## Social: Friends & Leaderboard

Model
- Flat friends list (no circles). Friendships stored in Firestore `friendships` collection (bidirectional, pending/accepted).
- Friend codes for invites: generate a 6-char code, share it, friend enters it to connect.
- All 17 games appear on the leaderboard. Scores use authenticated Firebase UID.
- `currentStreak` field published to Firestore on score writes, displayed as 🔥 badge on leaderboard rows.
- "Hasn't played yet" section shows dimmed friends who haven't scored for a game.

Real-time Updates
- Firestore snapshot listeners (`addScoreListener`, `addFriendshipListener`) provide live updates.
- `FriendsViewModel` uses listeners with polling fallback for `MockSocialService`.
- Listener methods are `nonisolated` for Sendable conformance.

UX & UI
- Friends header with segmented range (Today / 7 Days) and inline date pager.
- Game carousel with native SwiftUI snapping. Per-game leaderboard pages.
- Rank delta chips (optional, flag-gated). Sticky "You" bar for current rank.
- `FriendManagementView`: generate/copy friend code, add by code, accept pending requests, swipe-to-delete friends with confirmation.
- `FriendsView` decomposed to ~250 lines. `GradientAvatar` and `GameIconCarousel` extracted as shared components.

Architecture
- `SocialService` protocol with `FirebaseSocialService` (production) and `MockSocialService` (dev).
- `FriendsViewModel` orchestrates profile, friends, leaderboard, rank deltas, date paging, listeners, and debounced refresh.
- Scoring centralized in `LeaderboardScoring.swift`, respects each `Game.scoringModel`.
- `PendingScoreStore` handles offline score queue with retry logic.

Files
- `Features/Shared/Views/FriendsView.swift`, `Features/Friends/ViewModels/FriendsViewModel.swift`
- `Features/Shared/Components/GameLeaderboardPage.swift`, `Features/Friends/Views/FriendManagementView.swift`
- `Features/Shared/Components/GradientAvatar.swift`, `Features/Shared/Components/GameIconCarousel.swift`
- `Core/Models/Social/LeaderboardScoring.swift`, `Core/Services/Social/*`

