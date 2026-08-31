# StreakSync — What's Left

**Compiled 2026-08-29, revised the same day.** Every item below was verified against the code,
not copied forward from an older document.

This supersedes the "open items" sections of every earlier audit ledger. Two groups:

- **In the repo**, under `docs/archive/` — `UI_SYSTEM_AUDIT.md`, `REDDIT_LAUNCH_AUDIT.md`,
  `SECURITY_AUDIT.md`, `UI_AUDIT_RESEARCH_ASKS.md`. Each carries a banner saying so.
- **Local-only, by design** — `CODEBASE_AUDIT.md`, `DESIGN_AUDIT.md`, the three
  `*_MODULE_ANALYSIS.md` files, `docs/shakedown-*.md`, and
  `.superpowers/audit_2026-07-24_findings.md`. `.gitignore` deliberately excludes these as
  internal development docs and QA artifacts. **If you cloned this repo they do not exist for
  you, and nothing below depends on them** — they are named only so a reader who does have
  them locally knows they are superseded too.

All of them stay useful as findings archives; none is accurate status. A large majority of
what they list as open has in fact shipped — five parallel agents re-derived a backlog from
them on 2026-08-29 and roughly 70% came back already fixed.

App is live: <https://apps.apple.com/us/app/streaksync-puzzle-tracker/id6755203446>.
Release path is Xcode Cloud — push to `main` archives and delivers to TestFlight.

**Status 2026-08-29 (end of the third pass):** `finish-e2e-2026-08-28` is **merged and pushed**
to `main` (`a8b695c`), 48 commits. CI is **green including UI tests** — the first time UI tests
have ever passed in CI here. Marketing version is **1.24**; 1.23 was already approved, so that
train was closed and the first two upload attempts were rejected (ITMS-90186 / ITMS-90062).
Gates: `build_sim` clean and warning-free, `swiftlint` **exit 0** (375 violations, 0 serious,
275 files), **678 tests passed / 0 failed** (660 unit + 18 UI).

**Status 2026-08-31:** a small follow-up pass on branch `overnight-2026-08-31`, not merged.
Verified `STREAK_LOGIC_DOCUMENTATION.md` end to end, fixed the one code bug that surfaced
from doing so, refreshed `CLAUDE.md`'s drifted simulator UDIDs, and retired four stale
entries below. See **§8** — including a combined-run failure that needs watching.

---

## 1. Blocked on you — I can't do these from here

| # | Item | Why it's blocked | Effort |
|---|---|---|---|
| 1 | **Crashlytics** | Needs `FirebaseCrashlytics` added as a package product to the app target in Xcode. That's a `.pbxproj` edit, which the project rules forbid me from hand-editing. | 5 min in Xcode + ~20 lines of init code |
| 2 | **Product analytics** | `FirebaseAnalytics` is not linked at all. The app target's only package products are `GoogleSignIn`, `FirebaseAuth`, `FirebaseFirestore` and `FirebaseAppCheck`, so this is the same `.pbxproj` edit as Crashlytics — not a code-only change. See §2.3. | 5 min in Xcode, then instrumentation |
| 3 | **Firebase budget alert** | Google Cloud Console, project `streaksync-55ca0`. No cost guardrail exists. | 5 min |
| 4 | **App Check enforcement** | Code is fully scaffolded (`Core/Config/AppCheckSetup.swift`, `FirebaseAppCheck` already linked) but the provider factory is commented out at `App/AppDelegate.swift:22`. Needs a debug token registered in Firebase Console first, then uncomment. This is `docs/archive/SECURITY_AUDIT.md`'s only unresolved finding (H5). | 15 min |
| 5 | **App Store Connect API key** | Users and Access ▸ Integrations. Would let the release flow run unattended instead of via an app-specific password. | 10 min |
| 6 | **The in-Xcode SwiftLint phase is a false green** | See below — the fix is a target build-setting change. | 2 min |
| 7 | **Create the Widget Extension target** | All 22 source files are written and lint/typecheck clean; the target itself is a `.pbxproj` edit. `StreakSyncWidget/README.md` has the setup, the entitlement, and the four files to add to membership. | 10 min in Xcode |
| 8 | **Device-test the merged work** | The branch itself merged on 2026-08-29 (`a8b695c`); what is still outstanding is the hardware run. Account switching, the friend nudge, notification routing, and the friend-writes offline / rules-rejection paths have never executed on a device, and a green simulator suite never exercises "no network". | — |

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

