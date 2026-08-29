# StreakSync — What's Left

**Compiled 2026-08-29, revised the same day.** Every item below was verified against the code,
not copied forward from an older document.

This supersedes the "open items" sections of `CODEBASE_AUDIT.md`, `DESIGN_AUDIT.md`,
`UI_SYSTEM_AUDIT.md`, `REDDIT_LAUNCH_AUDIT.md`, `SECURITY_AUDIT.md`,
`.superpowers/audit_2026-07-24_findings.md`, the three `*_MODULE_ANALYSIS.md` files, and the
`docs/shakedown-*.md` set. Those stay useful as findings archives; they are **not** accurate
status. A large majority of what they list as open has in fact shipped.

App is live: <https://apps.apple.com/us/app/streaksync-puzzle-tracker/id6755203446>.
Release path is Xcode Cloud — push to `main` archives and delivers to TestFlight.

---

## 1. Blocked on you — I can't do these from here

| # | Item | Why it's blocked | Effort |
|---|---|---|---|
| 1 | **Crashlytics** | Needs `FirebaseCrashlytics` added as a package product to the app target in Xcode. That's a `.pbxproj` edit, which the project rules forbid me from hand-editing. | 5 min in Xcode + ~20 lines of init code |
| 2 | **Firebase budget alert** | Google Cloud Console, project `streaksync-55ca0`. No cost guardrail exists. | 5 min |
| 3 | **App Check enforcement** | Code is fully scaffolded (`Core/Config/AppCheckSetup.swift`, `FirebaseAppCheck` already linked) but the provider factory is commented out at `App/AppDelegate.swift:22`. Needs a debug token registered in Firebase Console first, then uncomment. This is `SECURITY_AUDIT.md`'s only unresolved finding (H5). | 15 min |
| 4 | **App Store Connect API key** | Users and Access ▸ Integrations. Would let the release flow run unattended instead of via an app-specific password. | 10 min |
| 5 | **The in-Xcode SwiftLint phase is a false green** | See below — the fix is a target build-setting change. | 2 min |
| 6 | **Create the Widget Extension target** | All 22 source files are written and lint/typecheck clean; the target itself is a `.pbxproj` edit. `StreakSyncWidget/README.md` has the setup, the entitlement, and the four files to add to membership. | 10 min in Xcode |
| 7 | **Device-test + merge `finish-e2e-2026-08-28`** | Merging to `main` triggers Xcode Cloud → a real TestFlight build. Outward-facing, so it needs your explicit go-ahead. The account-switch and notification changes have never run on hardware. | — |

**Crashlytics is the one that matters.** The app has been live since May with zero production
crash visibility.

### On the SwiftLint build phase

The Run Script phase runs, but `ENABLE_USER_SCRIPT_SANDBOXING = YES` confines it. On a build
today it reports:

```
Linting Swift files in current working directory
Linting 'ShareViewController.swift' (1/2)
Linting 'ShareExtensionBrandMark.swift' (2/2)
Done linting! Found 0 violations, 0 serious in 2 files.
```

**2 files out of 213**, and a green "0 violations" — while the CLI on the same tree was reporting
14 errors. Every in-Xcode lint result since sandboxing was enabled has been meaningless. Until
that's fixed, `swiftlint` from the terminal is the only real gate. Fix is either
`ENABLE_USER_SCRIPT_SANDBOXING = NO` on the target, or passing explicit paths to `swiftlint lint`
in the script.

---

## 2. Product gaps

### 2.1 Home Screen presence — **written, blocked on the target**
Superseded. The whole extension now exists as source under `StreakSyncWidget/` (22 files) and
the app publishes a `WidgetSnapshot` to the App Group on every result, reconciliation, day
change and launch. Two widgets (a streak overview across `systemSmall`/`systemMedium` and all
three accessory families, plus a configurable single-game widget), App Intents for opening a
game and answering "what's my Wordle streak" in Siri/Shortcuts.

Nothing compiles until **you create the Widget Extension target in Xcode** — see
`StreakSyncWidget/README.md` for the setup, the one entitlement, and the exact four main-app
files to add to its membership. Verified as far as possible without a target: clean
`swiftc -typecheck` under Swift 6 with `-application-extension`, and 0 SwiftLint violations
across all 22 files. Runtime layout is unverified; the medium family's chip fit at
accessibility text sizes is the thing most likely to need adjusting on device.

Still absent and undecided: Live Activity and Control Center controls (`ActivityKit` returns
zero matches). Neither is obviously right for a once-a-day puzzle.

### 2.2 Silent blank account on cross-provider sign-in — **fixed**
The original entry understated this in two ways, both found on 2026-08-29.

First, the wipe was reachable by a **second, much more likely route**. Sign-out itself called
`clearAllData()`, so a signed-out user is anonymous with no local data; tapping "Sign in with
Google" for a never-seen Google account then took the *link* branch, permanently promoting the
throwaway anonymous UID into that Google account and stranding the real Apple history under the
old UID. `AppContainer` classified that as a benign provider upgrade and never even logged it.

