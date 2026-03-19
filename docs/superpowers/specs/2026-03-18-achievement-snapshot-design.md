# Achievement Checker O(n²) → O(n) Optimization

## Problem

`checkAllAchievements` has O(n²) complexity. Three call sites loop over every result (n iterations), calling `checker.checkAllAchievements()` each time. Inside, 9 checkers each independently scan `allResults` (another n). With `maxResults = 500`, this produces up to 250,000 iterations on day change.

Most checkers ignore the `for result:` parameter entirely — they compute aggregate metrics from `allResults`. The outer loop is waste.

## Solution

Pre-compute all metrics in a single O(n) pass into an `AchievementSnapshot` struct. Checkers become O(1) lookups against snapshot fields. The outer loops at all three call sites are eliminated.

## `AchievementSnapshot`

```swift
struct AchievementSnapshot {
    let totalGamesPlayed: Int
    let successCount: Int
    let uniqueGameIds: Set<UUID>
    let uniqueDayCount: Int
    let consecutiveDaysPlayed: Int
    let earlyBirdCount: Int
    let nightOwlCount: Int
    let minimalAttemptWins: Int
    let comebackCount: Int

    static func build(from results: [GameResult], games: [Game], referenceDate: Date = Date()) -> AchievementSnapshot
}
```

Lives in `TieredAchievementChecker.swift` alongside the checker.

### `build()` implementation

Build a `[UUID: Game]` lookup dictionary from `games` for O(1) game access.

Single pass over `results`:
1. Increment `totalGamesPlayed` (count)
2. If `result.isSuccess`, increment `successCount`
3. Insert `result.gameId` into `uniqueGameIds` set
4. Compute `startOfDay` for the result date, insert into a `Set<Date>` for unique days
5. Insert the day into a `[UUID: Set<Date>]` dictionary (grouped by game, deduplicated per game via Set) for comeback detection
6. Extract hour: if 5..<9 increment `earlyBirdCount`, if 0..<5 increment `nightOwlCount`
7. Check minimal-attempt win criteria (using game lookup dictionary), increment `minimalAttemptWins`

After the pass:
- Derive `uniqueDayCount` from the unique days set size
- Derive `consecutiveDaysPlayed` from the sorted unique days set. Same algorithm as current `calculateConsecutiveDaysPlayed` including the "check against today" step — uses `referenceDate` parameter (defaults to `Date()`) so tests can pin the date. Using `Set<Date>` input (vs current raw results array) also fixes the minor inefficiency of duplicate dates in the sorted array.
- Derive `comebackCount` from the per-game day dictionary (same gap-detection logic as current `checkComebackChampion`, operating on the pre-deduplicated `Set<Date>` per game)

Returns all-zero/empty snapshot for empty `results` input.

### Minimal attempts helper

`minimalAttempts(for:games:defaultMax:)` moves from `TieredAchievementChecker` into `AchievementSnapshot.build()` as a private helper, since it's only needed during snapshot construction.

## Checker API change

### Before

```swift
func checkAllAchievements(
    for result: GameResult,
    allResults: [GameResult],
    streaks: [GameStreak],
    games: [Game],
    currentAchievements: inout [TieredAchievement]
) -> [AchievementUnlock]
```

### After

```swift
func checkAllAchievements(
    snapshot: AchievementSnapshot,
    streaks: [GameStreak],
    currentAchievements: inout [TieredAchievement]
) -> [AchievementUnlock]
```

- `for result` removed — no individual result needed
- `allResults` replaced by `snapshot`
- `games` removed — consumed by snapshot builder

### Private checker changes

Each private checker method changes from scanning arrays to reading snapshot fields:

| Checker | Before | After |
|---------|--------|-------|
| `checkStreakMaster` | Uses `result` + `streaks` | Uses `streaks` only (unchanged, but `result` param removed — uses max streak across all streaks) |
| `checkGameCollector` | `allResults.count` | `snapshot.totalGamesPlayed` |
| `checkPerfectionist` | `allResults.filter { $0.isSuccess }.count` | `snapshot.successCount` |
| `checkDailyDevotee` | `calculateConsecutiveDaysPlayed(results:)` | `snapshot.consecutiveDaysPlayed` |
| `checkVarietyPlayer` | `Set(allResults.map(\.gameId)).count` | `snapshot.uniqueGameIds.count` |
| `checkSpeedDemon` | Filter + count loop over `allResults` | `snapshot.minimalAttemptWins` |
| `checkTimeBasedAchievements` | Two filter passes over `allResults` | `snapshot.earlyBirdCount`, `snapshot.nightOwlCount` |
| `checkComebackChampion` | Group by game, sort, gap detection | `snapshot.comebackCount` |
| `checkMarathonRunner` | `Set(allResults.map { ... }).count` | `snapshot.uniqueDayCount` |

