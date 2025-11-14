# Notification System Analysis

## Overview
Comprehensive analysis of the StreakSync notification system to identify potential issues.

## System Architecture

### Core Components

1. **NotificationScheduler** (`StreakSync/Core/Services/Notifications/NotificationScheduler.swift`)
   - Singleton (`NotificationScheduler.shared`)
   - MainActor class
   - Handles all notification scheduling
   - Manages notification categories and actions
   - Key methods:
     - `scheduleDailyStreakReminder(games: [Game], hour: Int, minute: Int)`
     - `cancelDailyStreakReminder()`
     - `scheduleAchievementNotification(for: AchievementUnlock)`
     - `scheduleResultImportedNotification(for: Game)`
     - `registerCategories()` - Registers notification categories with actions
     - `checkPermissionStatus()` - Checks authorization status

2. **NotificationDelegate** (`StreakSync/Core/Services/Notifications/NotificationDelegate.swift`)
   - Singleton (`NotificationDelegate.shared`)
   - Implements `UNUserNotificationCenterDelegate`
   - Handles foreground notification presentation
   - Handles user interactions (tap, action buttons)
   - Properties:
     - `weak var appState: AppState?`
     - `weak var navigationCoordinator: NavigationCoordinator?`
   - Initialization: Sets `UNUserNotificationCenter.current().delegate = self` in `init()`
   - Dependencies set later in `StreakSyncApp.onAppear`

3. **NotificationPermissionFlow** (`StreakSync/Core/Services/Notifications/NotificationPermissionFlow.swift`)
   - Handles permission requests
   - Shows educational flow
   - Calls `NotificationScheduler.shared.registerCategories()` when permission granted

4. **NotificationSettingsView** (`StreakSync/Features/Settings/Views/NotificationSettingsView.swift`)
   - UI for configuring notifications
   - Loads/saves settings from UserDefaults
   - Calls `appState.checkAndScheduleStreakReminders()` when settings change

5. **NotificationCoordinator** (`StreakSync/Core/Services/Utilities/NotificationCoordinator.swift`)
   - ⚠️ **NOTE**: This is NOT for UserNotifications - it handles internal app notifications (NotificationCenter)
   - Manages game result ingestion, deep links, app lifecycle
   - Different from the UserNotifications system

6. **DayChangeDetector** (`StreakSync/Core/Services/Utilities/DayChangeDetector.swift`)
   - Monitors day changes
   - Posts `.dayDidChange` notification
   - Timer-based (checks every minute) + app lifecycle events

### Notification Flow

#### Daily Streak Reminder Flow
1. `AppState.checkAndScheduleStreakReminders()` is called:
   - On app launch (`StreakSyncApp.initializeApp()`)
   - When game result is added (`AppState.addGameResult()`)
   - When settings change (`NotificationSettingsView.saveSettings()`)
   - When smart reminder is applied (`AppState.applySmartReminderNow()`)

2. `checkAndScheduleStreakReminders()`:
   - Checks if reminders enabled
   - Gets preferred time from UserDefaults
   - Finds games at risk via `getGamesAtRisk()`
   - Calls `NotificationScheduler.shared.scheduleDailyStreakReminder()`

3. `scheduleDailyStreakReminder()`:
   - Checks permission status
   - Cancels existing daily reminder
   - Creates notification content based on number of games
   - Schedules with `UNCalendarNotificationTrigger` (repeats: true)

#### Day Change Flow
1. `DayChangeDetector` detects day change
2. Posts `.dayDidChange` notification
3. `AppState.handleDayChange()` is called:
   - Invalidates caches
   - Rebuilds streaks
   - Checks achievements
   - Calls `updateSmartRemindersIfNeeded()`

#### Smart Reminder Flow
1. `updateSmartRemindersIfNeeded()`:
   - Checks if smart reminders enabled
   - Checks if 2+ days since last computation
   - Calls `applySmartReminderNow()` if needed

2. `applySmartReminderNow()`:
   - Computes smart reminder suggestion
   - Updates UserDefaults with new time
   - Calls `checkAndScheduleStreakReminders()`

## Identified Issues

### 🔴 CRITICAL ISSUE #1: Missing Notification Rescheduling on Day Change

**Location**: `StreakSync/Core/State/AppState.swift:240-258`

**Problem**: 
In `handleDayChange()`, the system:
- Rebuilds streaks
- Checks achievements  
- Updates smart reminders

**BUT** it does NOT call `checkAndScheduleStreakReminders()` to reschedule notifications for the new day.