Second, the sign-out sheet told users "Your personal streaks and scores stay on this device"
while `handleSignOut()` deleted exactly those. Shipped copy contradicting shipped behaviour.

Fixed by making the destruction recoverable rather than trying to predict it, since there is no
reliable detector — `fetchSignInMethods(forEmail:)` returns empty under Firebase's default email
enumeration protection and cannot tell "no such account" from "account exists":

- Sign-out no longer touches local data at all, which makes the copy true and means history
  now follows the user into a newly linked account instead of being stranded.
- A UID change archives the outgoing account's stores under its own UID
  (`PersistenceService.archiveAll(namespace:)`) instead of deleting them, and restores the
  incoming account's archive if this device has one — so signing back in with the original
  provider returns the streaks immediately, without depending on a cloud pull.
- `AppContainer.shouldWarnAboutEmptyAccountSwitch` decides after the fact from facts that are
  always available (previous session was real and had data, new one is empty after syncing, no
  shared provider) and AccountView shows an inline recovery note. Advisory only.

**Not device-tested.** This is auth and data lifecycle on a live app; it needs a real
multi-provider run on hardware before merge.

### 2.3 No product analytics
No `FirebaseAnalytics` import, no `logEvent` call anywhere. There is currently no way to know
which games get used, whether the share-discovery onboarding converts, or where people drop off.

### 2.4 Friends feature has no proactive pull
`NotificationScheduler` has no social scheduling function. Friends is entirely pull-based — you
only see activity if you go looking. A "you and 3 friends played today" nudge is the obvious
counterpart to the existing streak reminder.

