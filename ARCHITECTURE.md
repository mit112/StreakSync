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
- App lifecycle: `StreakSyncApp.initializeApp()` loads state once; `AppContainer` forwards lifecycle to services.

Decisions
- Duplicate achievement helpers removed from `AppState+GameLogic`; single source lives in `AppState+TieredAchievements`.
- URL payload keys centralized under `AppConstants.DeepLinkKeys`.
- Notification names exposed as typed `Notification.Name` static constants.
- Avoid `UserDefaults.synchronize()` for performance; rely on the system.

## Achievements (Tiered-Only)

- Tiered achievements are the single source of truth. Legacy `Achievement` is deprecated at runtime.
- Models: `TieredAchievement`, `AchievementTier`, `AchievementCategory`, `TierRequirement`, `AchievementProgress`.
- Persistence: `tieredAchievements` under `UserDefaults` via `PersistenceService`.
- Flow: `AppState.checkAchievements` -> `TieredAchievementChecker` -> post `AppConstants.Notification.tieredAchievementUnlocked` -> `AchievementCelebrationCoordinator` shows `AchievementUnlockCelebrationView`.
- Migration: `AppState+Persistence.migrateLegacyAchievementsIfNeeded()` seeds tiered from legacy payloads once and clears legacy key.
- Analytics: `AnalyticsService` computes `AchievementAnalytics` using tiered data only (tier distribution, category progress, recent unlocks).

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

Developer (DEBUG)
- Lightweight analytics self-tests live in `Core/Services/Analytics/AnalyticsSelfTests.swift` and can be called at startup in DEBUG to verify overview, trends, per-game stats, and achievements analytics.

## Social: Friends & Leaderboard (Updated)

UX & UI
- Friends header includes status chip (Local Storage / Real-time Sync), segmented range (Today / 7 Days), and an inline date pager with long-press to calendar.
- Game-aware leaderboard metrics and rank delta chips. Sticky "You" bar summarises current rank and metric for the selected game.
- Game carousel uses native SwiftUI snapping with `.scrollPosition(id:)`, `.scrollTargetLayout()`, `.scrollTargetBehavior(.viewAligned)`, and horizontal `contentMargins` to naturally center edges.
- Empty state shows an Invite Friends CTA; inline error banner with dismiss; local-only ribbon explains offline/local mode.

Architecture
- `FriendsViewModel` in `Features/Friends/ViewModels` orchestrates profile, friends, leaderboard, rank deltas, date paging, and debounced refresh.
- Scoring is centralized in `Core/Models/Social/LeaderboardScoring.swift` and respects each `Game.scoringModel`.
- `HybridSocialService` is hardwired to local in development (no CloudKit APIs invoked) and will flip to CloudKit when entitlements are added later.

Performance & Accessibility
- Lazy stacks for lists; minimal overlays. Motion is subtle and honors Reduce Motion. VoiceOver labels summarise rank, name, metric, and delta.
- Debounced refresh helper avoids rapid reloads during quick UI changes; periodic timer is only used if CloudKit is enabled.

Files
- `Features/Shared/Views/FriendsView.swift`, `Features/Friends/ViewModels/FriendsViewModel.swift`
- `Features/Shared/Components/GameLeaderboardPage.swift`, `Features/Friends/Views/FriendManagementView.swift`
- `Core/Models/Social/LeaderboardScoring.swift`, `Core/Services/Social/*`

