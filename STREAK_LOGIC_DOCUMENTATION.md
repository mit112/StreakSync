# Streak Logic Documentation

## Overview
This document explains how streaks work across games in StreakSync, including when they reset and what functions trigger streak recomputation.

## What Happens on a New Day

### Key Behavior: Streaks Do NOT Automatically Break on New Day

**Important**: When a new day starts, streaks do **NOT** automatically break if no game has been played yet. The streak remains active until one of the following occurs:

#### Scenario 1: Game Played Yesterday, New Day Starts (No Game Played Today Yet)
- **What Happens**: Streak remains **active** and unchanged
- **Why**: `rebuildStreaksFromResults()` only looks at existing game results. Since today has no results yet, it can't detect a gap
- **When It Breaks**: 
  - When a game is played today but shows a gap (e.g., last completed game was 2+ days ago)
  - When the app is launched and `normalizeStreaksForMissedDays()` runs
  - When a result is deleted

#### Scenario 2: Game Played Today (Same Day)
- **What Happens**: 
  - If completed: Streak extends if yesterday was also completed, otherwise starts at 1
  - If failed: Streak breaks immediately (resets to 0)
- **Logic**: Uses `calculateUpdatedStreak()` to determine if consecutive day or gap

#### Scenario 3: Game Played Today But Last Game Was 2+ Days Ago
- **What Happens**: Streak breaks and starts new streak at 1
- **Why**: Gap detection in `calculateUpdatedStreak()` detects `daysBetween > 1`

### Day Change Flow

When `DayChangeDetector` detects a new day:

```swift
handleDayChange()
  → rebuildStreaksFromResults()  // Recalculates from existing results
  → checkAllAchievements()
  → checkAndScheduleStreakReminders()
  // NOTE: normalizeStreaksForMissedDays() is NOT called here
```

**Critical Point**: `normalizeStreaksForMissedDays()` is **NOT** called on day change. It's only called:
- On app launch (`loadPersistedData()`)
- After game result deletion

This means streaks remain active on a new day until actual game results show a gap or the app is launched.

## Streak Reset Conditions

### 1. **Failed Game (Immediate Reset)**
- **Location**: `AppState+GameLogic.swift:103-110`
- **Condition**: When a game result is added with `completed == false`
- **Action**: Streak is immediately reset to 0
- **Code**:
```swift
if result.completed {
    // ... streak extension logic ...
} else {
    // Failed game - break streak
    newCurrentStreak = 0
    newStreakStartDate = nil
}
```

### 2. **Gap in Completed Games (Consecutive Day Break)**
- **Location**: `AppState+GameLogic.swift:72-90`
- **Condition**: When a completed game is added but there's a gap of more than 1 day since the last completed game
- **Action**: Current streak resets to 1 (new streak starts)
- **Logic**:
  - If `daysBetween == 1`: Streak extends (consecutive day)
  - If `daysBetween == 0`: Streak maintains (same day)
  - If `daysBetween > 1`: Streak breaks and starts at 1

### 3. **Missed Day Detection (Normalization)**
- **Location**: `AppState+Persistence.swift:180-260`
- **Condition**: When `normalizeStreaksForMissedDays()` detects an actual gap in completed games
- **Action**: Streak is reset to 0 if there's a missing day in completed game results
- **Key Logic**: Only breaks streaks if there's an actual gap in completed games, NOT just because time has passed
- **Function**: `shouldBreakStreakForGame()` checks for gaps in completed game results

## Streak Computation Functions

### Primary Functions

#### 1. `updateStreak(for: GameResult)` - Incremental Update
- **Location**: `AppState+GameLogic.swift:15-37`
- **Purpose**: Updates a single streak when a new game result is added
- **Called From**:
  - `AppState.addGameResult()` (line 513, 642)
  - `AppState.addGameResultReturningAdded()` (line 642)
- **Flow**:
  1. Finds existing streak for the game
  2. Calls `calculateUpdatedStreak()` to compute new streak
  3. Updates streaks array via `setStreaks()`
  4. **Note**: Caller must save streaks (not saved automatically)

#### 2. `calculateUpdatedStreak(current:with:)` - Streak Calculation Logic
- **Location**: `AppState+GameLogic.swift:39-129`
- **Purpose**: Core logic for calculating streak updates
- **Logic**:
  - **Completed Game**:
    - If streak is 0: Start new streak at 1
    - If streak > 0: Check days between plays
      - 1 day gap: Extend streak
      - 0 days (same day): Maintain streak
      - >1 day gap: Reset to 1 (new streak)
  - **Failed Game**: Reset to 0
- **Updates**: `currentStreak`, `maxStreak`, `streakStartDate`, `lastPlayedDate`, totals

