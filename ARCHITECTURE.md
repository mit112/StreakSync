# StreakSync Architecture Overview

## Layers

- **App entry**: `StreakSync/App` bootstraps the app, configures Firebase, and creates the `AppContainer`.
- **Dependency container**: `AppContainer` wires all services (state, navigation, notifications, sync, social, analytics, design system).
- **State**: `Core/State/AppState*` holds domain data (games, streaks, results, tiered achievements) and coordinates persistence, streak logic, and achievements. Split into 7 focused extensions.
- **Persistence**: `Core/Services/Persistence` — UserDefaults + App Group (JSON, ISO8601 dates) for local data, Keychain for sensitive data.
- **Sync**: `Core/Services/Sync` — Firebase Firestore for personal data sync (game results, achievements) and Share Extension bridge.
- **Social**: `Core/Services/Social` — Firebase Auth + Firestore for friends, leaderboards, and real-time listeners.
- **Navigation**: `Core/Services/Navigation` provides tab-based stacks and routing.
- **Design System**: `Design System/*` defines colors, haptics, animations, sound.

## Key Flows

- **Share → App**: Share Extension saves to App Group → `AppGroupBridge` detects → `NotificationCoordinator` → `AppState.addGameResult` → UI refresh.
- **Deep links**: `AppGroupURLSchemeHandler` parses `streaksync://` scheme and posts typed payloads → `NotificationCoordinator` navigates.
- **App lifecycle**: `AppContainer` forwards lifecycle events — loads state on init, refreshes on foreground, flushes pending scores, monitors Share Extension results for 5 seconds on activation.

## Architectural Decisions

- Single Firebase backend for all features (social, personal sync, auth). CloudKit fully removed.
- `AppContainer` is the sole DI container; creates and wires all services.
- `AppState` uses `@Observable` (Swift Observation); `AppContainer` uses `ObservableObject` (needed for `@EnvironmentObject` injection).
- URL payload keys centralized under `AppConstants.DeepLinkKeys`.
- Notification names exposed as typed `Notification.Name` static constants.
- Avoid `UserDefaults.synchronize()`; rely on the system.

## Account & Identity Model

- **Local data (streaks, results, achievements)**: Persisted in UserDefaults + App Group. Synced to Firebase Firestore under `users/{uid}/gameResults` and `users/{uid}/sync/achievements`.
- **Social identity (friends, leaderboards)**: Firebase Auth + Firestore.
  - `FirebaseAuthStateManager` handles anonymous auth (auto-created) and Apple Sign-In with credential linking (anonymous → Apple, preserves UID).
  - `AccountView` in Settings provides sign-in/sign-out UI.
  - Google Sign-In deferred (needs separate SPM dep + OAuth client).
- **Guest Mode**: Local-only mode that lets someone use the app without affecting host data. Snapshots and restores state. Firebase sync and leaderboard publishing are disabled while active.
- **Sensitive data**: `PendingScoreStore` uses Keychain via `KeychainService` (migrated from UserDefaults).

## Achievements

- **Tiered system**: Bronze → Silver → Gold → Diamond across 10 categories.
- **Models**: `TieredAchievement`, `AchievementTier`, `AchievementCategory`, `TierRequirement`, `AchievementProgress`.
- **Checker**: `TieredAchievementChecker` is a pure `struct` — no `@MainActor`, no UI dependencies. Testable with 25 unit tests.
- **Flow**: `AppState.checkAchievements` → `TieredAchievementChecker` → direct call to `AchievementCelebrationCoordinator.queueCelebration()` → shows `AchievementUnlockCelebrationView`.
- **Persistence**: UserDefaults via `PersistenceService`, synced to Firestore.
- **ID Consistency**: Deterministic UUIDs via `AchievementCategory.consistentID` prevent duplicates during recalculation and sync.
- **Deduplication**: The `tieredAchievements` getter/setter include deduplication logic for persisted data.

## Smart Reminder Engine

All computation runs locally on device.

- **Algorithm**: Build a 24h histogram from the last 30 days of results. Slide a 2-hour window to find peak coverage. Suggest reminder 30 minutes before window start, clamped to 06:00–22:00.
- **Smart OFF**: User-selected time is respected.
- **Smart ON**: Recomputes at most every 2 days on day change.
- **Lifecycle**: Day change triggers `updateSmartRemindersIfNeeded()`.

## Analytics

- **Service**: `AnalyticsService` coordinates computation with fingerprint-based caching (result count + last timestamp). Cache auto-invalidates when data changes.
- **Computation**: `AnalyticsComputer` is a pure `nonisolated static` computation layer with `async let` parallelism. 34 unit tests.
- **Deep Dives**: Wordle/Nerdle (guess distribution), Pips (per-difficulty times), Pinpoint (guess distribution), Strands (hints distribution).
- **Weekly Recap**: ISO-week grouping with completion rate, consistency%, and streak stats.
- **CSV Export**: SwiftUI `ShareLink` exports current scope as CSV.
- **Dashboard**: 241 lines, delegates to 7 extracted section views in `Sections/`.

## Social: Friends & Leaderboard

**Model**
- Flat friends list (no circles). Friendships in Firestore `friendships` collection (bidirectional, pending/accepted).
- Friend codes: 6-char code generation, share, and lookup.
- All 17 games on leaderboard. Scores include `allowedReaders` array for privacy.
- `currentStreak` published to Firestore, displayed as 🔥 badge on leaderboard rows.
- "Hasn't played yet" section for friends without scores.

**Real-time Updates**
- Firestore snapshot listeners (`addScoreListener`, `addFriendshipListener`).
- Score listener only active when viewing today's date (past dates skip — no new scores possible).
- `FriendsViewModel` uses listeners with polling fallback for `MockSocialService`.
- Listener methods are `nonisolated` for `Sendable` conformance.

**Security**
- Scores: `allowedReaders` array-contains queries restrict leaderboard visibility to friends.
- Friendships: Only sender creates (userId1), only recipient accepts (userId2), userId fields immutable.
- Field validation enforced in Firestore rules for scores, friendships, and friend codes.

**Architecture**
- `SocialService` protocol with `FirebaseSocialService` (production) and `MockSocialService` (dev).
- `FriendsViewModel` orchestrates profile, friends, leaderboard, date paging, and listeners.
- `PendingScoreStore` handles offline score queue with Keychain persistence and retry on app activation.
