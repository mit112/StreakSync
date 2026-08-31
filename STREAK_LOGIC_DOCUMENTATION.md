# Streak Logic Documentation

> **Verified against the code on 2026-08-31.** Every claim below was checked against the
> current source, and every file/line reference was read rather than carried forward. The
> previous revision (2025-12-05) was wrong in its headline claim and described three
> subsystems that no longer exist; see [What changed in this pass](#what-changed-in-this-pass)
> at the end for the list, so a reader who remembers the old text knows what to unlearn.
>
> Line numbers are accurate as of commit `3db2189`. Treat symbol names as the durable
> reference and line numbers as a hint.

## Overview

A **streak** is a per-game count of consecutive calendar days on which the user *completed*
that game. Streaks are stored as `GameStreak` values in `AppState.streaks`, one per game,
and are always derived from `AppState.recentResults` — the results are the source of truth,
the streaks are a cache.

Two functions maintain them, and understanding the split is the whole model:

| | `updateStreak(for:)` | `rebuildStreaksFromResults()` |
|---|---|---|
| Scope | One game, one new result | Every game, all results |
| Cost | O(1) | O(results) |
| Used by | `addGameResult` only | Everything else |
| Can it *lower* a streak to 0 for a missed day? | No | No |

Neither can break a streak for a day that simply passed with no play, because both only
look at results that exist. That job belongs to a third function,
`normalizeStreaksForMissedDays(referenceDate:)`, and **it must be called after every
rebuild.** This pairing is the single most important invariant in this document.

## The three functions

### 1. `updateStreak(for: GameResult)` — incremental

`Core/State/AppState+GameLogic.swift:14`

Finds the streak for `result.gameId`, delegates to `calculateUpdatedStreak`, writes the
array back via `setStreaks()`. If no streak exists for the game it logs a warning and
returns — it does not create one. **The caller is responsible for saving.**

### 2. `calculateUpdatedStreak(current:with:)` — the core rule

`Core/State/AppState+GameLogic.swift:38`. Pure: takes a streak and a result, returns a new
streak. This is the function to read if you want the rules.

```
result.completed == false  →  currentStreak = 0, streakStartDate = nil
result.completed == true:
    currentStreak == 0     →  currentStreak = 1, streakStartDate = result.date
    else, by daysBetween(lastPlayedDate, result.date):
        ==  1              →  currentStreak += 1        (consecutive day)
        <=  0              →  unchanged                 (same day OR historical backfill)
        >   1              →  currentStreak = 1         (gap; new streak starts)
    maxStreak = max(maxStreak, currentStreak)
```

Two subtleties that are easy to break and are deliberate:

- **`daysBetween <= 0`, not `== 0`.** A backfilled result older than `lastPlayedDate`
  yields a negative `daysBetween`. Without the `<=`, it fell through to the "gap" branch
  and reset a healthy streak to 1 while backdating `streakStartDate`.
- **`lastPlayedDate` never moves backwards** — it is `max(current.lastPlayedDate,
  result.date)` (line 55), so importing an old result cannot rewind the game's recency.

`daysBetween` (`Core/Services/Utilities/GameDateHelper.swift:82`) compares
`calendar.startOfDay` values, so it is a **calendar-day** difference, not elapsed hours.

### 3. `rebuildStreaksFromResults()` — full recompute

`Core/State/AppState+Import.swift:17`

Groups `recentResults` by game, sorts each group chronologically, and replays the same
rules to produce a fresh streak per game. Then `ensureStreaksForAllGames` adds empty
streaks for games with no results.

Two things it does that the incremental path does not:

- **`maxStreak` has a monotonic floor** (line 80): it is raised to the previously persisted
  `maxStreak` for that game. Without this, a user past the `maxResults` cap (500,
  `AppConstants.Storage.maxResults`) would watch their all-time best shrink as old results
  were pruned.
- `totalGamesPlayed` / `totalGamesCompleted` are recomputed as `results.count` and the
  completed count **within the retained window** — they get *no* such floor. See
  [Known caveat: totals drift](#known-caveat-totals-drift).

**Limitation, by construction:** it only sees gaps *between* results. A game last completed
five days ago still comes out of a rebuild with a non-zero `currentStreak`, because nothing
in the result set says "and then the user stopped". That is what the next function is for.

### 4. `normalizeStreaksForMissedDays(referenceDate: Date = Date())` — break expired streaks

`Core/State/AppState+Persistence.swift:132`

Builds a per-game `Set` of days that have a completed result, then for each streak with
`currentStreak > 0` walks day by day from `lastPlayedDate` up to (but not including)
`referenceDate`. The first day with no completed result means the streak is dead, and it is
reset to `currentStreak = 0, streakStartDate = nil`. `maxStreak`, the totals and
`lastPlayedDate` are preserved. Persists and invalidates the cache only if something changed.

- The helper is `hasGapInStreak(completedDays:lastPlayedDate:referenceDate:calendar:)`
  (line 188), pre-indexed so the check is O(days) rather than O(days × results).
- **Playing yesterday keeps the streak alive today.** The loop stops *before*
  `referenceDate`, so today's absence never breaks a streak — you get the whole day to play.
- **It can only lower a streak, never raise one.** Normalizing does not repair an
  under-counted streak; only a rebuild can.
- If a game has no completed results at all, it returns `false` (no break). That is
  deliberate: a streak whose supporting results were pruned by the `maxResults` cap should
  not be destroyed on the strength of evidence the app no longer has.
- `referenceDate` is injectable purely as a test seam (`NormalizeStreaksTests`).

## The invariant: rebuild is always followed by normalize

Because a rebuild cannot detect "the user stopped playing", **every call to
`rebuildStreaksFromResults()` must be followed by `normalizeStreaksForMissedDays()`.**

Production call sites, all of which honour it:

| Site | Trigger |
|---|---|
| `AppState.handleDayChange()` — `AppState.swift:155-156` | Midnight rollover |
| `AppState.refreshData()` — `AppState+Persistence.swift:427-428` | Pull-to-refresh / foreground |
| `AppState.reconcileAfterResultSetChanged()` — `AppState+Reconciliation.swift:27-28` | Any wholesale result-set change |
| `StreakSyncApp.initializeApp()` — `StreakSyncApp.swift:124-125` | After the launch Firestore sync |
| `AppContainer.handleAppBecameActive()` — `AppContainer.swift:451-452` | Foreground, if sync is stale (>300s) |
| `AppContainer` auth-change handler — `AppContainer.swift:284-285` | UID change / sign-in |
| `AppContainer.handleProviderUpgraded(...)` — `AppContainer.swift:339, 344` | Linking a second auth provider |

`GuestSessionManager.swift:136-137` pairs them too, when restoring the host session.

> `handleProviderUpgraded` rebuilt **without** normalizing until 2026-08-31 — a provider
> upgrade could leave an expired streak reading as active until the next day change or
> foreground. `NormalizeStreaksTests.testRebuildAloneLeavesAnExpiredStreakActive` now pins
> the invariant so the pairing is not mistaken for redundancy again.

## Entry points

### A game result is added

`AppState.addGameResult(_:deferReconciliation:)` — `AppState+ResultAddition.swift:20`.
Calls `updateStreak(for:)` (line 67), posts `.appGameDataUpdated` (line 84), then
asynchronously `saveStreaks()` (104), `publishWidgetSnapshot()` (126) and
`checkAndScheduleStreakReminders()` (135). Prunes to `maxResults` (line 108) once the cap
is exceeded.

Note this path does **not** normalize — it does not need to. Adding a result can only
extend or reset a streak via the rules above, and a same-day add cannot create a missed day.

### A game result is deleted

`AppState.removeGameResult(_:)` — `AppState.swift:232`. Removes the result, writes a
tombstone into `deletedResultIds` so a cold resync cannot resurrect it, retracts the
published social score, then delegates everything else to
`reconcileAfterResultSetChanged()`.

### Wholesale result-set changes

`AppState.reconcileAfterResultSetChanged()` — `AppState+Reconciliation.swift:22` — is the
single funnel for sync merges, backup imports, restores, deletes and pruning. Order is
load-bearing and documented in the source: caches and streaks first, then achievements
(which read them), then the UI notification, then the slower writes.

### Day change

`DayChangeDetector` posts `.dayDidChange`; `AppState.handleDayChange()`
(`AppState.swift:142`) rebuilds, normalizes, checks achievements, reschedules reminders and
republishes the widget snapshot. **It returns early in Guest Mode** — otherwise
`checkAllAchievements` would union host data and the reminder rewrite would use guest
at-risk games.

### App launch

`StreakSyncApp.initializeApp()` — `StreakSyncApp.swift`:

1. Local-first paint: `loadPersistedData()` then `normalizeStreaksForMissedDays()` (89-90).
2. UI is marked initialized — the user sees cached, normalized streaks before any network.
3. In the background: Firebase auth, notification categories, `syncIfNeeded()`, then
   `rebuildStreaksFromResults()` + `normalizeStreaksForMissedDays()` (124-125), then
   `checkAndScheduleStreakReminders()`.

`loadPersistedData()` (`AppState+Persistence.swift:18`) itself does **not** rebuild. It
loads, fixes legacy Connections results, normalizes, recomputes achievements and publishes
a widget snapshot. It returns early in Guest Mode or Review Mode, and debounces re-entry
within 1 second.

## Modes that suppress streak work

- **Guest Mode** (`isGuestMode`) — `handleDayChange`, `loadPersistedData` and `refreshData`
  all return early. The guest session is in-memory; `GuestSessionManager` restores and then
  rebuild+normalizes host streaks when it ends.
- **Review Mode** (`reviewModeEnabled`) — `loadPersistedData` returns early so seeded demo
  data is not overwritten.

## Notifications

Exactly **one** notification announces that streaks changed: `GameDataUpdated`, declared as
`AppConstants.Notification.gameDataUpdated` and posted as `.appGameDataUpdated`. It is
posted by `addGameResult` (`AppState+ResultAddition.swift:84`) and by
`reconcileAfterResultSetChanged` (`AppState+Reconciliation.swift:33`).

The only notification flowing the other way — an *input* that triggers streak work — is
`.dayDidChange` (`DayChangeDetector.swift:113`), observed at `AppState.swift:125`.

## `GameStreak` reference

`Core/Models/Streak/StreakModels.swift:43`. A `Codable`, `Sendable` struct with `let`
properties — updates replace the value, never mutate it.

| Property | Meaning |
|---|---|
| `currentStreak` | Consecutive days completed; 0 when broken |
| `maxStreak` | All-time best; floored at `currentStreak` in `init`, never lowered by a rebuild |
| `totalGamesPlayed` | Completed **and** failed, within the retained window after a rebuild |
| `totalGamesCompleted` | Completed only, same caveat |
| `lastPlayedDate` | Most recent play, completed or failed; never moves backwards |
| `streakStartDate` | First day of the current streak; `nil` when broken |

Computed: `completionRate` / `successRate` (identical formulas), `completionPercentage`,
`isActive` (last play was today or yesterday, per
`GameDateHelper.isGameResultActive`), `streakStatus` (`.broken` if `currentStreak == 0`,
else `.active` / `.inactive` from `isActive`).

The initializer carries `precondition`s — negative counts, `totalGamesCompleted >
totalGamesPlayed`, and an empty `gameName` all trap. `precondition` is **live in Release**,
so a bad construction crashes users, not just the test host.

### Known caveat: totals drift

`updateStreak` increments `totalGamesPlayed` / `totalGamesCompleted` without bound, while
`rebuildStreaksFromResults` recomputes them from the ≤500-result window. For a user past
the cap, any rebuild snaps both totals down. `maxStreak` is explicitly protected from this;
these two are not.

Impact is mostly bounded because the common consumers use them as a **ratio**
(`completionRate` in sorting, and the percentage on `ModernGameCard` /
`GameCompactCardView`) — numerator and denominator shrink together.

The one place the absolute number is user-visible is
`GameDetailViewModel.shareGameStats()` (`GameDetailViewModel.swift:119`), which puts
`Total Games: <totalGamesPlayed>` into the shared text. For a user past the cap that figure
under-reports after any rebuild. Recorded because it is real and undocumented, not because
it is urgent — it needs a lifetime counter of the kind `activeDaysEver` / `uniqueGamesEver`
already use, which is a product decision rather than a bug fix.

Note the Analytics figures (`OverviewStatsSection`, `MostActiveGamesSection`, …) are *not*
affected: they come from `AnalyticsComputer` over the result set directly, not from
`GameStreak`.

## Key files

| Concern | File |
|---|---|
| Model | `Core/Models/Streak/StreakModels.swift` |
| Incremental update | `Core/State/AppState+GameLogic.swift` |
| Full rebuild | `Core/State/AppState+Import.swift` |
| Normalization, load/save | `Core/State/AppState+Persistence.swift` |
| Recompute funnel | `Core/State/AppState+Reconciliation.swift` |
| Result addition | `Core/State/AppState+ResultAddition.swift` |
| Day boundaries | `Core/Services/Utilities/GameDateHelper.swift` |
| Day change detection | `Core/Services/Utilities/DayChangeDetector.swift` |
| Tests | `StreakSyncTests/NormalizeStreaksTests.swift`, `StreakLogicTests.swift` |

## What changed in this pass

Corrections to the 2025-12-05 revision, for readers who remember it:

1. **The headline claim was backwards.** It asserted in bold, in three places, that
   `normalizeStreaksForMissedDays()` is *not* called on day change, and drew the conclusion
   that "streaks remain active on a new day until actual game results show a gap or the app
   is launched". It **is** called (`AppState.swift:156`), and the conclusion did not hold.
2. **CloudKit is gone.** An entire trigger section described `UserDataSyncService` and
   `CloudKitSubscriptionManager`. Neither symbol exists anywhere in the tree; sync is
   Firestore.
3. **The "Settings — Force Rebuild" manual trigger is gone.** Neither
   `SettingsComponents.swift` nor `forceRebuildAllStreaks()` exists.
4. **Two of the three documented notifications never existed.** `GameResultAdded` and
   `RefreshGameData` have zero occurrences in the tree.
5. **The normalization helper was renamed.** `shouldBreakStreakForGame()` does not exist;
   it is `hasGapInStreak(completedDays:lastPlayedDate:referenceDate:calendar:)`.
6. **The app-launch flow was wrong.** `loadPersistedData()` does not rebuild, and the
   documented CloudKit step does not happen.
7. **`AppState+Reconciliation.swift` was entirely undocumented**, despite now being the
   funnel that deletion and every sync path go through.
8. Undocumented behaviours now covered: the `daysBetween <= 0` backfill guard, the
   `lastPlayedDate` monotonic guard, the `maxStreak` cap floor, the `referenceDate` test
   seam, Guest/Review mode suppression, `publishWidgetSnapshot()` in the day-change and
   reconcile flows, and the totals-drift caveat.
9. Every line-number reference was stale; all were re-read.