### 2.5 Undecided
Aggregate/cross-game leaderboard (`DESIGN_AUDIT.md` §8 decision #4) was never decided.
Liquid Glass adoption (`glassEffect`) — zero uses; both audits agree current restraint is fine.

---

## 3. Correctness and performance

| Item | Location | Note |
|---|---|---|
| ~~Pinpoint parser fabricates a score~~ | — | **Fixed 2026-08-29**, and it was worse than described: the keycap fallback counted every `N️⃣` in a combined daily post, so Crossclimb's "Fill order" row was read as five Pinpoint guesses. Two such rows exceed `maxAttempts` and trip `GameResult`'s `.lowerGuesses` assert — a reachable Debug crash, reproduced. A malformed `(0/5)` grid crashed the same way. |
| ~~Sync push is N+1~~ | — | **Fixed 2026-08-29.** Batched into `WriteBatch` commits of ≤500, matching `FirebaseSocialService+Scores`. Failure semantics deliberately unchanged. |
| Achievements sync as one base64 blob | `FirestoreAchievementSyncService.swift` | Guarded (warns 450KB, fails 700KB) but the single-document design is unchanged, and the failure surfaces only as an internal `status` enum nothing displays. |
| No Firestore request timeout | `App/AppDelegate.swift:38` | **Correction:** `FirestoreSettings` has no timeout knob, so this is not a settings change. A timeout would have to be an app-level race around the sync's *read* phase — and it is meaningless for writes, which Firestore queues offline by design. Re-scope before attempting. |
| `TieredAchievementChecker` duplication | 8 near-identical ~25-line `check*` functions | ~150–200 lines removable via one generic helper. This shape is what produced the Completionist ordering bug fixed in this pass. |
| Streaks/achievements in UserDefaults | `PersistenceService.swift:20` | Self-acknowledged as fine at current size; only `gameResults` is file-backed. |
| `Task.sleep`-based timing | `AppContainer.handleAppBecameActive` | A 1s reset and a 5s Share-Extension monitoring window. No known user-visible bug. |
| Unlimited friendCode minting | `firestore.rules:123` | Low severity: a signed-in user can create unbounded `friendCodes` docs. App Check (item 3) is the intended mitigation. |
| Name-keyed deep link matches the slug, not the display name | `NotificationCoordinator.swift:238` | `streaksync://game?name=…` now works, but matches `game.name` (`"minicrossword"`, `"linkedinqueens"`), so `name=Mini%20Crossword` still finds nothing. Fine for internal callers; worth widening if the scheme is ever documented publicly. |

---

## 4. Testing gaps

- **7 subsystems have no test file at all**: `Core/Config`, `Core/Errors`, `Features/Analytics`,
  `Features/Dashboard`, `Features/Onboarding`, `Features/Streaks`, `Design System`. Beware the
  naming traps — `StreakLogicTests` tests `Core/State`, not `Features/Streaks`.
- **The widget extension has no tests of its own** and cannot have any until the target exists.
  `WidgetSnapshotTests` covers the shared payload and the app-side builder; the timeline
  providers and views are untested.
- **UI tests cover none of the three riskiest journeys**: share-extension import, friend-request
  accept, notification deep link. All three have caused real regressions before. The 8 existing
  UI tests are the same ones added in Feb 2026.
- **UI tests are excluded from CI** because two unit tests (`ShareExtensionIngestionTests
  .testAppGroupQueue_WriteLoadClear`, `FirstShareCelebrationTriggerTests`) run ~6–7 min each and
  dominate the job.
- **Device notification shakedown never executed.** `docs/notification-runtime-device-shakedown.md`
  is a runbook written in Feb 2026 and never run: permission-state matrix, timezone/DST changes
  mid-schedule, snooze re-arm. Needs a physical device, no code.
- **Dynamic Type coverage is thin**: 11 of ~164 files reference `@ScaledMetric` /
  `dynamicTypeSize` / `sizeCategory`.

---

## 5. Fixed in the 2026-08-29 pass

Recorded so these don't get re-flagged by the next audit.

**Correctness**
- Completionist undercounted by one whenever Variety Player reached Gold in the same cycle — the
  lifetime-union bump ran *after* `checkCompletionist`. The union is now folded into
  `AchievementSnapshot` at build time. Regression test included, verified failing against the
  old code (counted 2, expected 3).
- Tier progress bar regressed below an already-earned tier after a missed day — the bar read ~3%
  while the label beside it read "14/30". `percentageToNextTier` now applies the same floor
  `progressDescription` already did. Verified failing against the old code (0.125 vs 0.625).
- Game deep links pushed detail onto whatever tab was showing; now routed to Home.
- The name-keyed deep link (`streaksync://game?name=…`) was posted and silently dropped — the
  handler reported success while nothing happened. Now consumed.
- `NotificationDelegate` claimed the `UNUserNotificationCenter` delegate from an async `.task`,
  after `didFinishLaunching` returned. Now registered during launch, as UN requires — and because
  that opens a window where a cold-launch tap arrives before `appState`/`navigationCoordinator`
  exist, a response landing in that window is stashed and replayed by `setDependencies` instead
  of no-oping against `nil`. iOS delivers `didReceive` exactly once, so it had to be replayed.
- `uniqueGamesEver` (the monotonic lifetime game set behind Variety Player) was only ever written
  one result at a time by `addGameResult` — nothing backfilled it for cloud sync merges, backup
  imports, or restores, unlike its sibling `activeDaysEver`. On a restored device it stayed empty,
  so Variety Player only ever saw games inside the capped 500-result window. Added
  `recordUniqueGames(from:)` and called it from `reconcileAfterResultSetChanged`.
- Notification preview/test re-implemented the at-risk filter and omitted the "already played
  today" check, so it could list games the scheduler wouldn't remind about.

**Lint gate** — `swiftlint` went from **exit 2** (14 errors, 404 warnings against a 400
threshold) to **exit 0** (0 errors, 389 warnings).

**Hygiene** — 337 `logger` calls that a past bulk edit had flattened to one leading space were
re-indented (`git diff -w` empty, so provably whitespace-only). 18 files got the file header
SwiftLint requires. Dead code removed: `SectionHeaderView` (zero call sites), two unused
`SettingsViewModel` members, and a `minimalAttempts` switch whose every branch returned the
default.

**Accessibility** — VoiceOver labels on 6 icon-only buttons; 44pt hit areas on the month chevrons
and the at-risk "Play" pill; per-icon labels in `GameIconCarousel` no longer swallowed by the
container; `@ScaledMetric` on `GradientAvatar` and `CircularProgressView`; settings row icons
hidden from VoiceOver; three overlapping unlock announcements reduced to two.

**Layout** — analytics card radii and section spacing aligned to tokens; double horizontal
padding removed in `RecentActivitySection`; the empty grid cell in `StreakSummaryHero` no longer
claims layout space; `NotificationSettingsView` list style matched to its siblings.

---

## 6. Fixed in the second 2026-08-29 pass

The uncommitted layer above was split into 12 reviewable commits (whitespace, headers, lint,
achievements, notifications, deep links, accessibility, layout, dead code, docs), then:

- **Pinpoint parser** — see §3. Three regression tests, each verified failing against the old
  code; the `(0/5)` case crashed the test host outright, which is the bug reproduced.
- **Firestore push batched** into `WriteBatch` commits of ≤500.
- **Account switches are now recoverable** — see §2.2. Nine tests, verified against mutated
  implementations: dropping the decision guards makes five negative cases warn, and degrading
  `archiveAll` back to `clearAll` loses the data.
- **Widget snapshot published to the App Group** plus the full extension source — see §2.1.
- One defect introduced by the earlier uncommitted work was caught and fixed before it was
  committed: `recordActiveDays`' doc comment had been orphaned onto `recordUniqueGames`.
- `.swiftlint.yml` now covers `StreakSyncWidget`, so the CLI can't silently skip it.

Gates at the end of the pass: `build_sim` clean, `swiftlint` **exit 0** (385 violations, 0
serious, 245 files), unit suite **455 passed / 0 failed**.

**Three pre-existing Swift 6 concurrency warnings** surface in
`StreakSyncTests/FirstShareCelebrationTriggerTests.swift:32-33` (non-Sendable capture, main
actor-isolated mutation from a Sendable closure). Untouched by this pass — they only became
visible when the test target recompiled.