### 2.3 No product analytics — **blocked, not merely unwritten**
No `FirebaseAnalytics` import, no `logEvent` call anywhere. There is currently no way to know
which games get used, whether the share-discovery onboarding converts, or where people drop off.

**Correction (2026-08-29):** this was filed as a product gap someone could just sit down and
write. It isn't. `FirebaseAnalytics` is not a linked package product — the app target links
exactly four (`GoogleSignIn`, `FirebaseAuth`, `FirebaseFirestore`, `FirebaseAppCheck`), so the
first `import FirebaseAnalytics` will not compile. Adding the product is a `.pbxproj` edit, which
puts this in §1 alongside Crashlytics (now item 2 there). Both want the same trip into Xcode.

### 2.4 Friends feature has no proactive pull — **shipped 2026-08-29**
The body of this entry still described the gap after it was closed, which read as a
contradiction. Corrected 2026-08-31: `NotificationScheduler+Social.swift` exists and defines
`FriendActivityNudge` / `FriendActivityNudgeInput` / `FriendActivityNudgePolicy`, with a
`friendActivity` notification category registered in `NotificationScheduler.swift:110` and
handled in `NotificationDelegate.swift:158`. Covered by `SocialNotificationSchedulingTests`.

### 2.5 Undecided
Aggregate/cross-game leaderboard (`DESIGN_AUDIT.md` §8 decision #4) was never decided.
Liquid Glass adoption (`glassEffect`) — zero uses; both audits agree current restraint is fine.

---

## 3. Correctness and performance

| Item | Location | Note |
|---|---|---|
| ~~Pinpoint parser fabricates a score~~ | — | **Fixed 2026-08-29**, and it was worse than described: the keycap fallback counted every `N️⃣` in a combined daily post, so Crossclimb's "Fill order" row was read as five Pinpoint guesses. Two such rows exceed `maxAttempts` and trip `GameResult`'s `.lowerGuesses` assert — a reachable Debug crash, reproduced. A malformed `(0/5)` grid crashed the same way. |
| ~~Sync push is N+1~~ | — | **Fixed 2026-08-29.** Batched into `WriteBatch` commits of ≤500, matching `FirebaseSocialService+Scores`. Failure semantics deliberately unchanged. |
| ~~Pending-score queue duplicated *and* lost scores~~ | `PendingScoreQueue.swift` | **Fixed 2026-08-29.** Both success paths called `removeAll()`, which only holds if the committed set is the whole queue — `publishDailyScores` commits one day while the queue holds a backlog, and the flush awaits a commit during which more can be appended. Both dropped scores that were never written. The failure path had the mirror bug and doubled the queue per retry (two scores became sixty-four after five). One pure helper now serves both callers, with tests. |
| ~~Delete Account hangs forever offline~~ | `FirebaseSocialService+Friends.swift` | **Fixed 2026-08-29.** Awaited `deleteAllUserData()` first, and Firestore writes neither return nor cancel while offline, so the App Store-mandated flow sat on an unescapable spinner. Now opens with a bounded `source: .server` probe; nothing is destroyed when it fails. Narrows a certain hang to a small race, not zero. |
| ~~A network outage read as "Sync failed"~~ | `SyncFailureClassifier` | **Fixed 2026-08-29.** `.offline` was only ever set for "no authenticated user", so the built-and-tested `.offline(showingCachedScores:)` branch was unreachable in production. Now mapped from the Firestore unavailable code, matching on domain too so a permission bug can't hide behind it. |
| ~~Pips month summary always read "0 completed"~~ | `SharedModels.swift` | **Fixed 2026-08-29.** Two call sites tested `completionStatus.contains("Completed")`; no case of that property contains the substring (they are "1/3 Complete", "All Complete", "Not Started"), so both were permanently false and Pips calendar days were never tinted. Replaced with a `hasAnyCompletion` boolean — deriving behaviour from display copy was the real defect. |
| ~~At-risk section miscounted the unnamed games~~ | `AtRiskTodaySection.swift` | **Fixed 2026-08-29.** Listed three names then said "and `count - 2` more", so five at-risk games read "and 3 more". Arithmetic extracted out of the `View` body, which is why an off-by-one survived uncovered. |
| ~~16 `String(format:)` calls with no placeholder~~ | `AppError+ErrorDetails.swift` | **Fixed 2026-08-29.** Every one targeted a string with no specifier, silently discarding the content type / game / key / URL. The `.strings` copy is deliberate prose, so the fix was deleting the dead formatting, not forcing `%@` back in — no user-visible change. Translator comments still advertised `%@`, which had become a hazard; rewritten, with a test asserting no raw placeholder reaches the user. |
| `completedDifficulties` counts failed attempts | `SharedModels.swift:356` | **Open, needs a call — but the blast radius is now known (2026-08-31).** It does not filter on `GameResult.completed`, so a failed Pips attempt counts toward the completion total and lights a difficulty dot. The reason it stayed open is that fixing it changes which dots appear. What was missing is how reachable it is: the Pips parser hardcodes `completed: true` (`GameResultParser+Other.swift:255`, "If we can parse it, it was completed"), so a Pips result with `completed == false` **cannot come from a share import at all**. The only way to produce one is the manual edit path (`editGameResult` / `GameResult.replacing(completed:)`). So this is a one-line filter whose only observable effect is on results the user deliberately marked failed — which is arguably the behaviour they'd expect anyway. Your call; it is a 2-minute change either way. |
| ~~Interactive friend writes hung offline~~ | `+DeferredWrites.swift` | **Fixed 2026-08-29.** Six writes awaited a server ack that never arrives offline and cannot be cancelled. Now fired without awaiting, but keeping the completion handler — dropping it would trade the hang for a silent rules rejection. Failures reach the existing Manage Friends alert with per-operation copy and rollback. **Not hardware-verified.** |
| ~~Analytics tab was blank for new users~~ | `AnalyticsEmptyStateSection.swift` | **Fixed 2026-08-29.** Content was ten `if`s with no `else`. Now branches on `hasDataForCurrentSelection`, a property written for exactly this and never wired up. Ten dead members deleted with their tests. Covered by a UI test, since the branch lives in a SwiftUI `body`. |
| Achievements sync as one base64 blob | `FirestoreAchievementSyncService.swift` | Guarded (warns 450KB, fails 700KB) but the single-document design is unchanged, and the failure surfaces only as an internal `status` enum nothing displays. |
| ~~No Firestore request timeout~~ | `docs/firestore-timeout-rescope.md` | **Re-scoped 2026-08-29 — do not build a timeout.** Reads are already time-boxed by the SDK (`getDocuments` is a one-shot Watch listener released when `OnlineStateTracker` flips Offline at `kOnlineStateTimeout = 10s`). Writes are the opposite: the headers state the completion "will not be called while the client is offline", so every `try await setData/commit` suspends *forever* — and a Firestore write structurally cannot be cancelled, so the obvious `withThrowingTaskGroup` timeout silently does nothing. The real damage is five awaited writes behind an interactive spinner, worst of all the App Store-mandated **Delete Account** flow (`AccountView.swift:442`). See the doc for the recommended fixes, which are cheaper than a timeout. |
| ~~`TieredAchievementChecker` duplication~~ | — | **Stale entry, removed 2026-08-31.** It described "8 near-identical ~25-line `check*` functions"; the file now holds exactly two (`checkStreakMaster`, `checkCompletionist`), both deliberately kept out of the table because they are genuinely special, plus a `snapshotMetrics` table driving the rest. The dedup this row asked for was already done in the second 2026-08-29 pass. |
| Streaks/achievements in UserDefaults | `PersistenceService.swift:20` | Self-acknowledged as fine at current size; only `gameResults` is file-backed. |
| `Task.sleep`-based timing | `AppContainer.handleAppBecameActive` | A 1s reset and a 5s Share-Extension monitoring window. No known user-visible bug. |
| Unlimited friendCode minting | `firestore.rules:123` | Low severity: a signed-in user can create unbounded `friendCodes` docs. App Check (item 4) is the intended mitigation. |
| ~~Name-keyed deep link matches the slug, not the display name~~ | — | **Stale entry, removed 2026-08-31.** §7 already recorded display-name matching as shipped; this row contradicted it. `SharedModels.swift:324` matches `$0.name.lowercased() == normalizedName \|\| $0.displayName.lowercased() == normalizedName`, so `name=Mini%20Crossword` resolves. Covered by `DeepLinkNameMatchingTests` and the `testNameKeyedDeepLinkOpensGameDetail` UI test. |
| Achievement snapshot totals are not cap-protected | `TieredAchievementChecker.swift:87` | **New, found 2026-08-31.** `AchievementSnapshot` explicitly defends two of its four cumulative metrics against the 500-result cap — `uniqueGameIds` unions with `lifetimeUniqueGameIds`, and `uniqueDayCount` is `max(uniqueDays.count, lifetimeActiveDayCount)`. Its siblings `totalGamesPlayed: results.count` and `successCount` get no such floor, so **Game Collector** and **Perfectionist** progress stalls or goes backwards once a user passes the cap. Not data loss: `TieredAchievementModels.swift:259` floors the bar at the earned tier, so tiers already won are never revoked — it is the progress toward the *next* tier that regresses. The fix is the same shape as the two that already exist (persisted lifetime counters), which means a migration, so it was recorded rather than done unattended. |

---

## 4. Testing gaps

> UI tests now run in CI (18 cases). The traps that made that hard are recorded in CLAUDE.md:
> unit tests execute *inside the app* as its test host and pollute its `UserDefaults`, and a
> reset that clears too much resurrects first-run onboarding, which covers the UI with a
> permission sheet on any simulator whose authorization is still `.notDetermined`.

- ~~**7 subsystems have no test file at all**~~ — **stale, corrected 2026-08-31.** Six of the
  seven were covered by the 135 tests §7 records; this bullet was never updated to match.
  `Core/Errors` → `AppErrorLocalizationTests` / `AppErrorAnalyticsTests`; `Features/Analytics`
  → six `Analytics*Tests` files; `Features/Onboarding` → `ShareOnboardingFlagIsolationTests` /
  `ShareDiscoveryGateTests`; `Features/Streaks` → three `StreakHistory*Tests`; `Design System`
  → `DesignSystemTokenTests` / `DesignSystemColorProbe`; `Core/Config` → `ColorHexParsingTests`.
  **`Features/Dashboard` is the one that genuinely remains** — no dedicated test file; it is
  touched only incidentally by `ShareOnboardingFlagIsolationTests` and the UI suite. Beware the
  naming trap that made this hard to audit: `StreakLogicTests` tests `Core/State`, not
  `Features/Streaks`.
- **The widget extension has no tests of its own** and cannot have any until the target exists.
  `WidgetSnapshotTests` covers the shared payload and the app-side builder; the timeline
  providers and views are untested.
- ~~**UI tests cover none of the three riskiest journeys**~~ — **fixed 2026-08-29.**
  `StreakSyncUITests/CriticalJourneyUITests.swift` covers share-extension import,
  notification deep link (both that it opens the right game *and* that it routes via Home
  rather than the visible tab), and friend-request accept. All three journeys begin outside
  the app — in an extension process, in Firestore, in SpringBoard — so each test enters at
  the first point the app owns, through a `#if DEBUG` launch-argument seam
  (`App/UITestSupport.swift`). None of it exists in a Release binary.
  What is deliberately **not** covered, stated per test: the extension's own App Group write
  and the Darwin notification (two processes), the OS delivering the URL to `onOpenURL`
  (Apple's code), and the Firestore write behind accept (covered by the rules suite).
  All four were confirmed to fail with the seams disabled. The share-import one initially
  passed with them disabled — it was reading a result its own earlier run had left on the
  simulator — which is why it now takes `--uitest-reset` first.
- ~~**UI tests are excluded from CI**~~ — **fixed 2026-08-29.** The recorded reason was
  measured false (see the correction above), and the exclusion was hiding a real regression:
  `testSettingsSubscreensOpenAndReturn` and `testCrossFeatureNavigationStress` had been RED
  since the Settings subscreens became pushed details in a `NavigationStack` and dropped their
  "Done" button (`NotificationSettingsView.swift:117`, DESIGN_AUDIT §4.5). The tests still
  tapped "Done". Both now pop via the navigation bar back button, and the UI target is scoped
  into `ci.yml`. Measured: 10 UI tests, **264s serial** / 615s parallel — serial is faster
  because clone booting dominates, so `-parallel-testing-enabled NO` stays.
- **Device notification shakedown never executed.** `docs/notification-runtime-device-shakedown.md`
  is a runbook written in Feb 2026 and never run: permission-state matrix, timezone/DST changes
  mid-schedule, snooze re-arm. Needs a physical device, no code. Note it is **gitignored**
  (`docs/notification-runtime-*.md`), so it exists only on the machine it was written on — it
  is an unexecuted runbook rather than an archive, and it gates the pre-merge device test.
- **Dynamic Type coverage is thin**: 11 of ~164 files reference `@ScaledMetric` /
  `dynamicTypeSize` / `sizeCategory`.
- ~~**`STREAK_LOGIC_DOCUMENTATION.md` needs a verification pass.**~~ — **done 2026-08-31.**
  Every claim re-derived from the source and every line reference re-read; see §8.

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


---

## 7. Fixed in the third 2026-08-29 pass

Everything below is on `main`. The pattern worth noting: most of these were **not** in the
backlog — they were found by doing the backlog items.

**Found by widening CI**
- Two UI tests had been red since the Settings subscreens became pushed details and dropped
  their "Done" button (DESIGN_AUDIT §4.5). The app was right; the tests were stale. The CI
  exclusion had hidden it since February.
- A cancelled analytics load stranded the screen on a **permanent spinner** — the placeholder
  was gated on `analyticsData == nil` and the cancellation guard returned before assigning.
  Only reproduced on a slower machine.

**Found by building a test seam**
- `flushPendingScoresIfNeeded` doubled its Keychain queue on every failure, compounding per
  retry (two scores became sixty-four after five). Fixing it surfaced a worse one: **both**
  success paths called `removeAll()`, so a successful publish destroyed an uncommitted backlog
  from earlier days. One pure helper now serves both call sites.

**Found by deleting duplication**
- Variety Player's monotonic floor had **no test** — the ordering test passes with it removed,
  so nothing stopped a future reader deleting it as a redundant `max()`.

**Found by re-scoping**
- Delete Account could hang unescapably offline: it awaits `deleteAllUserData()` first, and a
  Firestore write neither returns nor cancels while offline. Now gated on a bounded
  `source: .server` probe. `docs/firestore-timeout-rescope.md` has the analysis; the verdict
  was **do not build a timeout**, and all four of its recommendations are implemented.

**Also shipped:** display-name matching for `streaksync://game?name=`, three Swift 6 concurrency
warnings cleared, 135 tests across seven previously-untested subsystems, a friend-activity
nudge, achievement sync failures surfaced honestly, interactive friend writes no longer hanging,
Analytics empty state, and three verified display bugs (Pips always reading "0 completed", the
at-risk "and N more" off-by-one, 16 `String(format:)` calls with no placeholder).

**Verification discipline:** every logic change was mutation-proven — the fix reverted, the
failing value predicted, confirmed, restored. That caught one genuinely vacuous test of mine:
the share-import UI test passed against a simulator holding data its own earlier run had left.

**Still never run on hardware.** Account switching, the friend nudge, notification routing, and
especially the friend-writes offline and rules-rejection paths. A green suite here never
exercises "no network".

---

## 8. The 2026-08-31 pass

Scope was deliberately narrow: the one remaining zero-risk backlog item (the streak-logic
doc verification), the staleness it exposed, and whatever bugs fell out of doing it. No
speculative refactors — the Dynamic Type sweep and the `TieredAchievementChecker` dedup were
considered and skipped, the first because no runnable gate proves a layout change didn't
regress, the second because it turned out to be already done (see §3).

**The doc pass paid for itself.** `STREAK_LOGIC_DOCUMENTATION.md` is now verified line by
line. It was worse than its own banner admitted: besides the known-backwards headline claim,
it documented three subsystems that no longer exist (`UserDataSyncService`,
`CloudKitSubscriptionManager`, `SettingsComponents.forceRebuildAllStreaks`), two
notifications that never existed anywhere in the tree (`GameResultAdded`, `RefreshGameData`),
and a normalization helper under the wrong name (`shouldBreakStreakForGame` — it is
`hasGapInStreak`). Every line reference was stale. The rewrite documents what is actually
there, including behaviours that had never been written down: the `daysBetween <= 0` backfill
guard, the `lastPlayedDate` monotonic guard, the `maxStreak` cap floor, Guest/Review-mode
suppression, and `AppState+Reconciliation.swift` — the funnel that deletion and every sync
path now go through, which the old doc did not mention at all.

**One real bug, found by writing the doc down.** Enumerating the `rebuild → normalize`
pairing to document it made the odd one out obvious:
`AppContainer.handleProviderUpgraded(to:displayName:)` rebuilt streaks **without**
normalizing, alone among the seven sites. Because a rebuild only inspects gaps *between*
results, linking a second auth provider could leave an expired streak reading as active until
the next day change or foreground. Fixed with the one line that matches every sibling site.

The honest limit on that fix: `handleProviderUpgraded` is `private`, needs auth mocks, and
there is no `AppContainer` test file, so **the call site itself is not covered**. What is now
covered is the invariant it depends on —
`NormalizeStreaksTests.testRebuildAloneLeavesAnExpiredStreakActive` asserts that a rebuild
alone leaves a three-day-old streak reading 3, and that normalize then takes it to 0. Verified
non-vacuous by mutation: stubbing `hasGapInStreak` to `return false` fails it (and three
sibling tests). This is the `uniqueGamesEver` lesson from §7 applied — the pairing now has a
test, so nobody deletes it as a redundant call.

**Also corrected**

- `CLAUDE.md` simulator UDIDs had drifted; **every copy-pasteable `xcodebuild` command in it
  was broken.** 8 references updated (iPhone 17 Pro is now `35FE3AEC-…`, Max `D5C61B1E-…`).
- Four stale ROADMAP entries retired against the code, not against memory: the
  `TieredAchievementChecker` dedup (already done), the name-keyed deep link (already
  shipped, and it contradicted §7 two sections above it), §2.4's body (still described the
  gap its own heading said was closed), and "7 subsystems have no test file" (six of the
  seven now have one; only `Features/Dashboard` genuinely remains).
- `completedDifficulties` is still your call, but is no longer an open question — the Pips
  parser hardcodes `completed: true`, so the only reachable trigger is a manual edit. See §3.
- One new finding recorded rather than fixed: `AchievementSnapshot` protects two of its four
  cumulative metrics from the 500-result cap and not the other two, so Game Collector and
  Perfectionist progress regresses past the cap. Needs persisted counters plus a migration,
  which is not unattended work. See §3.

### Gates

| Gate | Result |
|---|---|
| `build_sim` | **SUCCEEDED**, 0 warnings, 0 errors |
| `swiftlint` | **exit 0** — 375 violations, 0 serious, 275 files. The changed files add **zero** new violations. |
| Unit suite (`-only-testing:StreakSyncTests`) | **658 passed / 0 failed / 6 skipped**, exit 0, 66s |
| Mutation proof | New test confirmed failing against a stubbed `hasGapInStreak` |

The unit count reconciles exactly, which is worth stating because §7 above reports "660 unit"
and this pass only added one test: there are **664 `func test*` in `StreakSyncTests/`**, of
which **6 skip deliberately** — all of `PendingSaveStoreTests`, via
`XCTSkipUnless(probeSucceeded, "Keychain unavailable in this environment")`, which probes the
Keychain in `setUpWithError` and skips only where it genuinely does not work. 658 + 6 = 664.
§7's 660 does not reconcile against that and should be treated as the unreliable figure.

> **The combined unit+UI run could not be verified on this machine tonight.** It was run
> twice, both times after `simctl privacy reset all` and with `-parallel-testing-enabled NO`.
> Both failed, at the infrastructure level, on **different** tests:
>
> | Run | Failed | Reported cause |
> |---|---|---|
> | 1 | `testAppLaunchesToTabLayout`, `testCrossFeatureNavigationStress` | `Failed to establish communication with the test runner (Underlying Error: Channel disconnected)` — aborted at 580s, and the **unit suite never executed at all** |
> | 2 | `testSharedResultReachesTheDashboard` | `Simulator device failed to launch com.mitsheth.StreakSyncUITests.xctrunner` → `FBProcessExit Code=64 "The process failed to launch"`, `RequestDenied ... (SBMainWorkspace)`. 662 tests passed, including the whole unit suite. |
>
> Neither is an assertion failure — both are the runner process failing to start or stay
> connected — and a different test failed each time, which is the signature of resource
> flakiness rather than a regression. The machine was under sustained memory pressure
> throughout (~6 GB swap in use, 41–53% memory free).
>
> This pass's changes are an unlikely cause: one is an auth-provider-upgrade path no UI test
> exercises, the other is a unit test file, and the unit suite passed cleanly twice.
> **The honest status is therefore: unit suite green (658/0, twice); UI suite unverified
> here.** CI is the arbiter — it ran the UI suite green on 2026-08-29 and should be checked
> before drawing any conclusion about the UI tests' health.

