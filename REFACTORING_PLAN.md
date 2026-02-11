# StreakSync — Refactoring & Issue Plan
> Detailed analysis of flagged issues with root causes, risks, and action plans

---

## 🔴 Issue 1: Persistence Key Mismatch Bug (DATA LOSS RISK)

### What's Going Wrong
`AppState+Import.swift` defines a private `PersistenceKeys` enum with **different key strings** than the ones used everywhere else in the app:

```
PersistenceKeys.recentResults  → "recentResults"
PersistenceKeys.achievements   → "achievements"
PersistenceKeys.streaks        → "streaks"

vs.

UserDefaultsPersistenceService.Keys.gameResults   → "streaksync_game_results"
UserDefaultsPersistenceService.Keys.achievements  → "streaksync_achievements"
UserDefaultsPersistenceService.Keys.streaks       → "streaksync_streaks"
```

The `saveAllData()` method in `AppState+Import.swift` writes to the wrong keys. Data saved there will never be read back by `loadPersistedData()`.

### Why It Happened
`saveAllData()` was likely added as a quick debug/utility method and defined its own local keys instead of reusing the canonical ones. It bypasses the existing `saveGameResults()`, `saveStreaks()`, etc.

### Risk Level
**HIGH** — If `saveAllData()` is ever called as the sole save path, all data written in that session is silently orphaned. The user's data would appear to vanish on next launch.

### Action Plan
1. **Delete** the private `PersistenceKeys` enum and the `saveAllData()` method entirely.
2. If a "save everything" convenience is needed, compose it from the existing methods:
   ```swift
   func saveAllData() async {
       await saveGameResults()
       await saveStreaks()
       await saveTieredAchievements()
   }
   ```
3. Search the codebase for any call sites of `saveAllData()` and verify they now use the correct path.

### Effort: ~15 minutes

---

## 🟠 Issue 2: `addGameResult()` / `addGameResultReturningAdded()` Code Duplication

### What's Going Wrong
`AppState.swift` contains two nearly identical methods for adding game results:
- `addGameResult(_ result:)` — returns `Void`
- `addGameResultReturningAdded(_ result:)` — returns `Bool`

These two methods are **~120 lines each** and share ~95% of their logic: validation, duplicate check, cache update, streak update, achievement check, notification posting, persistence, social publishing. The only difference is the return type and that the `Void` version has some Guest Mode checks the `Bool` version lacks.

### Why It's a Problem
- **Divergence risk**: Any fix applied to one method but not the other creates subtle bugs. The `Bool` version is already missing the Guest Mode result-limit guard that the `Void` version has.
- **Maintenance burden**: Every new feature (e.g., a new notification, a new side effect) must be added to both methods.
- **Review difficulty**: Reviewers must compare two 120-line methods to verify they stay in sync.

### Root Cause
The `Bool` version was added later when a caller needed to know if the result was actually inserted (to gate haptics/UI feedback). Rather than refactoring the original, a copy was made.

### Action Plan
1. Make `addGameResult` the **single implementation** that returns `@discardableResult Bool`.
2. Move the shared logic into a single private method:
   ```swift
   @discardableResult
   func addGameResult(_ result: GameResult) -> Bool {
       // single implementation with all validation, 
       // cache updates, streak, achievements, etc.
   }
   ```
3. Delete `addGameResultReturningAdded()`.
4. Update any call sites that used `addGameResultReturningAdded()` to use `addGameResult()` — the return value is already there.
5. Ensure the Guest Mode result-limit guard is present in the unified method.

### Effort: ~30 minutes

---

## 🟠 Issue 3: `AppState.swift` Is Too Large (~800+ lines)

### What's Going Wrong
`AppState.swift` is the single largest file and contains:
- Core data properties (games, streaks, results, achievements)
- UI state (isLoading, errorMessage, selectedGame)
- Duplicate detection logic (~100 lines)
- Result addition + all side effects (~250 lines across two methods)
- Streak risk detection + smart reminders (~120 lines)
- Notification migration
- Guest Mode helpers
- Grouped results logic (Pips)
- Deletion + recompute APIs
- Cache management
- Error mapping

Despite already being split into extensions (`+GameLogic`, `+Persistence`, `+TieredAchievements`, `+Import`), the base file still does too much.