**Impact**: 
- If games at risk change on a new day, notifications won't be updated
- Daily reminder might show stale game list
- Notifications might fire for games that are no longer at risk
- Notifications might not fire for newly at-risk games

**Expected Behavior**:
After rebuilding streaks and checking achievements, the system should reschedule notifications to reflect the current state of games at risk.

**Fix Required**:
```swift
private func handleDayChange() {
    logger.info("📅 Day changed - refreshing UI data")
    
    invalidateCache()
    
    Task {
        await rebuildStreaksFromResults()
        await checkAllAchievements()
        await updateSmartRemindersIfNeeded()
        
        // ADD THIS:
        await checkAndScheduleStreakReminders()
        
        logger.info("✅ UI refreshed for new day")
    }
}
```

### 🟡 ISSUE #2: Notification Categories May Not Be Registered on App Launch

**Location**: `StreakSync/Core/Services/Notifications/NotificationPermissionFlow.swift:37`

**Problem**:
`registerCategories()` is only called when:
- User grants permission in `NotificationPermissionFlowViewModel.requestPermission()`

**But NOT**:
- On app launch if permission was already granted
- When app becomes active if permission exists

**Impact**:
- If user granted permission previously, categories might not be registered
- Notification actions (Play Now, Remind Tomorrow, etc.) might not work
- Categories should be registered whenever permission is authorized

**Expected Behavior**:
Categories should be registered:
1. When permission is granted (current)
2. On app launch if permission already exists
3. When app becomes active if permission exists

**Fix Required**:
Register categories in `StreakSyncApp.initializeApp()` or `NotificationScheduler.init()` after checking permission status.

### 🟡 ISSUE #3: NotificationDelegate Dependencies Set Late

**Location**: `StreakSync/App/StreakSyncApp.swift:104-108`

**Problem**:
- `NotificationDelegate.init()` sets `UNUserNotificationCenter.current().delegate = self` immediately
- But `appState` and `navigationCoordinator` are set later in `.onAppear`
- If a notification arrives between init and onAppear, handlers will fail

**Impact**:
- Race condition: notification could arrive before dependencies are set
- Navigation from notifications might fail
- Action handlers might not work properly

**Expected Behavior**:
Dependencies should be set as early as possible, ideally in `initializeApp()` before marking app as initialized.

**Fix Required**:
Move dependency setup to `initializeApp()`:
```swift
private func initializeApp() async {
    logger.info("🚀 Starting app initialization")
    
    // Set notification delegate dependencies EARLY
    NotificationDelegate.shared.appState = container.appState
    NotificationDelegate.shared.navigationCoordinator = container.navigationCoordinator
    
    // Register categories if permission exists
    let status = await NotificationScheduler.shared.checkPermissionStatus()
    if status == .authorized {
        await NotificationScheduler.shared.registerCategories()
    }
    
    await container.appState.loadPersistedData()
    await container.appState.checkAndScheduleStreakReminders()
    
    await MainActor.run {
        isInitialized = true
        logger.info("✅ App initialization completed")
    }
}
```

### 🟡 ISSUE #4: Smart Reminders Don't Reschedule Regular Reminders on Day Change

**Location**: `StreakSync/Core/State/AppState.swift:826-834`

**Problem**:
`updateSmartRemindersIfNeeded()` only runs if smart reminders are enabled. If smart reminders are OFF, regular reminders are not rescheduled on day change.

**Impact**:
- Regular reminders might show stale game lists after day change
- Games at risk might change but notifications won't reflect this

**Expected Behavior**:
Even if smart reminders are disabled, regular reminders should be rescheduled on day change to reflect current games at risk.

**Fix Required**:
In `handleDayChange()`, always call `checkAndScheduleStreakReminders()` regardless of smart reminder status.

### 🟢 MINOR ISSUE #5: Notification Content May Be Stale

**Location**: `StreakSync/Core/Services/Notifications/NotificationScheduler.swift:226-284`

**Problem**:
`scheduleDailyStreakReminder()` uses the games list passed in. If this list is computed at scheduling time but the notification fires later, the content might be stale.

**Impact**:
- Notification content is computed at scheduling time, not at delivery time
- This is actually correct for local notifications (content is set when scheduled)
- But the games list should reflect current state

