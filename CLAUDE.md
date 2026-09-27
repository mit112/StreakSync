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
  mcp__XcodeBuildMCP__session_set_defaults(scheme: "StreakSync", simulatorName: "iPhone 18 Pro", projectPath: "StreakSync.xcodeproj")
  ```

## Build & Test Commands

```bash
# Build (no code signing needed for simulator)
xcodebuild build \
  -project StreakSync.xcodeproj -scheme StreakSync \
  -destination 'platform=iOS Simulator,id=D38CD57F-C3A1-4EEA-9F55-92AE1DE51DC2' \
  -skipPackagePluginValidation CODE_SIGNING_ALLOWED=NO -quiet \
  2>&1 | xcsift -w

# Run all tests (unit + UI)
xcodebuild test \
  -project StreakSync.xcodeproj -scheme StreakSync \
  -destination 'platform=iOS Simulator,id=D38CD57F-C3A1-4EEA-9F55-92AE1DE51DC2' \
  -skipPackagePluginValidation CODE_SIGNING_ALLOWED=NO

# Run a single test class
xcodebuild test \
  -project StreakSync.xcodeproj -scheme StreakSync \
  -destination 'platform=iOS Simulator,id=D38CD57F-C3A1-4EEA-9F55-92AE1DE51DC2' \
  -skipPackagePluginValidation CODE_SIGNING_ALLOWED=NO \
  -only-testing:StreakSyncTests/StreakLogicTests

# Run a single test method
xcodebuild test \
  -project StreakSync.xcodeproj -scheme StreakSync \
  -destination 'platform=iOS Simulator,id=D38CD57F-C3A1-4EEA-9F55-92AE1DE51DC2' \
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

### Run the lint gate with `--no-cache`

`swiftlint` caches per-file results and the cache **can go stale after an edit**, silently
under-reporting. Measured 2026-09-21 on this repo: a cached `swiftlint` run reported
**0 violations** for `StreakSyncShareExtension/ShareViewController.swift` while
`swiftlint lint --no-cache` on the same tree reported **5** in that file — including a
`line_length` and a `file_length` violation that had just been introduced. Whole-repo
totals differed by 5 (375 cached vs 380 uncached). A cached run is fine for a quick
look; **the gate is `swiftlint lint --no-cache`**, and "my changes added no new
violations" is only meaningful when both sides of the comparison were uncached.

To get a trustworthy before/after, lint `HEAD` in a throwaway worktree rather than
trusting a remembered number:

```bash
git worktree add --detach /tmp/baseline HEAD
(cd /tmp/baseline && swiftlint lint --no-cache | tail -1)
git worktree remove --force /tmp/baseline
```

### The lint gate is the CLI, not the build phase

Run `swiftlint` from the terminal and check the exit code. **Do not trust the SwiftLint Run
Script build phase** — `ENABLE_USER_SCRIPT_SANDBOXING = YES` confines it, so it lints 2 files
out of 213 and reports a green "0 violations" while the CLI on the same tree reports errors.
Baseline as of 2026-08-29: `swiftlint` exits **0** with 385 warnings against a
`warning_threshold` of 400 — that threshold is itself an error-severity rule, so adding ~15
warnings turns the gate red. `included:` covers `StreakSync`, `StreakSyncShareExtension`,
`StreakSyncTests` and `StreakSyncWidget`; a new top-level directory left out of that list is
silently unlinted.

### Running tests — read this before concluding "the runner is broken"

The unit suite runs fine: as of 2026-08-31, **658 pass / 0 fail / 6 skipped**
(`-only-testing:StreakSyncTests`) in about a minute. The 6 skips are deliberate — all of
`PendingSaveStoreTests`, via `XCTSkipUnless(probeSucceeded, "Keychain unavailable in this
environment")`. That reconciles: `StreakSyncTests/` holds 664 `func test*`, and 658 + 6 = 664. Prefer XcodeBuildMCP: `build_sim(buildForTesting: true)` then
`test_sim(testProductsPath: <that>, extraArgs: ["-only-testing:StreakSyncTests"])`.

**Don't count tests by grepping the log — read the result bundle.** Pass
`-resultBundlePath Out.xcresult`, then:

```bash
xcrun xcresulttool get test-results summary --path Out.xcresult | jq \
  '{result, totalTestCount, passedTests, failedTests, skippedTests}'
```

Verified 2026-09-21 against the unit target: `{"result":"Passed","totalTestCount":664,
"passedTests":658,"failedTests":0,"skippedTests":6}` — exactly the documented baseline,
from one command. `build-results` is the equivalent for warnings and errors. This has been
available since Xcode 16; the project simply never used it.