### Why It's a Problem
- **Cognitive load**: Hard to understand the full surface area of AppState.
- **Merge conflicts**: Multiple features touching the same file simultaneously.
- **Testing difficulty**: Can't test duplicate detection independently from streak updating from notification scheduling.
- **Separation of concerns violation**: UI state, business logic, persistence coordination, and notification scheduling are all interleaved.

### Action Plan (incremental, non-breaking)

| Extract To | What Moves | Lines Saved |
|-----------|-----------|-------------|
| `AppState+DuplicateDetection.swift` | `isDuplicateResult()`, `buildResultsCache()`, `gameResultsCache` property | ~90 lines |
| `AppState+Reminders.swift` | `checkAndScheduleStreakReminders()`, `getGamesAtRisk()`, `calculateSmartDefaultTime()`, `computeSmartReminderSuggestion()`, `applySmartReminderNow()`, `updateSmartRemindersIfNeeded()`, reminder-related stored properties | ~130 lines |
| `AppState+ResultAddition.swift` | Unified `addGameResult()` (after Issue 2 fix), social publishing logic | ~140 lines |
| (already exists) `AppState+GameLogic.swift` | Already has streak update logic — keep as-is | — |

After extraction, `AppState.swift` becomes a ~300-line coordinator: properties, computed props, cache management, error/loading state, and initializer.

### Effort: ~1.5 hours

---

## 🟠 Issue 4: `SharedModels.swift` Is Too Large (~1600+ lines)

### What's Going Wrong
`SharedModels.swift` contains:
- `ScoringModel` enum
- `Game` struct (with ~50 static game instances)
- `GameCategory` enum
- `CodableColor` struct
- `GameResult` struct (with game-specific `displayScore` logic for 10+ games)
- `GroupedGameResult` struct
- Date extensions, URL extensions

### Why It's a Problem
- **Static game catalog dominates the file**: ~800 lines are just static game definitions. Adding a new game means editing a 1600-line file.
- **Display logic is tangled into the model**: Each game's `displayScore` and `scoreEmoji` is a growing `if/else` chain inside `GameResult`. Adding a game means adding more branches.
- **Shared between app and extension**: The Share Extension only needs the parsing-relevant parts, not the full game catalog.

### Action Plan

| Extract To | What Moves | Lines Saved |
|-----------|-----------|-------------|
| `GameDefinitions.swift` | All `static let wordle = Game(...)` instances, `popularGames`, `allAvailableGames` | ~600 lines |
| `GameResultDisplay.swift` | All private `displayScore` computed properties (`quordleDisplayScore`, `pipsDisplayScore`, `connectionsDisplayScore`, `zipDisplayScore`, etc.) and `scoreEmoji` variants | ~250 lines |
| `CodableColor.swift` | `CodableColor` struct (already self-contained) | ~80 lines |
| `DateExtensions.swift` / `URLExtensions.swift` | Date and URL extensions | ~40 lines |

After extraction, `SharedModels.swift` becomes a clean ~600-line file with core model definitions: `ScoringModel`, `Game` (struct only, no instances), `GameCategory`, `GameResult` (core fields + validation), `GroupedGameResult`.

**Bonus**: Consider replacing the `displayScore` if/else chain with a strategy pattern or a dictionary lookup:
```swift
// Instead of 10 if/else branches in displayScore:
private static let displayStrategies: [String: (GameResult) -> String] = [
    "quordle": { $0.quordleDisplayScore },
    "pips": { $0.pipsDisplayScore },
    // ...
]
```

### Effort: ~2 hours

---

## ✅ Issue 5: ThemeManager Should Be Eliminated — COMPLETED

> **Resolution**: ThemeManager.swift was already fully unused (zero references outside itself, not even in the Xcode project file). Deleted the orphaned file on Feb 11, 2026.

### What Was Wrong
`ThemeManager` was a singleton `ObservableObject` that wrapped `StreakSyncColors` — but it always defaulted to `.light` colorScheme because it couldn't access `@Environment(\.colorScheme)` outside a view:

```swift
private var colorScheme: ColorScheme {
    return .light  // ← always light mode
}
```

This means any code path that uses `ThemeManager.shared.primaryColor` gets the **light mode color even in dark mode**.

