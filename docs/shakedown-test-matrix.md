# StreakSync Shakedown Test Matrix

Date: 2026-02-17  
Project: `StreakSync`  
Goal: Break core flows intentionally and capture reproducible failures.

## Environment

- macOS 25.3.0
- Xcode CLI (`xcodebuild`) with iOS Simulator `iPhone 17 Pro Max (iOS 26.0)`
- Firebase CLI `15.6.0`
- Firestore Emulator `v1.20.2`

## Execution Summary

| Area | Scenario | Method | Result | Notes |
|---|---|---|---|---|
| Baseline | Full scheme tests | `xcodebuild test` | FAIL | 180 total, 174 pass, 6 fail |
| Startup chaos | Repeated cold launch/terminate x20 | `simctl launch` loop | PASS | 0 launch failures |
| Auth transition | Anonymous->provider linking race | Runtime test | BLOCKED | Requires interactive provider auth on test device |
| Sync integrity | Merge/conflict regression suite | `SyncMergeTests` | PASS | 13/13 passed |
| Sync conversion | Firestore round-trip conversion | `SyncServiceConversionTests` | FAIL | Crash in round-trip test |
| Notifications | Reminder content formatting | `NotificationContentTests` | FAIL | 4 failing assertions |
| Analytics | Weekly completion calculation | Isolated unit test | FAIL | Expected 0.666..., got 1.0 |
| Security rules | Unauth read/write on `/users/*/gameResults/*` | Firestore emulator REST | PASS | `403 PERMISSION_DENIED` |
| Security rules | Unauth read/write on `/scores/*` | Firestore emulator REST | PASS | `403 PERMISSION_DENIED` |
| UI flow automation | Run UI target from scheme/test plan | `xcodebuild -only-testing:StreakSyncUITests` | PASS | Ran 3 consecutive passes with 0 failures |
| UI flow depth (initial) | Validate coverage of critical app journeys | Inspect executed UI cases | FAIL | Initially only 3 template tests executed |
| UI flow depth (expanded) | Smoke + rapid tab traversal | New UI suite + 3-pass rerun | PASS | 6 tests/run, all green across 3 passes |
| UI flow depth (phase 2) | Settings/Friends deeper journeys | Enhanced suite + 3-pass rerun | FAIL | 2 deterministic failures tied to Manage Friends sheet presentation |
| Fix batch 1 targeted verification | Notification + sync conversion + analytics regressions | Focused rerun (`FixBatch1_Targeted_Final.xcresult`) | PASS | `17/17` tests passed |
| Fix batch 1 UI verification | Full phase-2 UI suite after fixes | Multiple full reruns | FAIL | Same 2 Manage Friends-related tests still failing |
| Fix batch 1 UI mitigation retry | Friends control semantics + hit-target hardening | Full UI rerun (`FixBatch1_UIFull_AfterSemantics.xcresult`) | FAIL | Still `2/10` failing at Manage Friends presentation step |
| Friends root-cause verification | Isolated failing friends tests | Targeted reruns (`FriendsRootCause_OnlyManage_PostCompileFix`, `FriendsRootCause_Cross_PostCompileFix`) | PASS | Both previously failing cases now pass |
| Friends root-cause regression check | Full UI phase-2 suite after overlay fix | `FriendsRootCause_UIFull_Cleaned.xcresult` | PASS | `10/10` UI tests passing |
| Security rules (authenticated) | Friends/scores transition + malformed payload checks | Firestore rules unit harness (`firebase emulators:exec --only firestore "npm --prefix firestore-rules-tests test"`) | PASS | 9 targeted authenticated rules cases passed |

## Commands Run

- Baseline full tests:
  - `xcodebuild test -project "StreakSync.xcodeproj" -scheme "StreakSync" -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -resultBundlePath "ShakedownBaseline.xcresult" CODE_SIGNING_ALLOWED=NO`
- Isolated failing suites:
  - `... -only-testing:StreakSyncTests/NotificationContentTests`
  - `... -only-testing:StreakSyncTests/SyncServiceConversionTests`
  - `... -only-testing:StreakSyncTests/AnalyticsComputerTests/test_computeWeeklySummaries_completionRate_calculatesCorrectly`
- Sync merge verification:
  - `... -only-testing:StreakSyncTests/SyncMergeTests`
- UI shakedown reruns:
  - `... -only-testing:StreakSyncUITests -resultBundlePath "Shakedown_UITests_Run1.xcresult"`
  - `... -only-testing:StreakSyncUITests -resultBundlePath "Shakedown_UITests_Run2.xcresult"`
  - `... -only-testing:StreakSyncUITests -resultBundlePath "Shakedown_UITests_Run3.xcresult"`
