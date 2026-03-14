# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Critical Rules

- NEVER modify .xcodeproj or .pbxproj files directly — they corrupt easily
- NEVER edit .xcassets, .xcstrings, .storyboard, or .xib files
- After making changes, ALWAYS build to verify compilation before committing
- When creating new Swift files, place them in the correct directory and match the file header format exactly
- Do NOT "modernize" AppContainer to @Observable — it uses ObservableObject because @EnvironmentObject requires it
- Do NOT regress AppState or GameCatalog to ObservableObject/@Published — they use @Observable deliberately

## API Standards (STRICT)

- Use NavigationStack (NOT NavigationView)
- Use .foregroundStyle() (NOT .foregroundColor())
- Use async/await for all async work (NOT GCD/DispatchQueue)
- Use `Logger` from OSLog for logging (NOT print())
- Safe unwrapping only — no force unwrap (`!`), force try (`try!`), or force cast (`as!`)

## Workflow Rules
- When writing or modifying SwiftUI views, consult the swiftui-pro skill references before generating code
- **ALWAYS use XcodeBuildMCP tools** (`build_sim`, `test_sim`, `build_run_sim`) instead of raw `xcodebuild` bash commands for builds and tests. Set session defaults at the start of each session:
  ```
  mcp__XcodeBuildMCP__session_set_defaults(scheme: "StreakSync", simulatorName: "iPhone 17 Pro Max", projectPath: "StreakSync.xcodeproj")
  ```

## Build & Test Commands

```bash
# Build (no code signing needed for simulator)
xcodebuild build \
  -project StreakSync.xcodeproj -scheme StreakSync \
  -destination 'platform=iOS Simulator,id=D799B5E4-DB81-40AE-84A2-FA4B44F2A44E' \
  -skipPackagePluginValidation CODE_SIGNING_ALLOWED=NO --quiet \
  2>&1 | xcsift -w

# Run all tests (unit + UI)
xcodebuild test \
  -project StreakSync.xcodeproj -scheme StreakSync \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -skipPackagePluginValidation CODE_SIGNING_ALLOWED=NO

# Run a single test class
xcodebuild test \
  -project StreakSync.xcodeproj -scheme StreakSync \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -skipPackagePluginValidation CODE_SIGNING_ALLOWED=NO \
  -only-testing:StreakSyncTests/StreakLogicTests

# Run a single test method
xcodebuild test \
  -project StreakSync.xcodeproj -scheme StreakSync \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -skipPackagePluginValidation CODE_SIGNING_ALLOWED=NO \
  -only-testing:StreakSyncTests/StreakLogicTests/testStreakContinuation

# Firestore security rules tests (Node.js)
cd firestore-rules-tests && npm install
firebase emulators:start --only firestore &
node firestore.rules.test.mjs

# Lint (SwiftLint must be installed)
swiftlint
```

Pipe through `| xcpretty` for readable output if xcpretty is installed.

## Architecture

**iOS-only SwiftUI app** targeting iOS 26+ / Swift 6.0 / Xcode 26. Backend is Firebase (Firestore + Auth) via SPM. No CocoaPods, no Carthage.

### Targets

- **StreakSync** — main app target
- **StreakSyncShareExtension** — Share Extension (separate target, shared App Group)
- **StreakSyncTests** — unit + UI tests (parallelized via StreakSync.xctestplan)

### Dependency Injection

`AppContainer` (`App/AppContainer.swift`) is the single DI container. It creates all services in dependency order and injects them into the SwiftUI environment as `@EnvironmentObject`. It also provides view model factory methods (`makeGameDetailViewModel()`, etc.).

- `AppContainer` uses `ObservableObject` (required for `@EnvironmentObject` — do not change)
- `AppState` and `GameCatalog` use `@Observable` (Swift Observation — do not change)

### AppState Decomposition

`AppState` (`Core/State/AppState.swift`) is the central data store, split into 7 focused extension files:

- `+DuplicateDetection` — result dedup with cached hash sets
- `+ResultAddition` — adding game results, social score publishing
- `+GameLogic` — streak calculation (`calculateUpdatedStreak`)
- `+Reminders` — smart reminder engine, streak-at-risk detection
- `+Persistence` — save/load, normalization, data refresh
- `+TieredAchievements` — achievement checking, persistence, recompute
- `+Import` — rebuild streaks from results, data migration

### Service Layer (Core/Services/)

Protocol-oriented with production and mock implementations:
- `SocialService` protocol → `FirebaseSocialService` (prod) / `MockSocialService` (dev/test)
- `PersistenceServiceProtocol` → `UserDefaultsPersistenceService` (prod) / `MockPersistenceService` (test)
- `FirebaseAuthStateManager` — anonymous auth + Apple Sign-In with credential linking
- `AnalyticsService` — delegates computation to `AnalyticsComputer` (pure static struct)
- `TieredAchievementChecker` — pure struct, no UI deps, fully testable