### Current Usage (27 references across 10 files)
- `ImprovedDashboardView.swift` — creates ThemeManager
- `GameDetailView.swift` — accesses colors through ThemeManager
- `StreakHistoryView.swift`, `AllStreaksView.swift` — same
- `GameResultDetailView.swift`, `AnimatedGameCard.swift`, `AddCustomGameView.swift`
- `AppContainer.swift` — creates `ThemeManager.shared`
- `ColorTheme.swift` — comments reference it

### Why It's a Problem
- **Silent dark mode bug**: Colors from ThemeManager are always light-mode variants.
- **Misleading abstraction**: Developers might reach for ThemeManager thinking it's the right approach.
- **Unnecessary indirection**: Views already have `@Environment(\.colorScheme)` — they should call `StreakSyncColors.primary(for: colorScheme)` directly.

### Action Plan
1. **For each of the ~10 files that reference ThemeManager**:
   - Remove the `@EnvironmentObject var themeManager: ThemeManager` or `ThemeManager.shared` reference
   - Add `@Environment(\.colorScheme) private var colorScheme` if not already present
   - Replace `themeManager.primaryColor` → `StreakSyncColors.primary(for: colorScheme)`
   - Replace `themeManager.cardBackground` → `StreakSyncColors.cardBackground(for: colorScheme)`
   - (and so on for each property)
2. **Remove** `ThemeManager.swift` entirely.
3. **Remove** `themeManager` from `AppContainer`.
4. **Remove** any ThemeManager mentions from `ColorTheme.swift`.

### Migration table

| ThemeManager Property | StreakSyncColors Replacement |
|----------------------|----------------------------|
| `primaryColor` | `StreakSyncColors.primary(for: colorScheme)` |
| `secondaryColor` | `StreakSyncColors.secondary(for: colorScheme)` |
| `tertiaryColor` | `StreakSyncColors.tertiary(for: colorScheme)` |
| `primaryBackground` | `StreakSyncColors.background(for: colorScheme)` |
| `cardBackground` | `StreakSyncColors.cardBackground(for: colorScheme)` |
| `secondaryBackground` | `StreakSyncColors.secondaryBackground(for: colorScheme)` |
| `accentGradient` | `StreakSyncColors.accentGradient(for: colorScheme)` |
| `successColor` | `StreakSyncColors.success(for: colorScheme)` |
| `warningColor` | `StreakSyncColors.warning(for: colorScheme)` |
| `errorColor` | `StreakSyncColors.error(for: colorScheme)` |
| `gameColor(for:)` | `StreakSyncColors.gameColor(for: category, colorScheme: colorScheme)` |

### Effort: ~1 hour (mechanical replacement across 10 files)

---

## 🟡 Issue 6: MainTabView iOS 26 / Standard Tab Duplication

### What's Going Wrong
`MainTabView.swift` has three nearly identical blocks:
1. `iOS26TabView` — the TabView body for iOS 26+
2. `standardTabView` — the TabView body for pre-iOS 26
3. `destinationView(for:)` — standard destination resolver
4. `ios26DestinationView(for:namespace:)` — iOS 26 destination resolver with zoom transitions

The tab definitions (Home, Awards, Friends, Settings with NavigationStacks and `.tabItem` modifiers) are **copy-pasted** between the two TabView variants. The destination resolvers differ only in that the iOS 26 version adds `.navigationTransition(.zoom(...))`.

### Why It's a Problem
- Adding a new tab requires editing two places.
- Adding a new navigation destination requires editing two destination resolvers.
- Risk of the two versions drifting apart (different environment injections, etc.).

### Action Plan
1. **Extract tab content** into shared helper views:
   ```swift
   private func homeTab() -> some View {
       NavigationStack(path: $coordinator.homePath) {
           ImprovedDashboardView()
               .environmentObject(container.gameManagementState)
               .navigationDestination(for: NavigationCoordinator.Destination.self) { 
                   destinationView(for: $0) 
               }
       }
   }
   ```
2. **Use a single `destinationView(for:)`** method. Apply iOS 26 transitions conditionally:
   ```swift
   @ViewBuilder
   private func destinationView(for destination: Destination) -> some View {
       let view = baseDestinationView(for: destination)
       if #available(iOS 26.0, *) {
           view.navigationTransition(transition(for: destination))
       } else {
           view
       }
   }
   ```
