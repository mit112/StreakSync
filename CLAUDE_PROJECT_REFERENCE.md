# StreakSync — Project Reference Guide
> Created for long-term development sessions. Last updated: Feb 2026

---

## 1. What Is StreakSync?

StreakSync is a **native iOS app** (SwiftUI, MVVM) for tracking daily puzzle game streaks — Wordle, Quordle, Connections, NYT Mini, LinkedIn games, and 40+ others. Users share game results via iOS Share Extension; the app parses them, computes streaks, unlocks achievements, and syncs data through CloudKit and Firebase.

---

## 2. Architecture Overview

```
StreakSyncApp (@main)
  └─ AppContainer (DI container, @MainActor, ObservableObject)
       ├─ AppState (@Observable, central data store)
       ├─ NavigationCoordinator (tab + stack navigation)
       ├─ PersistenceService (UserDefaults + App Group)
       ├─ UserDataSyncService (CloudKit user data sync)
       ├─ GuestSessionManager (local-only guest sessions)
       ├─ FirebaseAuthStateManager (anonymous auth)
       ├─ FirebaseSocialService (leaderboards, friend circles)
       ├─ AnalyticsService (computed statistics)
       ├─ AchievementSyncService (CloudKit achievements)
       ├─ NotificationCoordinator + NotificationScheduler
       ├─ NetworkMonitor (offline queue flush)
       ├─ GameCatalog (@Observable, game registry + favorites)
       ├─ GameManagementState
       ├─ StreakSyncColors (sole color system, ThemeManager deleted)
       ├─ HapticManager, SoundManager, BrowserLauncher
       └─ AchievementCelebrationCoordinator
```

### Key Patterns
- **Dependency Injection**: `AppContainer` creates everything; injected via `.environmentObject()` / `.environment()`.
- **@Observable (Swift 5.9 Observation)**: `AppState` and `GameCatalog` use the new `@Observable` macro, accessed via `.environment()`.
- **ObservableObject**: `AppContainer`, `NavigationCoordinator`, `GuestSessionManager`, etc. still use `@Published` + `@EnvironmentObject`.
- **Tab-based navigation**: 4 tabs (Home, Awards, Friends, Settings), each with its own `NavigationStack` path.
- **Lazy tab loading**: Awards, Friends, and Settings tabs defer content creation until first selected.
- **Share Extension**: `StreakSyncShareExtension` parses game results from shared text and writes to App Group.
- **Actor isolation**: `GameResultIngestionActor` for thread-safe result ingestion.

---

## 3. Directory Structure (Source Only)

