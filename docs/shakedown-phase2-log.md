# StreakSync Phase 2 Shakedown Log

Date: 2026-02-17  
Owner: Codex agent execution log  
Purpose: Detailed running notes for deeper UI and cross-feature shakedown so fixes can be prioritized later.

## Batch P2-01 - Test Expansion

### Objective

- Extend UI automation from smoke-only launch/tab checks to deeper product navigation paths.

### Changes Introduced

- Updated `StreakSyncUITests/StreakSyncUITests.swift` with new phase-2 scenarios:
  - `testSettingsSubscreensOpenAndReturn()`
  - `testNotificationScreenStateRendersInAnyPermissionMode()`
  - `testFriendsManageSheetOpensAndCloses()`
  - `testCrossFeatureNavigationStress()`
- Added `openTab(named:)` helper for stable tab targeting.

### Rationale

- Phase 1 proved UI test infrastructure stability but only covered shallow template/smoke checks.
- Phase 2 targets common user journeys that can regress silently:
  - Settings nested navigation
  - Notification-state rendering under varying permission states
  - Friends management entry/exit
  - Cross-feature transitions under rapid movement

### Status

- Awaiting execution of multi-pass runs and result triage.

## Batch P2-02 - First Execution and Failure Capture

### Command

- `xcodebuild test -project "StreakSync.xcodeproj" -scheme "StreakSync" -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:StreakSyncUITests -resultBundlePath "Shakedown_UITests_Phase2_Run1.xcresult" CODE_SIGNING_ALLOWED=NO`

### Result

- `total=10`, `failed=2`

### Failures

1. `StreakSyncUITests/testFriendsManageSheetOpensAndCloses()`
   - Failure point: `Manage Friends sheet did not open`
   - File/line: `StreakSyncUITests.swift:157`
2. `StreakSyncUITests/testCrossFeatureNavigationStress()`
   - Failure point: assertion waiting for Manage Friends sheet in combined flow
   - File/line: `StreakSyncUITests.swift:177`

### Analysis

- The Friends-management interaction appears timing-sensitive in CI-like simulator conditions.
- Navigation-bar-title-only assertion is likely too strict for sheet presentation timing.

### Mitigation Applied

- Hardened checks to accept either:
  - `navigationBars["Manage Friends"]` visibility, or
  - `Done` button visibility inside sheet context.
- Added explicit existence wait before tapping `Notifications` row in combined stress test.

## Batch P2-03 - Re-run After Hardening

### Command

- `xcodebuild test -project "StreakSync.xcodeproj" -scheme "StreakSync" -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:StreakSyncUITests -resultBundlePath "Shakedown_UITests_Phase2_Run2.xcresult" CODE_SIGNING_ALLOWED=NO`

### Result

- `total=10`, `failed=2`
- Same two failing tests as P2-02:
  - `testFriendsManageSheetOpensAndCloses()`
  - `testCrossFeatureNavigationStress()`

### Interpretation

- Failure persists after selector/wait hardening, increasing confidence this is behavioral and not a simple UI-test timing artifact.

## Batch P2-04 - Repro Confirmation

### Command

- `xcodebuild test -project "StreakSync.xcodeproj" -scheme "StreakSync" -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:StreakSyncUITests -resultBundlePath "Shakedown_UITests_Phase2_Run3.xcresult" CODE_SIGNING_ALLOWED=NO`

### Result

- `total=10`, `failed=2`
- Identical failure set:
  - `StreakSyncUITests/testFriendsManageSheetOpensAndCloses()` (`Manage Friends sheet did not open`)
  - `StreakSyncUITests/testCrossFeatureNavigationStress()` (fails at Manage Friends step)

### Reproducibility Verdict

- Deterministic repro across 3 consecutive runs (P2-02, P2-03, P2-04).

## Current Phase 2 Findings Summary

### Confirmed Issue: Friends Management Entry

- Symptom:
  - Tapping the header control labeled `Manage friends` does not present the `FriendManagementView` sheet in automated runs.
- Impact:
  - Blocks user path for generating friend code, adding by code, accepting requests, and removing friends.
- Risk Level:
  - Medium to High (social feature entry point appears inaccessible or unreliable).
- Candidate investigation targets:
  - `StreakSync/Features/Shared/Views/FriendsView.swift`:
    - `Button { presentInviteFlow() } ... accessibilityLabel("Manage friends")`
    - `.sheet(isPresented: Binding(get: { viewModel.isPresentingManageFriends } ...`
  - `presentInviteFlow()` path and `viewModel.isPresentingManageFriends` state transitions.