- Expanded UI flow shakedown reruns:
  - `... -only-testing:StreakSyncUITests -resultBundlePath "Shakedown_UITests_Flow_Run1.xcresult"`
  - `... -only-testing:StreakSyncUITests -resultBundlePath "Shakedown_UITests_Flow_Run2.xcresult"`
  - `... -only-testing:StreakSyncUITests -resultBundlePath "Shakedown_UITests_Flow_Run3.xcresult"`
- Phase 2 deeper-flow reruns:
  - `... -only-testing:StreakSyncUITests -resultBundlePath "Shakedown_UITests_Phase2_Run1.xcresult"`
  - `... -only-testing:StreakSyncUITests -resultBundlePath "Shakedown_UITests_Phase2_Run2.xcresult"`
  - `... -only-testing:StreakSyncUITests -resultBundlePath "Shakedown_UITests_Phase2_Run3.xcresult"`
- Startup stress:
  - 20x `simctl launch` + `simctl terminate` loop
- Firestore rules shakedown:
  - `firebase emulators:exec --only firestore '<curl probes>'`
- Firestore rules authenticated unit suite:
  - `firebase emulators:exec --only firestore "npm --prefix firestore-rules-tests test"`

## Key Raw Outcomes

- Baseline failures:
  - `AnalyticsComputerTests/test_computeWeeklySummaries_completionRate_calculatesCorrectly()`
  - `NotificationContentTests/testMoreThanThreeGamesContent()`
  - `NotificationContentTests/testSingleGameContent()`
  - `NotificationContentTests/testThreeGamesContent()`
  - `NotificationContentTests/testTwoGamesContent()`
  - `SyncServiceConversionTests/testGameResultFromFirestoreRoundTripPreservesValues()`
- Firestore emulator responses:
  - `READ_UNAUTH=403`, `WRITE_UNAUTH=403` on user docs/results
  - `READ_SCORE_UNAUTH=403`, `WRITE_SCORE_UNAUTH=403` on scores
- Firestore authenticated rules-unit outcomes:
  - `firestore-rules-tests/firestore.rules.test.mjs`: `9/9` PASS
  - Negative-path create/update/read checks correctly returned `PERMISSION_DENIED`
- UI shakedown outcomes:
  - Run 1: `total=3 failed=0 skipped=0`
  - Run 2: `total=3 failed=0 skipped=0`
  - Run 3: `total=3 failed=0 skipped=0`
  - Executed cases:
    - `StreakSyncUITestsLaunchTests/testLaunch`
    - `StreakSyncUITests/testExample()`
    - `StreakSyncUITests/testLaunchPerformance()`
- Expanded UI shakedown outcomes:
  - Flow Run 1: `total=6 failed=0`
  - Flow Run 2: `total=6 failed=0`
  - Flow Run 3: `total=6 failed=0`
  - Executed cases:
    - `StreakSyncUITests/testAppLaunchesToTabLayout()`
    - `StreakSyncUITests/testAllCoreTabsExistAndAreHittable()`
    - `StreakSyncUITests/testTabSwitchingShowsContentContainers()`
    - `StreakSyncUITests/testRapidTabSwitchingStress()`
    - `StreakSyncUITests/testLaunchPerformance()`
    - `StreakSyncUITestsLaunchTests/testLaunch`
- Phase 2 deeper-flow outcomes:
  - Phase2 Run 1: `total=10 failed=2`
  - Phase2 Run 2: `total=10 failed=2`
  - Phase2 Run 3: `total=10 failed=2`
  - Deterministically failing cases:
    - `StreakSyncUITests/testFriendsManageSheetOpensAndCloses()`
    - `StreakSyncUITests/testCrossFeatureNavigationStress()`
  - New passing phase-2 cases:
    - `StreakSyncUITests/testSettingsSubscreensOpenAndReturn()`
    - `StreakSyncUITests/testNotificationScreenStateRendersInAnyPermissionMode()`
- Friends root-cause verification outcomes:
  - `FriendsRootCause_OnlyManage_PostCompileFix`: PASS
  - `FriendsRootCause_Cross_PostCompileFix`: PASS
  - `FriendsRootCause_Targeted_Cleaned`: PASS
  - `FriendsRootCause_UIFull_Cleaned`: `total=10 failed=0`

## Blocked / Not Fully Exercised

- Real-device provider auth turbulence tests (Apple/Google) were not runnable from CLI-only harness.
- Notification DST/timezone runtime delivery checks require clock/timezone mutation on device/simulator plus notification permission workflow scripting.
- UI stress now includes settings deep navigation and rapid traversal; friend-management entry path issue is fixed, while deeper flows (result import, notifications deep-linking) remain unautomated.