Log-scraping is the fallback, and it is genuinely treacherous — it over- *and*
under-counts. Measured 2026-09-21 on the UI target: the log printed
`Executed 18 tests` and 18 `Test Case … passed` lines, but only **15 distinct test names**,
and `StreakSyncUITests/` contains exactly **15 `func test*`**. Three cases are counted twice
across suite levels. **The UI suite is 15 tests, not 18** — every "18 UI tests" figure in
this repo's history came from that artifact. If you must scrape, match `passed on 'Clone`
rather than `^Test case` (parallel clones truncate prefixes) and always `sort -u` the test
names before counting.

- `Early unexpected exit, operation never finished bootstrapping — Test crashed with
  signal abrt before establishing connection` means **the test host aborted**, not that the
  runner is broken. It is almost always a Debug `assert` in app code tripped by a bad
  fixture — `GameResult`'s initializer asserts the score matches the game's scoring model,
  so e.g. `score: 7, maxAttempts: 6` takes down the entire run. Bisect with `-only-testing:`
  down to one test; the crash usually reproduces from fixture construction alone.
- `Failed to prepare device 'Clone N of …' — Timed out trying to boot simulator` IS
  environmental (parallel clone booting) and appears as an extra "System Failures" entry.
  It does not invalidate the tests that passed.
- CI runs **both** targets in one `xcodebuild` invocation as of 2026-08-29. That matters:
  unit tests execute *inside the app* as its test host, so they write to the app's
  `UserDefaults`, and UI tests then launch into that state. Two UI tests passed locally
  and in a UI-only run, then failed on CI for exactly this reason. UI tests must reset
  their own state — `--uitest-reset` wipes the whole persistent domain. If a UI test
  passes alone but fails in CI, suspect unit-test pollution before suspecting flakiness.
- The "two pathologically slow tests" note that used to live here was **measured false on
  2026-08-29** and has been removed. `testAppGroupQueue_WriteLoadClear` runs in 0.043s, each
  `FirstShareCelebrationTriggerTests` case in ~0.006s, and the slowest test in the suite is
  0.069s — 454 cases total 0.47s. The ~56s wall clock is compile plus simulator boot, not tests.

## Architecture

**iOS-only SwiftUI app** with an **iOS 18.6 deployment target** / Swift 6.0. iOS 26-only APIs are used behind `#available(iOS 26, *)` gates, never unconditionally. Backend is Firebase (Firestore + Auth) via SPM. No CocoaPods, no Carthage.

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

`ShareViewController` presents a SwiftUI confirmation sheet (processing/success/failure states) instead of `UIAlertController`. Success card shows game icon (tinted via `Game.backgroundColor`), `displayName`, `displayScore` (parser-provided or fallback), and a single primary "Done" button. **iOS 26 blocks Share Extensions from foregrounding the host app** (`extensionContext.open` and the `perform(openURL:)` responder-chain trick both fail), so tapping Done writes a `pendingDeepLinkGameId` key into the App Group; on the main app's next activation, `AppGroupBridge.consumePendingDeepLinkIfNeeded()` fires `.openGameRequested` and routes the user to the game detail. Result-imported local notifications (`NotificationDelegate.handleOpenGame`) provide the actual one-tap transition path.

Deep links use `streaksync://` URL scheme. Payload keys centralized in `AppConstants.DeepLinkKeys`. Notification UserDefaults keys centralized in `AppConstants.NotificationSettings`. App Group keys (including `pendingDeepLinkGameId`) centralized in `AppConstants.AppGroup` — but the Share Extension target hardcodes them (`"group.com.mitsheth.StreakSync"`, `"pendingDeepLinkGameId"`) because it doesn't have `AppConstants` in its file membership.

### Game System

Games have deterministic UUIDs (hardcoded in `GameDefinitions.swift`). 15 built-in games, no custom-game creation flow. Each game has a dedicated parser for share text extraction. Game detection and parsing logic lives in the models layer and is tested via `GameDetectionTests` and `GameResultParserTests`.

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


## Toolchain — one Xcode, as of 2026-09-21

| Job | Xcode | Path |
|---|---|---|
| Everything — dev, tests, simulators, archives | **27.0 GA (27A266a)** | `/Applications/Xcode-27.0.0.app` |

The two-Xcode split this section used to describe is **obsolete**. It existed
because the App Store rejects binaries built with a beta Xcode, so archives
needed a separate release toolchain. 27.0 shipped GA, the beta was removed, and
27.0 GA now serves both jobs. `xcodes installed` is the authority.

> **Machine was reset 2026-09-03.** Xcode 27.0 GA was installed 2026-09-21 and the
> iOS platform downloaded the same day (`xcodebuild -downloadPlatform iOS`) — a
> fresh Xcode ships **no simulator runtimes at all**, so `simctl list runtimes`
> comes back empty and every `-destination` fails until you download it. Simulator
> devices then have to be created by hand; only the ones listed below exist.