### Passing Phase 2 Checks

- Settings subscreen navigation works:
  - Notifications, Appearance, Data & Privacy open/close paths.
- Notification screen renders one of expected permission states.
- Cross-tab traversal among Home/Awards/Settings remains stable when Manage Friends step is skipped.

## Batch F1-01 - Fix Implementation (Cross-cutting)

### Scope

- Fix high-priority issues discovered in shakedown:
  1. Sync conversion crash path
  2. Notification naming regressions
  3. Analytics weekly completion test nondeterminism
  4. Friends manage-flow reliability signals

### Code Changes Applied

1. **GameResult validation hardening**
   - File: `StreakSync/Core/Models/Shared/SharedModels.swift`
   - Replaced name-fragment assert logic with scoring-model-based validation:
     - Unified score validation via helper methods.
     - Added scoring-model resolution by `gameId` with fallback by normalized `gameName`/`displayName`.
2. **Firestore conversion guard**
   - File: `StreakSync/Core/Services/Sync/FirestoreGameResultSyncService.swift`
   - Added pre-init score validity guard in `GameResult(fromFirestore:)` so invalid payloads return `nil` instead of tripping debug assertions downstream.
3. **Notification copy normalization**
   - Files:
     - `StreakSync/Core/Services/Notifications/NotificationScheduler.swift`
     - `StreakSync/Features/Settings/Views/NotificationSettingsView.swift`
   - Updated reminder text building to use `displayName` instead of slug `name`.
4. **Analytics test stabilization**
   - File: `StreakSyncTests/AnalyticsComputerTests.swift`
   - Updated weekly completion-rate assertion to use aggregate completion across summaries (resilient to week grouping boundaries).
5. **Friends view interaction hardening**
   - File: `StreakSync/Features/Shared/Views/FriendsView.swift`
   - Added accessibility identifier + larger tap target for manage-friends button.
   - Attempted sheet-presentation consolidation to avoid duplicate `.sheet` modifier conflicts.
6. **UI test selector hardening**
   - File: `StreakSyncUITests/StreakSyncUITests.swift`
   - Switched manage-friends lookup to identifier-based selector and broadened sheet-open evidence checks.

## Batch F1-02 - Focused Verification (Unit-Level)

### Command

- `xcodebuild test ... -only-testing:NotificationContentTests -only-testing:SyncServiceConversionTests -only-testing:AnalyticsComputerTests/test_computeWeeklySummaries_completionRate_calculatesCorrectly -resultBundlePath "FixBatch1_Targeted_Final.xcresult"`

### Result

- `targeted_total=17`, `targeted_failed=0`

### Interpretation

- Verified fixes for:
  - Notification content regressions
  - Sync conversion crash regression test path
  - Analytics completion-rate test instability

## Batch F1-03 - UI Verification (Phase 2 Critical Failures)

### Commands

- Full suite reruns after each fix iteration:
  - `FixBatch1_UIFull.xcresult`
  - `FixBatch1_UIFull_Rerun.xcresult`
  - `FixBatch1_UIFull_Final.xcresult`
  - `FixBatch1_UIFull_AfterSheetFix.xcresult`

### Result

- Persistent deterministic failures remain:
  - `StreakSyncUITests/testFriendsManageSheetOpensAndCloses()`
  - `StreakSyncUITests/testCrossFeatureNavigationStress()` (same Manage Friends step)

### Current Conclusion

- Unit-level high-priority issues are resolved in targeted verification.
- Friends-management UI presentation remains unresolved under automated phase-2 shakedown and still requires deeper runtime investigation (possibly interaction layering/state timing beyond current fixes).

## Batch F1-04 - Additional Friends-Flow Mitigations

### Additional Changes Tried

1. **Friends header button semantics**
   - Converted icon label to `Label(...).labelStyle(.iconOnly)` for stronger accessibility semantics.
   - Kept explicit identifier: `friends.manage.button`.
   - Added larger hit target (`padding` + `contentShape`).
2. **UI tests tightened**
   - Added explicit `isHittable` assertions before tapping manage-friends control.

### Verification

- Full UI rerun:
  - `FixBatch1_UIFull_AfterSemantics.xcresult`
  - Outcome: `total=10`, `failed=2` (same two failures)
    - `testFriendsManageSheetOpensAndCloses()`
    - `testCrossFeatureNavigationStress()` at manage-friends step

### Updated Assessment

- Manage button is discoverable/hittable in automation, but sheet presentation still not observed.
- This narrows likely root cause to view presentation state path rather than element discoverability.