#### 3. `rebuildStreaksFromResults()` - Full Rebuild
- **Location**: `AppState+Import.swift:17-108`
- **Purpose**: Rebuilds all streaks from scratch using all game results
- **Called From**:
  - `AppState.handleDayChange()` (line 264) - On day change
  - `AppState.removeGameResult()` (line 728) - After deletion
  - `AppState.loadPersistedData()` - Not directly, but via normalization
  - `UserDataSyncService` (lines 408, 468) - After CloudKit sync
  - `CloudKitSubscriptionManager` (lines 39, 53) - After remote changes
  - `AppContainer` (line 301) - On app initialization
  - `StreakSyncApp` (line 150) - On app launch
  - `SettingsComponents` (line 660) - Manual rebuild trigger
- **Flow**:
  1. Groups results by game
  2. Sorts results chronologically
  3. Calculates streaks by iterating through completed games
  4. Tracks consecutive days (only completed games count)
  5. Breaks streak on gaps or failed games
  6. Replaces entire streaks array
- **Important Limitation**: Only checks gaps **between** existing results, not gaps between last result and **today**
- **Fix**: Always call `normalizeStreaksForMissedDays()` after `rebuildStreaksFromResults()` to check for gaps up to today

#### 4. `normalizeStreaksForMissedDays()` - Streak Normalization
- **Location**: `AppState+Persistence.swift:180-220`
- **Purpose**: Checks and breaks streaks that should be broken due to missed days
- **Called From**:
  - `AppState.loadPersistedData()` (line 54) - On app launch
  - `AppState.removeGameResult()` (line 730) - After deletion
- **Key Feature**: Only breaks streaks if there's an actual gap in completed games (not just time elapsed)
- **Helper**: `shouldBreakStreakForGame()` checks for gaps in completed results

## Trigger Points for Streak Recalculation

### Automatic Triggers

#### 1. **New Game Result Added**
- **Function**: `AppState.addGameResult(_:)`
- **Location**: `AppState.swift:457-590`
- **Actions**:
  1. Calls `updateStreak(for: result)` synchronously (line 513, 642)
  2. Posts notifications: `GameResultAdded`, `GameDataUpdated`, `RefreshGameData`
  3. Saves streaks asynchronously (line 555, 681)
  4. Calls `checkAndScheduleStreakReminders()`

#### 2. **Day Change Detected**
- **Detector**: `DayChangeDetector` (checks every minute + app lifecycle events)
- **Notification**: `.dayDidChange`
- **Handler**: `AppState.handleDayChange()`
- **Location**: `AppState.swift:256-273`
- **Actions**:
  1. Invalidates cache
  2. Calls `rebuildStreaksFromResults()` - Full rebuild (recalculates from existing results only)
  3. Checks achievements
  4. Reschedules streak reminders
- **Important**: `normalizeStreaksForMissedDays()` is **NOT** called on day change
- **Result**: Streaks remain active if no game has been played yet today. They only break when:
  - A game is played and shows a gap
  - App is launched (normalization runs)
  - A result is deleted

#### 3. **App Launch/Initialization**
- **Location**: `StreakSyncApp.initializeApp()` → `AppState.loadPersistedData()`
- **Actions**:
  1. Loads persisted data (including streaks)
  2. Calls `normalizeStreaksForMissedDays()` - Checks for missed days
  3. Performs CloudKit sync (if available)
  4. Calls `rebuildStreaksFromResults()` - Rebuilds from synced results
  5. **Calls `normalizeStreaksForMissedDays()` again** - Checks for gaps up to today after rebuild
  6. Ensures streaks exist for all games
- **Bug Fix**: Added normalization after rebuild to fix issue where streaks showed as active even when games weren't played for days

#### 4. **Game Result Deleted**
- **Function**: `AppState.removeGameResult(_:)`
- **Location**: `AppState.swift:718-744`
- **Actions**:
  1. Removes result from array
  2. Rebuilds cache
  3. Calls `rebuildStreaksFromResults()` - Full rebuild
  4. Calls `normalizeStreaksForMissedDays()` - Check for now-missed days
  5. Recomputes achievements
  6. Saves all data
  7. Posts `GameDataUpdated` notification

#### 5. **CloudKit Sync Events**
- **Service**: `UserDataSyncService`
- **Actions**: Calls `rebuildStreaksFromResults()` after syncing results
- **Service**: `CloudKitSubscriptionManager`
- **Actions**: Calls `rebuildStreaksFromResults()` after remote changes

### Manual Triggers

#### 1. **Settings - Force Rebuild**
- **Location**: `SettingsComponents.swift:660`
- **Function**: `forceRebuildAllStreaks()`
- **Action**: Full rebuild + save + notifications

#### 2. **Connections Fix**
- **Location**: `AppState+Import.swift:174`
- **Function**: `fixExistingConnectionsResults()`
- **Action**: After fixing Connections results, rebuilds streaks

## Notification System

### Notifications Posted When Streaks Change

1. **`GameResultAdded`**
   - Posted: When a new game result is added
   - Listeners: Dashboard views, Analytics views

2. **`GameDataUpdated`**
   - Posted: When game data (including streaks) changes
   - Listeners: Dashboard views, Game detail views, Analytics views, Achievement store