Since there is only one Xcode, `open -a Xcode` works again and the `-10664`
`kLSIncompatibleApplicationVersionErr` workaround is no longer needed. (It applied
because two bundles both declared `CFBundleIdentifier = com.apple.dt.Xcode`, so
LaunchServices always resolved to the higher-versioned one.)

If a second Xcode is ever installed alongside this one, select per command with
`DEVELOPER_DIR` rather than switching the global `xcode-select` default, and
remember each Xcode needs its own `xcodebuild -downloadPlatform iOS`.

### Release flow (all CLI, no Organizer)

Bump `MARKETING_VERSION` on **both** `StreakSync` and `StreakSyncShareExtension` —
Apple rejects an extension whose `CFBundleShortVersionString` differs from the app.
Version components compare numerically, so 1.22 follows 1.21 (1.3 would be *lower*).

```bash
# 1. Archive
DEVELOPER_DIR=/Applications/Xcode-27.0.0.app/Contents/Developer xcodebuild archive \
  -project StreakSync.xcodeproj -scheme StreakSync \
  -destination 'generic/platform=iOS' \
  -archivePath ~/Library/Developer/Xcode/Archives/<date>/StreakSync-<ver>.xcarchive \
  -allowProvisioningUpdates -skipPackagePluginValidation

# 2. Export (re-signs with Apple Distribution). ExportOptions.plist:
#    method=app-store-connect, destination=export, teamID=3P89U4WZAB,
#    signingStyle=automatic, manageAppVersionAndBuildNumber=false
DEVELOPER_DIR=... xcodebuild -exportArchive -archivePath <archive> \
  -exportOptionsPlist ExportOptions.plist -exportPath <dir> -allowProvisioningUpdates

# 3. Validate, then upload
DEVELOPER_DIR=... xcrun altool --validate-app -f <ipa> -t ios -u <apple-id> -p "$ASC_PW"
DEVELOPER_DIR=... xcrun altool --upload-app  -f <ipa> -t ios -u <apple-id> -p "$ASC_PW"
```

`$ASC_PW` is an app-specific password from appleid.apple.com. Set it and run the
command in the *same* shell invocation, or it arrives empty and altool reports
`-20101 "Your Apple Account or password was entered incorrectly"` — which looks
like a wrong password rather than a missing one.

**Xcode Cloud is set up and is now the primary release path** (working since
2026-08-27; the manual archive flow above is the fallback). Workflow **"Default"**
on `mit112/StreakSync`: Branch Changes → `main` (any file change) triggers an
**Archive - iOS** action, scheme `StreakSync`, Distribution Preparation = **App
Store Connect**, which archives with a cloud GA Xcode and uploads to TestFlight.
So a release no longer needs the release Xcode installed locally — push to `main`
and the cloud archives it (never a beta binary).

Two `ci_scripts/` drive it (must stay executable and pushed — CI clones the repo,
not the working tree):
- `ci_post_clone.sh` — materializes the gitignored `GoogleService-Info.plist` from
  the `FIREBASE_PLIST_B64` secret env var, hard-failing if `PROJECT_ID` is wrong.
- `ci_pre_xcodebuild.sh` — `agvtool new-version -all "$CI_BUILD_NUMBER"` stamps every
  target's build number so uploads never collide.

`CI_BUILD_NUMBER` starts at 1 per workflow, so the marketing version was bumped to
**1.23** (build 12 under 1.22 was already on App Store Connect) to give a clean
`(1.23, 1)` first build. Submission to App Review is still manual in App Store
Connect — Xcode Cloud only delivers the build.

## Simulator Reference

**Always reference simulators by UDID, not by name.**

- iPhone 18 Pro: `D38CD57F-C3A1-4EEA-9F55-92AE1DE51DC2` (iOS 27.0 — preferred)
- iPhone 18 Pro Max: `398075D8-1B19-41D7-88A6-8CB001C22B3F` (iOS 27.0)

> There is no iPhone 17 Pro or 17 Pro Max device right now (the set was re-created on 2026-09-27) — create one only if you need it
> (`xcrun simctl create "iPhone 17 Pro Max" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max com.apple.CoreSimulator.SimRuntime.iOS-27-0`).
> Each booted simulator costs roughly 2.6 GB, and disk on this machine is tight.

> **UDID drift:** These UDIDs change whenever Xcode is reinstalled or simulators are re-created. If `xcodebuild` rejects the destination with "device not found", run `xcrun simctl list devices available | grep "iPhone 18 Pro"` and update this file.

Preferred destination string:
`platform=iOS Simulator,id=D38CD57F-C3A1-4EEA-9F55-92AE1DE51DC2`

**Always launch apps with:**
```bash
xcrun simctl launch --terminate-running-process --console-pty D38CD57F-C3A1-4EEA-9F55-92AE1DE51DC2 com.mitsheth.StreakSync
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