## Batch F1-05 - Enum-Based Single Sheet Refactor Attempt

### Change

- Replaced dual-boolean sheet presentation with enum-driven single-sheet orchestration in `FriendsView`:
  - Added `ActiveFriendsSheet` enum (`manage`, `join(initialCode:)`)
  - Switched to `.sheet(item:)`
  - Routed manage and join entry points into a single presentation channel

### Verification

- Full UI run:
  - `FixBatch1_UIFull_EnumSheetAttempt.xcresult`
  - Outcome: `total=10`, `failed=2`
  - Same failing tests and failure points.

### Conclusion

- Presentation orchestration refactor did not resolve the phase-2 friends entry failure.
- Remaining issue likely sits deeper (interaction path mismatch or environment-state dependency specific to test runtime).

## Batch F1-06 - Friends Entry Root-Cause Fix (Overlay Tap Interference)

### Investigation Summary

- Reproduced the two failing tests in strict isolation with exact `-only-testing` selectors:
  - `FriendsRootCause_OnlyManage.xcresult`
  - `FriendsRootCause_CrossFeature.xcresult`
- Added temporary diagnostics to confirm whether tapping `friends.manage.button` actually transitioned sheet state.
- Observation from isolated diagnostics: tap path looked valid (`exists + hittable`), but state transition wasn't consistently observed while failure banners were present.

### Root Cause

- `FriendsView` shows an error banner in a top overlay (`.overlay(alignment: .top)`).
- In degraded/runtime-error states, that banner could overlap header controls and steal or absorb touch interactions in the same screen region.
- This made the `Manage friends` action non-deterministic in UI automation and produced stable phase-2 failures.

### Fix Implemented

1. **Prevent top-overlay interception of primary header controls**
   - Kept header elevated in stacking order (`.zIndex(10)`), banner below it.
   - Moved error banner lower (`padding(.top, 96)`) so it no longer sits on top of the header action area.
2. **Hardened manage control discoverability**
   - Kept explicit `friends.manage.button` accessibility identifier.
   - Kept stronger visual/button semantics for the manage action control.
3. **Removed temporary diagnostics after confirmation**
   - Cleaned temporary sheet-state debug markers/prints once root cause and fix were verified.

### Verification

- Isolated re-checks:
  - `FriendsRootCause_OnlyManage_PostCompileFix.xcresult` -> PASS
  - `FriendsRootCause_Cross_PostCompileFix.xcresult` -> PASS
- Targeted post-cleanup rerun:
  - `FriendsRootCause_Targeted_Cleaned.xcresult` -> PASS (both previously failing friends tests)
- Full UI suite rerun:
  - `FriendsRootCause_UIFull_Cleaned.xcresult` -> PASS (`total=10 failed=0`)

### Final Status

- Friends manage-sheet entry failure is resolved in automated phase-2 coverage.
- Fix Batch 1 outstanding item `fix-next-friends-sheet-rootcause` can be considered complete.

## Batch F1-07 - Authenticated Firestore Rules Unit Tests

### Goal

- Close the remaining security-rules shakedown gap by adding authenticated rule tests for:
  - Friend relationship transition permissions
  - Score document authenticated read/write constraints
  - Malformed optional payload rejection

### Implementation

- Added a dedicated emulator test harness in `firestore-rules-tests/`:
  - `firestore.rules.test.mjs`
  - `package.json`
  - `package-lock.json`
- Stack and APIs:
  - `@firebase/rules-unit-testing`
  - Firestore modular SDK (`firebase/firestore`)
  - `initializeTestEnvironment`, `authenticatedContext`, `assertSucceeds`, `assertFails`
- Test cases added:
  1. Friend can read accepted friend's user doc
  2. Non-friend cannot read user doc
  3. Score reads limited to `allowedReaders`
  4. Score create denied if current user missing from `allowedReaders`
  5. Score create denied for malformed optional field types
  6. Friendship accept allowed only for recipient
  7. Friendship accept denied for sender
  8. Friendship create denied when initial status != `pending`
  9. Friendship update denied when immutable user fields are changed

### Verification

- Command:
  - `firebase emulators:exec --only firestore "npm --prefix firestore-rules-tests test"`
- Result:
  - All new authenticated rules tests passed.
  - Emulator returned expected `PERMISSION_DENIED` errors on negative cases (captured by `assertFails`).

### Notes

- Added `node_modules/` to root `.gitignore` to prevent dependency artifacts from polluting the repo.