```
StreakSync/
├── App/
│   ├── StreakSyncApp.swift        # @main entry point, bootstrap
│   ├── AppContainer.swift         # DI container
│   ├── AppDelegate.swift          # UIKit lifecycle, Firebase config
│   ├── ContentView.swift          # Root view, scene phase, sheets
│   └── MainTabView.swift          # 4-tab navigation, iOS 26 support
│
├── Core/
│   ├── State/
│   │   ├── AppState.swift                  # Central data store (~380 lines, properties + core APIs)
│   │   ├── AppState+DuplicateDetection.swift # isDuplicateResult, buildResultsCache
│   │   ├── AppState+ResultAddition.swift   # addGameResult, social publishing
│   │   ├── AppState+GameLogic.swift        # Streak update, normalization
│   │   ├── AppState+Reminders.swift        # Streak risk detection, smart reminders
│   │   ├── AppState+Import.swift           # rebuildStreaksFromResults, Connections fix
│   │   ├── AppState+Persistence.swift      # Save/load methods
│   │   ├── AppState+TieredAchievements.swift # Achievement checking
│   │   └── GuestSessionManager.swift       # Guest mode snapshots
│   │
│   ├── Models/
│   │   ├── Shared/SharedModels.swift       # Core types: ScoringModel, Game, GameCategory, GameResult, GroupedGameResult (~450 lines)
│   │   ├── Shared/GameResultDisplay.swift  # GameResult display/emoji logic (~340 lines)
│   │   ├── Shared/CodableColor.swift       # Thread-safe codable color (~100 lines)
│   │   ├── Shared/FoundationExtensions.swift # Date + URL extensions (~60 lines)
│   │   ├── Shared/AppConstants.swift
│   │   ├── Game/GameDefinitions.swift      # All static Game instances + catalog arrays (~865 lines)
│   │   ├── Game/GameCatalog.swift          # @Observable game registry + favorites
│   │   ├── Game/GameResultParser.swift     # Parses shared text per game
│   │   ├── Game/GameSection.swift
│   │   ├── Streak/StreakModels.swift       # GameStreak model
│   │   ├── Achievement/                    # Tiered achievement models + store
│   │   ├── Analytics/AnalyticsModels.swift
│   │   └── Social/LeaderboardScoring.swift # DailyGameScore
│   │
│   ├── Services/
│   │   ├── Navigation/NavigationCoordinator.swift  # Destination/SheetDestination enums
│   │   ├── Persistence/PersistenceService.swift     # UserDefaults + App Group
│   │   ├── Sync/UserDataSyncService.swift           # CloudKit
│   │   ├── Sync/AppGroupBridge.swift                # Share Extension comms
│   │   ├── Sync/GameResultIngestionActor.swift      # Actor-isolated ingestion
│   │   ├── Social/FirebaseSocialService.swift       # Firestore leaderboards
│   │   ├── Social/SocialService.swift               # Protocol
│   │   ├── Notifications/NotificationScheduler.swift
│   │   ├── Analytics/AnalyticsService.swift
│   │   └── Utilities/GameDateHelper.swift
│   │
│   ├── Config/
│   │   ├── BetaFeatureFlags.swift
│   │   └── SocialFeatureFlags.swift
│   │
│   └── Errors/AppError.swift
│
├── Design System/
│   ├── Colors/
│   │   ├── StreakSyncColors.swift    # NEW: Semantic color system (primary palette)
│   │   ├── iOS26ColorSystem.swift   # iOS 26 specific colors
│   │   └── GradientSystem.swift     # Game-specific gradients
│   ├── Extensions/ColorTheme.swift  # Hex init, theme enums, Color extensions
│   ├── (ThemeManager.swift deleted)
│   ├── Glass/GlassComponents.swift  # Glassmorphism effects
│   ├── GameCards/ModernGameCard (+ model, icon, animations)
│   ├── Animation/AnimationSystem.swift
│   ├── Haptics/HapticManager.swift
│   ├── Sound/SoundManager.swift
│   └── SafeSFSymbol.swift, SFSymbolCompatibility.swift
│
├── Features/
│   ├── Dashboard/     # ImprovedDashboardView, headers, search, filters
│   ├── Games/         # GameDetailView, GameManagementView, ModernGameCard
│   ├── Achievement/   # TieredAchievementsGridView, celebration views
│   ├── Analytics/     # AnalyticsDashboardView, chart sections
│   ├── Streaks/       # AllStreaksView, StreakHistoryView
│   ├── Friends/       # FriendsView, circles, discovery, activity feed
│   ├── Settings/      # SettingsView, appearance, notifications, privacy
│   ├── Onboarding/    # BetaWelcomeView
│   ├── Components/    # NativeLargeTitleHeader, iOS26Components
│   └── Shared/        # Reusable components (EmptyStates, StatCard, etc.)
│
├── StreakSyncShareExtension/
│   └── ShareViewController.swift
│
└── StreakSyncTests/   # 8 test files
```

---

## 4. Color System Status