3. **`RefreshGameData`**
   - Posted: When specific game data needs refresh
   - Listeners: Dashboard views, Game detail views

### Notification Flow
```
addGameResult() 
  → updateStreak() 
  → setStreaks() 
  → Post notifications (GameResultAdded, GameDataUpdated, RefreshGameData)
  → Save streaks asynchronously
```

## Streak Calculation Rules

### What Counts Toward Streaks
- **Only completed games** count toward streaks
- Failed games (`completed == false`) break streaks immediately
- Multiple plays on the same day don't increment streak (maintains current)

### Consecutive Day Logic
- Streak extends when: Completed game on day N, then completed game on day N+1
- Streak breaks when: Gap of 2+ days between completed games
- Streak resets when: Failed game is played

### Streak State Properties
- `currentStreak`: Current consecutive days (only completed games)
- `maxStreak`: Highest streak achieved (never decreases)
- `streakStartDate`: Date when current streak started
- `lastPlayedDate`: Date of most recent game (completed or failed)
- `totalGamesPlayed`: Total games played (completed + failed)
- `totalGamesCompleted`: Total completed games only

## Important Notes

### 1. **Streak Updates Are Synchronous, Saves Are Asynchronous**
- `updateStreak()` updates streaks immediately in memory
- Streaks are saved asynchronously via `saveStreaks()`
- This ensures UI updates immediately while persistence happens in background

### 2. **Full Rebuild vs Incremental Update**
- **Incremental**: `updateStreak()` - Fast, used when adding single result
- **Full Rebuild**: `rebuildStreaksFromResults()` - Slower, used for:
  - Day changes
  - After deletions
  - After sync operations
  - When data integrity needs verification

### 3. **Normalization Only Checks Gaps**
- `normalizeStreaksForMissedDays()` doesn't rebuild streaks
- It only checks if existing streaks should be broken due to gaps
- **Called only on**:
  - App launch (`loadPersistedData()`)
  - After game result deletion
- **NOT called on day change** - This is why streaks don't automatically break on a new day
- Uses `shouldBreakStreakForGame()` to check for actual gaps in completed game results

### 4. **Guest Mode Behavior**
- Streak updates are skipped in Guest Mode (`isGuestMode` check)
- Guest sessions operate in memory only
- Host streaks are preserved and restored when Guest Mode exits

## Summary Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    STREAK UPDATE FLOW                        │
└─────────────────────────────────────────────────────────────┘

New Game Result Added
    │
    ├─→ updateStreak(for: result)
    │       │
    │       └─→ calculateUpdatedStreak()
    │               │
    │               ├─→ Completed & Consecutive Day? → Extend streak
    │               ├─→ Completed & Same Day? → Maintain streak
    │               ├─→ Completed & Gap >1 day? → Reset to 1
    │               └─→ Failed? → Reset to 0
    │
    ├─→ Post Notifications (GameResultAdded, GameDataUpdated)
    │
    └─→ Save Streaks (async)

Day Change Detected
    │
    └─→ rebuildStreaksFromResults()
            │
            └─→ Recalculate all streaks from scratch

App Launch
    │
    ├─→ Load Persisted Streaks
    │
    └─→ normalizeStreaksForMissedDays()
            │
            └─→ Check for gaps → Break streaks if needed

Game Result Deleted
    │
    ├─→ rebuildStreaksFromResults()
    │
    └─→ normalizeStreaksForMissedDays()
```

## Key Files Reference

- **Streak Model**: `StreakSync/Core/Models/Streak/StreakModels.swift`
- **Streak Update Logic**: `StreakSync/Core/State/AppState+GameLogic.swift`
- **Streak Rebuild Logic**: `StreakSync/Core/State/AppState+Import.swift`
- **Streak Normalization**: `StreakSync/Core/State/AppState+Persistence.swift`
- **Day Change Detection**: `StreakSync/Core/Services/Utilities/DayChangeDetector.swift`
- **Main App State**: `StreakSync/Core/State/AppState.swift`

---

## November 2025 Updates

- **Refresh Data Self-Healing**
  - `AppState.refreshData()` now calls `rebuildStreaksFromResults()` followed by `normalizeStreaksForMissedDays()` after reloading persisted data.
  - This ensures streaks are always recomputed from the authoritative source of truth (`recentResults`) whenever the dashboard or game detail is refreshed or the app comes back to the foreground.
  - Fixes cases where streak summaries could drift out of sync with actual results (e.g. a Zip result existing while the Zip streak showed 0).

- **Calendar-Day Status & Activity**
  - `GameDateHelper` now computes "Today", "Yesterday", and "X days ago" using **calendar-day** comparisons via `startOfDay(for:)` instead of raw elapsed time.
  - `GameStreak.isActive` is `true` only when the last played date is today or yesterday; games played 2+ calendar days ago are considered inactive even if less than 48 hours have passed.
  - This keeps streak activity and status text correct across midnight boundaries and during early-morning launches.