### `checkStreakMaster` adjustment (behavioral fix)

Currently takes a `result` parameter to find the matching streak by `result.gameId`. This means the progress value depends on which result happens to be processed last — in the outer loop, the last result's game streak wins, producing non-deterministic behavior. The new approach evaluates the best streak across all streaks: `streaks.max(by:)` using `max(currentStreak, maxStreak)`. This is a **behavioral change** (not just a refactor) that fixes the non-determinism and matches the achievement's stated intent ("maintain consecutive day streaks").

### `checkComebackChampion` and `checkVarietyPlayer` monotonic guards

Both checkers currently apply `max(currentValue, newValue)` to prevent progress regression on partial histories. These guards stay in the checker methods — the snapshot provides the raw computed count, and the checker applies the monotonic floor.

The `checkVarietyPlayer` checker's internal `max()` is removed since the AppState call sites already handle the `uniqueGamesEver` union + monotonic logic after the checker returns. Keeping both would be redundant.

### Dead parameter cleanup

`checkComebackChampion` currently accepts a `streaks` parameter it never reads — this is removed along with all other dead parameters.

## Call site changes

### `AppState.checkAllAchievements()` (day change)

```swift
// Before: O(n²)
for result in recentResults {
    _ = checker.checkAllAchievements(for: result, allResults: recentResults, ...)
}

// After: O(n)
let snapshot = AchievementSnapshot.build(from: recentResults, games: games)
_ = checker.checkAllAchievements(snapshot: snapshot, streaks: streaks, currentAchievements: &current)
```

### `checkTieredAchievements(for:)` (single result add)

```swift
// Before: takes GameResult, passes allResults anyway
func checkTieredAchievements(for result: GameResult) {
    let unlocks = checker.checkAllAchievements(for: result, allResults: recentResults, ...)
}

// After: no result parameter needed
func checkTieredAchievements() {
    let snapshot = AchievementSnapshot.build(from: recentResults, games: games)
    let unlocks = checker.checkAllAchievements(snapshot: snapshot, streaks: streaks, ...)
}
```

The caller `checkAchievements(for:)` also drops the `for result:` parameter → `checkAchievements()`. Its call site in `AppState+ResultAddition` updates accordingly.

### `recalculateAllTieredAchievementProgress()` (startup/delete)

```swift
// Before: O(n²)
for r in orderedResults {
    _ = checker.checkAllAchievements(for: r, allResults: recentResults, ...)
}

// After: O(n)
let snapshot = AchievementSnapshot.build(from: recentResults, games: games)
_ = checker.checkAllAchievements(snapshot: snapshot, streaks: streaks, currentAchievements: &current)
```

## Variety Player monotonic union

The `uniqueGamesEver` union logic stays in the AppState call sites (applied after the checker returns), unchanged from today. The checker sets progress to `snapshot.uniqueGameIds.count`, then AppState applies `max(progress, union(uniqueGamesEver).count)`.

## Complexity

| Path | Before | After |
|------|--------|-------|
| Day change | O(n) loop x 9 checkers x O(n) = **O(n²)** | O(n) build + 9 x O(1) = **O(n)** |
| Single result add | 9 checkers x O(n) = **O(9n)** | O(n) build + 9 x O(1) = **O(n)** |
| Startup recompute | O(n) loop x 9 x O(n) = **O(n²)** | O(n) build + 9 x O(1) = **O(n)** |

## Files changed

| File | Change |
|------|--------|
| `Features/Achievement/Components/TieredAchievementChecker.swift` | Add `AchievementSnapshot` struct with `build()`. Rewrite `checkAllAchievements` signature. Each private checker reads snapshot fields. Move `minimalAttempts()` into snapshot builder. Remove `calculateConsecutiveDaysPlayed()` (logic moves to snapshot builder). |
| `Core/State/AppState+TieredAchievements.swift` | `checkTieredAchievements()` and `recalculateAllTieredAchievementProgress()` build snapshot, call checker once, remove loops. Drop `for result:` param from `checkTieredAchievements` and `checkAchievements`. |
| `Core/State/AppState.swift` | `checkAllAchievements()` builds snapshot, calls checker once, removes `for result in` loop. |
| `Core/State/AppState+ResultAddition.swift` | Update call from `checkAchievements(for: result)` to `checkAchievements()`. |

No new files created.

## Testing

Existing achievement tests continue to work — behavioral output is identical except for `checkStreakMaster`, which is now deterministic (see behavioral fix above). `AchievementSnapshot.build()` accepts a `referenceDate` parameter for testability and can be unit tested independently with crafted `GameResult` arrays.