### Current: `StreakSyncColors` (sole color system)
- Lives in `Design System/Colors/StreakSyncColors.swift`
- Palette enum `PaletteColor`: primary (#58CC02 green), secondary (#FF9600 orange), background, cardBackground, textPrimary, textSecondary — each with `.darkVariant`
- Semantic API: `StreakSyncColors.primary(for:)`, `.background(for:)`, `.cardBackground(for:)`, `.gameColor(for:colorScheme:)`, etc.
- Uses iOS system colors for backgrounds (`Color(.systemBackground)`, `.secondarySystemBackground`)
- Color cache for performance
- **ThemeManager has been deleted** — all views use `@Environment(\.colorScheme)` + `StreakSyncColors` directly

### Also present: `ColorTheme.swift`
- Hex init on `Color`, theme enum definitions, static semantic colors on `Color` extension
- `GradientSystem.swift` — game-specific mesh gradients

---

## 5. Navigation System

**`NavigationCoordinator`** (ObservableObject):
- `selectedTab: MainTab` — .home, .awards, .friends, .settings
- Separate `NavigationPath` per tab: `homePath`, `awardsPath`, `friendsPath`, `settingsPath`
- `Destination` enum: `.gameDetail(Game)`, `.streakHistory(GameStreak)`, `.allStreaks`, `.achievements`, `.settings`, `.gameManagement`, `.tieredAchievementDetail(TieredAchievement)`, `.analyticsDashboard`, `.streakTrendsDetail(timeRange, game)`
- `SheetDestination` enum: `.addCustomGame`, `.gameResult(GameResult)`, `.tieredAchievementDetail(TieredAchievement)`
- Methods: `navigateTo(_:)`, `switchToTab(_:)`, `switchToTabAndNavigate(_:_:)`, `popToRoot()`, `presentSheet(_:)`, `dismissSheet()`
- Deep link support via `handleJoinGroupDeepLink(code:)` and URL scheme `streaksync://`

---

## 6. Data Models

| Model | Key Fields | Notes |
|-------|-----------|-------|
| `Game` | id (UUID), name, displayName, url, category, scoringModel, iconSystemName, backgroundColor (CodableColor) | Static catalog in `allAvailableGames`; 17 games with parsers |
| `GameResult` | id, gameId, gameName, date, score?, maxAttempts, completed, sharedText, parsedData | Validated on init; game-specific `displayScore` logic |
| `GameStreak` | id, gameId, gameName, currentStreak, maxStreak, totalGamesPlayed/Completed, lastPlayedDate, streakStartDate | `isActive` checks via `GameDateHelper` |
| `TieredAchievement` | id, tiers with progress | Bronze → Silver → Gold → Diamond |
| `DailyGameScore` | userId, dateInt, gameId, gameName, score, maxAttempts, completed | Firebase leaderboard entry |
| `GroupedGameResult` | For Pips (multiple difficulties per puzzle number) | |

**Scoring Models**: `.lowerAttempts`, `.lowerTimeSeconds`, `.lowerGuesses`, `.lowerHints`, `.higherIsBetter`

**Game Categories**: `.word`, `.math`, `.music`, `.geography`, `.trivia`, `.puzzle`, `.nytGames`, `.linkedinGames`, `.custom`

---

## 7. Supported Games (with parsers)

NYT: Wordle, Connections, Spelling Bee, Mini Crossword, Strands, Pips  
LinkedIn: Queens, Tango, Crossclimb, Pinpoint, Zip, Mini Sudoku  
Word: Quordle, Octordle  
Math: Nerdle  
(40+ additional games defined but may lack full parser support)

---

## 8. Key Services

| Service | Purpose |
|---------|---------|
| `UserDataSyncService` | CloudKit incremental sync (results, streaks) with offline queue |
| `FirebaseSocialService` | Firestore-backed leaderboards, friend circles, daily scores |
| `FirebaseAuthStateManager` | Anonymous Firebase auth with auto re-authentication |
| `AnalyticsService` | Computed stats (completion rates, trends) with cache invalidation |
| `NotificationScheduler` | Daily streak reminders with smart time suggestions |
| `AchievementSyncService` | CloudKit achievement sync (feature-flagged) |
| `GuestSessionManager` | Snapshot/restore host data for guest mode |
| `NetworkMonitor` | Flushes offline queue when connectivity returns |
| `AppGroupBridge` | Share Extension ↔ main app communication |
| `GameResultIngestionActor` | Thread-safe result ingestion actor |

---

## 9. Build & Configuration

- **Xcode project** (not SPM-only): `StreakSync.xcodeproj`
- **Targets**: StreakSync (app), StreakSyncShareExtension, StreakSyncTests
- **Dependencies**: Firebase (Core, Firestore, Auth) via SPM
- **URL Scheme**: `streaksync://`
- **App Group**: `group.com.mitsheth.StreakSync`
- **CloudKit Container**: configured in `CloudKitConfiguration.swift`
- **Background Modes**: remote-notification
- **Entitlements**: CloudKit, App Groups
- **iOS 26 support**: `@available(iOS 26.0, *)` checks with `.tabBarMinimizeBehavior`, `.navigationTransition(.zoom)`, etc.
- **SwiftLint**: `.swiftlint.yml` present

---

## 10. Current State & Active Work

### Recently Completed
- Migrated from old color palette to `StreakSyncColors` with vibrant green (#58CC02) + warm orange (#FF9600)
- Fixed compilation errors from color system migration
- Using iOS system colors for backgrounds (proper light/dark mode support)
- SF Symbol compatibility layer (`SafeSFSymbol.swift`) for strict validation
- **Feb 2026 Refactoring Session** (all 8 issues resolved):
  - Fixed `saveAllData()` persistence key mismatch bug (data loss risk)
  - Deleted orphaned ThemeManager.swift (zero references, wasn't even in Xcode project)
  - Decomposed AppState.swift: 1042 → 380 lines (+DuplicateDetection, +ResultAddition, +Reminders)
  - Decomposed SharedModels.swift: 1770 → 452 lines (GameDefinitions, GameResultDisplay, CodableColor, FoundationExtensions)
  - Added CodableColor.swift + FoundationExtensions.swift to Share Extension target in pbxproj
  - Deduplicated MainTabView.swift: 424 → 204 lines (eliminated copy-pasted iOS 26/standard TabViews + dead ios26DestinationView)
  - Centralized all notification names as typed constants in AppConstants.swift (replaced ~30 raw string usages)
  - Fixed ensureStreaksForAllGames not called after rebuildStreaksFromResults

### Remaining Known Issues
- **Light mode contrast**: Previously "washed out" — improved with new palette but may need per-component tuning
- **iOS 26 features**: Conditional code for tab bar minimize behavior, zoom transitions, enhanced card backgrounds
- **ImprovedDashboardView duplication**: iOS 26 and legacy body are still largely duplicated (~500 lines), similar to the MainTabView pattern that was already fixed

---

## 11. Quick Reference: Environment Injection

```swift
// In MainTabView / ContentView:
.environmentObject(container)                      // AppContainer
.environment(container.appState)                   // AppState (@Observable)
.environmentObject(container.navigationCoordinator) // NavigationCoordinator
.environmentObject(container.guestSessionManager)   // GuestSessionManager
.environmentObject(container.userDataSyncService)   // UserDataSyncService
.environmentObject(BetaFeatureFlags.shared)         // Feature flags
.environment(container.gameCatalog)                  // GameCatalog (@Observable)
```

---

## 12. Testing

8 test files in `StreakSyncTests/`:
- `GameResultParserTests` — parsing shared text
- `AchievementCheckerTests` — tiered achievement logic
- `LeaderboardScoringTests` — daily game score computation
- `BetaFeatureFlagsTests` — feature flag behavior
- `LoadAndAchievementsTests` — load + achievement integration
- `MigrationAndSyncTests` — CloudKit sync scenarios
- `ShareExtensionIngestionTests` — share extension pipeline
- `SocialSettingsServiceTests` — privacy settings

---