3. **Compose the TabViews** from the shared helpers:
   ```swift
   // Both iOS 26 and standard use the same tab definitions
   // iOS 26 just adds .tabBarMinimizeBehavior
   ```

### Effort: ~45 minutes

---

## 🟡 Issue 7: Notification Name Strings Are Scattered & Inconsistent

### What's Going Wrong
Notification names are defined in multiple ways across the codebase:
- `NSNotification.Name("GameResultAdded")` — raw string inline
- `NSNotification.Name("GameDataUpdated")` — raw string inline
- `Notification.Name("RefreshGameData")` — raw string inline
- `Notification.Name(AppConstants.Notification.gameDataUpdated)` — via constants
- `Notification.Name(AppConstants.Notification.shareExtensionResultAvailable)` — via constants
- `.dayDidChange` — proper static extension (good)
- `.CKAccountChanged` — system notification (fine)
- `.joinGroupRequested` — proper static extension (good)

Some notifications use `AppConstants.Notification`, others use raw strings, and some use proper `Notification.Name` extensions. The raw strings like `"GameResultAdded"` and `"GameDataUpdated"` are used in multiple places and could easily be misspelled.

### Why It's a Problem
- **Typo risk**: A misspelled string means an observer silently never fires.
- **Discoverability**: No autocomplete for raw strings.
- **Refactoring difficulty**: Renaming a notification requires find-and-replace across the entire codebase.

### Action Plan
1. Audit all `Notification.Name` / `NSNotification.Name` usage.
2. Define all custom notifications as static extensions:
   ```swift
   extension Notification.Name {
       static let gameResultAdded = Notification.Name("GameResultAdded")
       static let gameDataUpdated = Notification.Name("GameDataUpdated")
       static let refreshGameData = Notification.Name("RefreshGameData")
       static let navigateToGame = Notification.Name("NavigateToGame")
       // ... all others
   }
   ```
3. Replace all raw string usages with the static constants.
4. Consider whether some NotificationCenter usage could be replaced with Combine publishers or `@Observable` callbacks (reducing the notification surface area).

### Effort: ~45 minutes

---

## 🔵 Issue 8: `ensureStreaksForAllGames` Drops Rebuilt Streaks

### What's Going Wrong
In `AppState+Persistence.swift`, `loadStreaks()` calls `ensureStreaksForAllGames()` which adds empty streaks for any game not found in the persisted list. But `rebuildStreaksFromResults()` in `AppState+Import.swift` also rebuilds streaks — only for games that have results. Games with zero results get no streak entry.

After `loadPersistedData()` runs:
1. `loadStreaks()` → loads persisted streaks, fills gaps with empties via `ensureStreaksForAllGames()`
2. `rebuildStreaksFromResults()` → **replaces** `self.streaks` with only games that have results
3. `normalizeStreaksForMissedDays()` → works on whatever is in `self.streaks`

Step 2 loses empty streaks for games with no results. This isn't a visible bug (those games show "no streak" either way), but it means `self.streaks.count` may not equal `self.games.count`, which could confuse UI code that assumes a 1:1 mapping.

### Action Plan
Add `ensureStreaksForAllGames()` at the end of `rebuildStreaksFromResults()`:
```swift
self.streaks = ensureStreaksForAllGames(newStreaks)
```

### Effort: ~5 minutes

---

## Summary: Recommended Execution Order

| Priority | Issue | Risk | Effort |
|----------|-------|------|--------|
| 1 | ✅ Persistence key mismatch bug | ~~Data loss~~ DONE | 0 min |
| 2 | ✅ addGameResult duplication | ~~Diverging behavior~~ DONE | 0 min |
| 3 | ✅ ThemeManager elimination | ~~Dark mode colors wrong~~ DONE | 0 min |
| 4 | ✅ AppState decomposition | ~~Maintainability~~ DONE | 0 min |
| 5 | ✅ SharedModels decomposition | ~~Maintainability~~ DONE | 0 min |
| 6 | ✅ MainTabView dedup | ~~Maintainability~~ DONE | 0 min |
| 7 | ✅ Notification name constants | ~~Typo risk~~ DONE | 0 min |
| 8 | ✅ ensureStreaksForAllGames | ~~Minor inconsistency~~ DONE | 0 min |

Total estimated: **~7 hours** of focused work, all incremental and non-breaking.
