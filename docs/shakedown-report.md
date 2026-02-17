# StreakSync Shakedown Report

Date: 2026-02-17  
Scope: Simulator + auth/sync/notification/rules surfaces (plus UI automation viability)  
Evidence sources: `xcodebuild` result bundles, Firestore Emulator probes, targeted code-path review

## Findings (Highest Severity First)

## 1) Crash in sync conversion path test

- Severity: High
- Area: Sync / Firestore conversion
- Evidence:
  - `SyncServiceConversionTests/testGameResultFromFirestoreRoundTripPreservesValues()` fails with crash (`signal trap`)
  - Reproduced in isolated run and baseline run
- Likely root cause:
  - `GameResult` enforces score validation using `assert(...)`
  - Test round-trip input uses `gameName = "connections"` and `score = 0`, which violates default lower-attempt score validation branch
  - This causes a debug assertion trap instead of graceful rejection
- Risk:
  - Any malformed or legacy Firestore record could crash debug builds during import paths and mask real sync issues.
- Recommendation:
  - In `GameResult(fromFirestore:)`, validate and reject invalid payloads safely (return `nil`) before invoking an asserting initializer, or use a non-asserting validation path for decoded remote data.

## 2) Notification reminder content regressions

- Severity: High
- Area: Notifications / user-visible reminder text
- Evidence:
  - 4 failing tests in `NotificationContentTests` (isolated + baseline)
  - Failing lines in test file:
    - single-game body contains game name
    - two/three/more-than-three game name/body expectations
- Likely root cause:
  - `NotificationScheduler.buildStreakReminderContent(games:)` uses `game.name` (slug/lowercase internal name), while tests and expected UX assume display names (e.g. `Wordle`, `Nerdle`)
- Risk:
  - User-facing reminders degrade readability and may violate expected copy format.
- Recommendation:
  - Build notification strings using `displayName` consistently (or align tests/spec if lowercase is intentional).

## 3) Analytics weekly completion-rate mismatch

- Severity: Medium
- Area: Analytics computations
- Evidence:
  - `AnalyticsComputerTests/test_computeWeeklySummaries_completionRate_calculatesCorrectly()` failed:
    - expected `0.666...`
    - actual `1.0`
- Likely root cause:
  - Date grouping/week-window behavior likely excludes one incomplete result in the test data setup (`daysAgo(3)` may cross week boundary depending on locale/calendar at runtime)
- Risk:
  - Weekly completion metrics can be misleading near week boundaries and vary by execution date/locale.
- Recommendation:
  - Make test deterministic by pinning dates to known ISO week and calendar.
  - Re-verify `computeWeeklySummaries` against explicit week boundary fixtures.

## 4) UI smoke coverage improved and is stable, but still not full-journey

- Severity: Medium
- Area: Test infrastructure
- Evidence:
  - After adding `StreakSyncUITests` into `StreakSync.xctestplan`, UI tests run successfully.
  - Initial 3-pass run: `3/3` tests each run (template-level coverage).
  - Expanded smoke suite added for tabs/content/rapid switching.
  - Expanded 3-pass run: `6/6` tests each run, zero failures.
- Risk:
  - Critical user journeys like share-import, friend requests, and notification deep-link actions remain untested in automation.
- Recommendation:
  - Keep `StreakSyncUITests` in test plan.
  - Continue from smoke to scenario-driven UI flows with deterministic fixtures (import/social/settings action assertions).

## 5) Friends management entry path instability in phase-2 shakedown (resolved)

- Severity: Medium
- Area: Social / Friends UX
- Evidence (pre-fix):
  - Phase-2 UI suite rerun 3 times:
    - `Shakedown_UITests_Phase2_Run1.xcresult` -> `total=10 failed=2`
    - `Shakedown_UITests_Phase2_Run2.xcresult` -> `total=10 failed=2`
    - `Shakedown_UITests_Phase2_Run3.xcresult` -> `total=10 failed=2`
  - Deterministic failing cases:
    - `StreakSyncUITests/testFriendsManageSheetOpensAndCloses()`
    - `StreakSyncUITests/testCrossFeatureNavigationStress()` (same manage-friends step)
- Root cause (confirmed):
  - Top-aligned error banner overlay in `FriendsView` could overlap header controls in degraded states and interfere with taps on the manage action.
- Fix:
  - Lowered error banner placement below header interaction zone and kept header above with explicit stacking order.
  - Kept stable accessibility targeting for the manage action control.
- Verification (post-fix):
  - `FriendsRootCause_OnlyManage_PostCompileFix.xcresult` -> PASS
  - `FriendsRootCause_Cross_PostCompileFix.xcresult` -> PASS
  - `FriendsRootCause_UIFull_Cleaned.xcresult` -> PASS (`total=10 failed=0`)