**Note**: This is less of an issue because notifications are rescheduled when games change. However, with the day change bug (#1), this becomes more problematic.

## Notification Categories

### Registered Categories:
1. **STREAK_REMINDER**
   - Actions: Play Now, Remind Tomorrow, Already Played
   - Options: customDismissAction

2. **ACHIEVEMENT_UNLOCKED**
   - Actions: View Achievement
   - Options: customDismissAction

3. **RESULT_IMPORTED**
   - Actions: None
   - Options: customDismissAction

## UserDefaults Keys

### Notification Settings:
- `streakRemindersEnabled` (Bool)
- `streakReminderHour` (Int)
- `streakReminderMinute` (Int)

### Smart Reminder Settings:
- `smartRemindersEnabled` (Bool)
- `smartRemindersLastComputed` (Date)
- `smartReminderWindowStartHour` (Int)
- `smartReminderWindowEndHour` (Int)
- `smartReminderCoveragePercent` (Int)

### Migration:
- `notificationSystemMigrated_v2` (Bool)

## Notification Trigger Types

1. **Daily Streak Reminder**: `UNCalendarNotificationTrigger` with repeats: true
   - Scheduled once, repeats daily at specified time
   - Identifier: `"daily_streak_reminder"`

2. **Achievement Notification**: `UNTimeIntervalNotificationTrigger` (1 second)
   - Immediate notification
   - Identifier: `"achievement_{achievementId}_{tierId}"`

3. **Result Imported**: `UNTimeIntervalNotificationTrigger` (1 second)
   - Immediate notification
   - Identifier: `"result_imported_{gameId}_{timestamp}"`

## Testing Recommendations

1. **Test Day Change**:
   - Set device time to 11:59 PM
   - Wait for day change
   - Verify notifications are rescheduled
   - Verify games at risk are recalculated

2. **Test Permission Flow**:
   - Fresh install
   - Grant permission
   - Verify categories registered
   - Restart app
   - Verify categories still registered

3. **Test Notification Actions**:
   - Schedule test notification
   - Interact with actions
   - Verify navigation works
   - Verify handlers execute

4. **Test Smart Reminders**:
   - Enable smart reminders
   - Add game results at various times
   - Wait 2+ days
   - Verify reminder time updates
   - Verify notifications rescheduled

## Reminder System Deep Dive

### Games at Risk Detection (`getGamesAtRisk()`)

**Location**: `StreakSync/Core/State/AppState.swift:705-731`

**Logic**:
1. Iterates through all games
2. For each game, checks:
   - Has active streak (`currentStreak > 0`)
   - Has NOT played today (no completed result for today)
3. Returns list of games meeting both criteria

**Analysis**: ✅ Logic is correct and straightforward. Uses `calendar.isDate(_:inSameDayAs:)` for accurate day comparison.

### Smart Reminder Algorithm (`computeSmartReminderSuggestion()`)

**Location**: `StreakSync/Core/State/AppState.swift:797-823`

**Algorithm Steps**:
1. Builds 24-hour histogram from last 30 days of completed results
2. Slides 2-hour window across 24 hours to find best coverage
3. Calculates reminder time as 30 minutes before window start
4. Clamps to 06:00–22:00 range

**🔴 CRITICAL BUG #6: Incorrect Window End Calculation**

**Location**: Line 816

**Problem**:
```swift
let windowEnd = (bestStart + 2) % 24
```

**This is WRONG!** The algorithm correctly finds a 2-hour window by checking:
```swift
let c = hourCounts[h] + hourCounts[(h + 1) % 24]  // Line 812
```

This means if `bestStart = 22`, the window is hours 22 and 23 (2 hours). But the code calculates:
- `windowEnd = (22 + 2) % 24 = 0` ❌

**Correct calculation**:
- For a 2-hour window starting at `bestStart`, the window is `[bestStart, bestStart+1]`
- So `windowEnd` should be `(bestStart + 1) % 24`
- If `bestStart = 22`: `windowEnd = 23` ✅
- If `bestStart = 23`: `windowEnd = 0` ✅

**Impact**:
- Window end is stored incorrectly in UserDefaults
- Display in UI shows wrong window (e.g., "22-0" instead of "22-23")
- Analytics and insights show incorrect play windows
- Documentation mismatch (shows wrong window in logs)

**Fix Required**:
```swift
let windowEnd = (bestStart + 1) % 24  // Correct: 2-hour window [start, start+1]
```

**Note**: The same bug exists in `AnalyticsDashboardView.swift:522` - needs the same fix.

### Smart Reminder Time Calculation

**Location**: Lines 818-821

**Logic**:
- Calculates reminder time as 30 minutes before window start
- Formula: `hour = (windowStart - 1 + 24) % 24`, `minute = 30`
- Clamps to 06:00–22:00 range

**Analysis**: ✅ **Code is CORRECT**

**Example**:
- If `windowStart = 19` (7 PM):
  - `hour = (19 - 1 + 24) % 24 = 18` (6 PM)
  - `minute = 30`
  - Result: `18:30` (6:30 PM) = 30 minutes before 19:00 ✅

- If `windowStart = 0` (midnight):
  - `hour = (0 - 1 + 24) % 24 = 23` (11 PM previous day)
  - `minute = 30`
  - Result: `23:30` (11:30 PM) = 30 minutes before 00:00 ✅

**Clamping**:
- If calculated hour < 6: Sets to 06:00
- If calculated hour > 22: Sets to 22:00

**Conclusion**: The time calculation correctly implements "30 minutes before window start" as documented. No fix needed.

### Smart Reminder Application Flow

**Location**: `StreakSync/Core/State/AppState.swift:837-850`

**Flow**:
1. `applySmartReminderNow()` computes suggestion
2. Updates UserDefaults with new time and window
3. **Forces** `streakRemindersEnabled = true` (line 840)
4. **Forces** `smartRemindersEnabled = true` (line 841)
5. Calls `checkAndScheduleStreakReminders()`

**🟡 ISSUE #7: Smart Reminder Forces Enable**

**Problem**: 
When `applySmartReminderNow()` is called, it forces both `streakRemindersEnabled` and `smartRemindersEnabled` to `true`, even if the user had disabled them.

**Impact**:
- User disables reminders → Smart reminder gets applied → Reminders re-enabled without user consent
- Violates user preference

**Expected Behavior**:
- Only update the time if reminders are already enabled
- Or check if reminders are enabled before applying

**Fix Required**:
```swift
func applySmartReminderNow() async {
    let suggestion = computeSmartReminderSuggestion()
    let defaults = UserDefaults.standard
    
    // Only apply if reminders are enabled
    guard defaults.bool(forKey: "streakRemindersEnabled") else {
        logger.info("⏭️ Reminders disabled - not applying smart reminder")
        return
    }
    
    defaults.set(Date(), forKey: "smartRemindersLastComputed")
    defaults.set(suggestion.hour, forKey: "streakReminderHour")
    defaults.set(suggestion.minute, forKey: "streakReminderMinute")
    defaults.set(suggestion.windowStart, forKey: "smartReminderWindowStartHour")
    defaults.set(suggestion.windowEnd, forKey: "smartReminderWindowEndHour")
    defaults.set(suggestion.coverage, forKey: "smartReminderCoveragePercent")
    defaults.set(true, forKey: "smartRemindersEnabled")  // Only set smart flag
    
    await checkAndScheduleStreakReminders()
}
```

### Reminder Scheduling Flow

**Complete Flow**:
1. `checkAndScheduleStreakReminders()` called
2. Checks if reminders enabled
3. Gets preferred time from UserDefaults
4. Calls `getGamesAtRisk()` to find games
5. If games at risk:
   - Calls `NotificationScheduler.scheduleDailyStreakReminder()`
6. If no games at risk:
   - Cancels daily reminder

**Analysis**: ✅ Flow is logical and correct. The only issue is it's not called on day change.

## Summary

The notification system is well-architected but has several critical bugs:

1. **Missing notification rescheduling on day change** - notifications not updated when day changes
2. **Smart reminder window calculation bug** - windowEnd is calculated incorrectly
3. **Smart reminder forces enable** - violates user preferences
4. **Notification categories not registered on launch** - may cause action buttons to fail
5. **NotificationDelegate dependencies set late** - race condition risk

**Priority Fixes**:
1. 🔴 **CRITICAL**: Add `checkAndScheduleStreakReminders()` call in `handleDayChange()`
2. 🔴 **CRITICAL**: Fix `windowEnd` calculation in `computeSmartReminderSuggestion()` (line 816)
3. 🔴 **CRITICAL**: Fix same bug in `AnalyticsDashboardView.swift` (line 522)
4. 🟡 **HIGH**: Fix smart reminder to not force-enable reminders
5. 🟡 **HIGH**: Register categories on app launch if permission exists
6. 🟡 **HIGH**: Move NotificationDelegate dependency setup to `initializeApp()`
7. 🟡 **MEDIUM**: Ensure regular reminders reschedule on day change regardless of smart reminder status