### Share Extension Pipeline

`StreakSyncShareExtension/` → saves result to App Group (key-based queue with `synchronize()`) → Darwin notification wakes main app → `AppGroupBridge` detects via lifecycle + Darwin observers → `AppGroupResultMonitor` loads queue → `NotificationCoordinator` routes `.gameResultReceived` → `AppState.addGameResult` (on `@MainActor`) → UI refresh.

Queue cleanup uses targeted key removal (only processed keys) to avoid cross-process TOCTOU races with the Share Extension.

Deep links use `streaksync://` URL scheme. Payload keys centralized in `AppConstants.DeepLinkKeys`. Notification UserDefaults keys centralized in `AppConstants.NotificationSettings`.

### Game System

Games have deterministic UUIDs (hardcoded in `GameDefinitions.swift`). 16 built-in games + custom game support. Each game has a dedicated parser for share text extraction. Game detection and parsing logic lives in the models layer and is tested via `GameDetectionTests` and `GameResultParserTests`.

### Social & Leaderboard

Flat friends list (no circles). Friendships are bidirectional Firestore docs with deterministic IDs (`[uid1, uid2].sorted().joined(separator: "_")`). Profile read access is gated by an `areFriends()` security rule that checks the `friendships` collection directly — no denormalized `friends` array needed. Scores use `allowedReaders` arrays for privacy-scoped queries; `allowedReaders` is reconciled (last 30 days) whenever friendships change. Real-time Firestore snapshot listeners for scores and friendships. `PendingScoreStore` queues scores in Keychain for offline retry. Bidirectional friend requests auto-accept (if A sends B a request while B has a pending request to A).

### Firestore Security Rules

Rules in `firestore.rules` with a 62-case pen test suite in `firestore-rules-tests/`. Rules enforce ownership, field validation, string size limits, `allowedReaders` for score privacy, and `areFriends()` for profile read access via friendship collection lookups.

## Code Conventions

- **File headers required** by SwiftLint — every Swift file must start with:
  ```
  //
  //  FileName.swift
  //  StreakSync
  //
  //  Description
  //
  ```
- **No `print()` statements** — use `Logger` from OSLog (SwiftLint custom rule enforced)
- **No force try (`try!`)** or **force cast (`as!`)** — SwiftLint errors on these
- **Force unwrap (`!`)** is a SwiftLint error — use safe unwrapping
- **Line length**: warning at 120, error at 150
- **File length**: warning at 400 lines, error at 500
- **Function body length**: warning at 50 lines, error at 80
- **Sorted imports** enforced
- **`@MainActor`** on `AppState`, `AppContainer`, and all ViewModels
- Dates use ISO8601 encoding/decoding throughout persistence
- Sensitive data goes in Keychain (`KeychainService`), never UserDefaults


## Simulator Reference

**Always reference simulators by UDID, not by name.**

- iPhone 17 Pro Max: `D799B5E4-DB81-40AE-84A2-FA4B44F2A44E` (preferred for testing)
- iPhone 17 Pro: `741DAF14-ED20-4EE7-9E29-E81494F05290`

Preferred destination string:
`platform=iOS Simulator,id=D799B5E4-DB81-40AE-84A2-FA4B44F2A44E`

**Always launch apps with:**
```bash
xcrun simctl launch --terminate-running-process --console-pty D799B5E4-DB81-40AE-84A2-FA4B44F2A44E com.mitsheth.StreakSync
```
`--terminate-running-process` is mandatory — without it, launch silently does nothing if the app is already running.

**Never delete DerivedData.** If builds are broken, clean with xcodebuild clean instead.

## Key File Locations

- Entry point: `StreakSync/App/StreakSyncApp.swift`
- DI container: `StreakSync/App/AppContainer.swift`
- Central state: `StreakSync/Core/State/AppState*.swift` (8 files)
- Achievement models: `StreakSync/Core/Models/Achievement/TieredAchievementModels.swift` + `AchievementFactory.swift`
- Settings views: `StreakSync/Features/Settings/Views/` (SettingsView, AccountView, AboutView, DataManagementView, NotificationSettingsView, AppearanceSettingsView)
- Settings VM: `StreakSync/Features/Settings/ViewModels/SettingsViewModel.swift`
- Game definitions: `StreakSync/Core/Models/Game/GameDefinitions.swift`
- Firestore rules: `firestore.rules`
- CI config: `.github/workflows/ci.yml`
- Test plan: `StreakSync.xctestplan` (parallelized unit + UI tests)