- Residual risk:
  - Banner overlap may still need visual spot-checks on unusual dynamic type sizes/localizations.

## 6) Startup lifecycle stress did not break under rapid relaunch

- Severity: Informational
- Area: Startup orchestration
- Evidence:
  - 20 launch/terminate cycles on simulator, `TOTAL_FAILS=0`
- Interpretation:
  - No immediate crash-loop or launch deadlock surfaced under basic lifecycle churn.
- Remaining risk:
  - This does not cover network/auth/sync races during startup; those require orchestrated dependency fault injection.

## 7) Firestore unauthenticated boundary checks are enforcing as expected

- Severity: Informational (positive control)
- Area: Firestore rules
- Evidence:
  - Emulator probes returned `403 PERMISSION_DENIED` for unauth read/write on:
    - `/users/user1`
    - `/users/user1/gameResults/result1`
    - `/scores/score1`
- Interpretation:
  - Baseline no-auth access controls are active for these routes.
- Remaining risk:
  - Real-device/system-level abuse scenarios still benefit from periodic emulator regression runs, but authenticated friend/scores edge cases now have dedicated rules-unit coverage.

## 8) Authenticated Firestore rules-unit coverage added

- Severity: Informational (risk reduction)
- Area: Firestore rules hardening
- Evidence:
  - Added dedicated harness under `firestore-rules-tests/` using `@firebase/rules-unit-testing`.
  - Executed via emulator:
    - `firebase emulators:exec --only firestore "npm --prefix firestore-rules-tests test"`
  - Result: `9/9` authenticated friend/scores rule cases passed.
- Coverage added:
  - User profile read allowed for friend, denied for non-friend.
  - Score read limited to `allowedReaders`.
  - Score create denied when `allowedReaders` omits current user.
  - Score create denied for malformed optional field type (`maxAttempts` non-int).
  - Friendship accept allowed only for recipient.
  - Friendship accept denied for sender.
  - Friendship create denied if initial status is not `pending`.
  - Friendship update denied when immutable IDs are changed.
- Recommendation:
  - Keep this harness in CI or at least pre-release security checks to guard against rules regressions.

## Shakedown Coverage vs Plan

- Completed:
  - Baseline observability + automated failures captured
  - Startup churn stress (simulator)
  - Sync conflict suite execution (`SyncMergeTests`)
  - Rules abuse checks (unauth probes)
  - Authenticated Firestore rules unit coverage for friend/scores edge cases
  - Notification/analytics targeted break tests
  - Documentation artifacts
- Partially blocked:
  - Real-device auth turbulence (Apple/Google interactive linking)
  - Timezone/DST notification delivery validation
  - Full UI-flow chaos automation across auth/import/social flows (deeper UI checks now present; friends manage entry issue fixed)

## Immediate Fix Queue (Suggested Order)

1. Prevent conversion assertion crash for remote payload handling.
2. Fix notification reminder copy source (`displayName` vs slug).
3. Stabilize weekly summary test fixture around explicit week boundaries.
4. Extend UI smoke into action-heavy flows (import/share, social interactions, settings toggles with assertions).
5. Continue extending automated UI chaos scenarios and keep rules suite in regular regression cadence.

## Regression Tests To Add/Strengthen

- Sync conversion:
  - Invalid remote payload should return `nil`, not trap.
  - Legacy `lastModified` missing path should remain safe.
- Notifications:
  - Content should use display labels for 1, 2, 3, >3 game paths.
- Analytics:
  - Fixed-date weekly buckets across locale/week-start variants.
- Rules:
  - Authenticated non-friend reads denied; friend reads allowed.
  - Score create/update rejects malformed `allowedReaders` and invalid optional field types.
- Infrastructure:
  - CI gate that fails if UI target is absent from test plan.

## Fix Batch 1 Verification (2026-02-17)

- Completed and verified:
  - Notification content regressions: fixed (`NotificationContentTests` passing in targeted run)
  - Sync conversion crash path: fixed for targeted regression (`SyncServiceConversionTests` passing in targeted run)
  - Analytics completion-rate test instability: fixed (`AnalyticsComputerTests` targeted case passing)
- Verification artifact:
  - `FixBatch1_Targeted_Final.xcresult` -> `17/17` targeted tests passed
- Follow-up completed:
  - Friends management sheet presentation path root cause fixed (overlay tap interference in header zone).
  - Full UI rerun now green:
    - `FriendsRootCause_UIFull_Cleaned.xcresult` -> `total=10 failed=0`
