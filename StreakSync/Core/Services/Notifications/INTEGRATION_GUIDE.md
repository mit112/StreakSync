# Notification System Integration Guide

## Quick Start

### 1. Initialize the Notification System

In your main app file (`StreakSyncApp.swift`), the notification delegate is initialized and categories are registered at launch if permission is authorized:

```swift
// In initializeApp():
NotificationDelegate.shared.appState = container.appState
NotificationDelegate.shared.navigationCoordinator = container.navigationCoordinator
let status = await NotificationScheduler.shared.checkPermissionStatus()
if status == .authorized { await NotificationScheduler.shared.registerCategories() }
```

### 2. Add Notification Settings to Your Settings View

The notification settings are already integrated into your main settings view. Users can access them via:
- Settings → Notifications

The simplified settings include:
- **Enable Streak Reminders**: Master toggle for all streak reminders
- **Reminder Time**: Single time picker for daily reminder (default: 7 PM)

### 3. Schedule Notifications

The system automatically schedules daily reminders based on user settings. To manually trigger a check:

```swift
// Check and schedule streak reminders
Task {
    await appState.checkAndScheduleStreakReminders()
}

// Schedule achievement notification
Task {
    await NotificationScheduler.shared.scheduleAchievementNotification(
        for: achievementUnlock
    )
}
```

### 4. Handle Achievement Unlocks

In your achievement unlock handler, add notification scheduling:

```swift
func handleTieredAchievementUnlock(_ unlock: AchievementUnlock) {
    // Post internal notification for UI
    NotificationCenter.default.post(
        name: Notification.Name("TieredAchievementUnlocked"),
        object: unlock
    )
    
    // Schedule user notification
    Task {
        await NotificationScheduler.shared.scheduleAchievementNotification(for: unlock)
    }
}
```

## Key Components

### NotificationPermissionFlowView
- Shows when user first enables notifications
- Explains benefits clearly
- Provides easy opt-out

### NotificationSettingsView
- **Simplified Settings**: Just enable toggle and time picker
- **No Per-Game Configuration**: Works automatically for all games
- **Debug Tools**: Test notifications and check current state

### NotificationScheduler
- **Single Daily Reminder**: Maximum one notification per day
- **Dynamic Content**: Adapts message based on number of games at risk
- **Automatic Scheduling**: Works with user's preferred time
- **Legacy Cleanup**: Cancels old per-game notifications

### NotificationDelegate
- **Handles notification interactions**: Tap, action buttons
- **Manages foreground display**: Shows notifications when app is open
- **Routes actions**: Opens specific games or achievements
- **Simplified Actions**: Works with new single daily reminder system

## How the Simplified System Works

### Daily Reminder Process
1. **App Check**: System checks all games with active streaks
2. **Risk Assessment**: Identifies games not played today
3. **Single Notification**: Sends one notification listing all at-risk games
4. **Dynamic Content**: Adapts message based on number of games at risk
5. **Day Change Reschedule**: On day change, the repeating reminder is rescheduled so content matches today’s at-risk games

### Notification Content Examples
- **1 Game**: "Don't lose your Wordle streak"
- **2-3 Games**: "Don't lose your streaks in Wordle, Connections"
- **4+ Games**: "Don't lose your streaks in Wordle, Connections, and 3 other games"

### User Experience Flow
1. **First Launch**: No permission request (respectful)
2. **User Enables**: Simple permission flow with clear benefits
3. **Settings**: Just 2 settings - enable toggle and time picker
4. **Daily Reminders**: One notification per day maximum
5. **Actions**:
   - Play Now: deep-links into the game
   - Remind Tomorrow: cancels the repeating daily reminder and schedules a one-off reminder for the next day at the selected time
   - Mark as Played: triggers immediate re-evaluation and rescheduling (cancels if no games are at risk)

## Migration from Old System

The system automatically migrates from the previous complex system:
- **Cleans up old settings**: Removes per-game configurations
- **Sets sensible defaults**: Enabled, 7 PM reminder time
- **Cancels old notifications**: Removes all per-game reminders
- **Schedules new reminder**: Single daily reminder system

## Best Practices

- **Permission First**: Always check permission status before scheduling
- **User Control**: Respect user preferences and settings
- **Simple Configuration**: Keep settings minimal and easy to understand
- **Test Thoroughly**: Use debug tools to test notification behavior
- **Error Handling**: Gracefully handle permission denials and errors

## Testing

Use the debug tools in NotificationSettingsView to test:

```swift
// Test notification (Debug builds only)
Button("Test Notification") {
    Task {
        await viewModel.testNotification()
    }
}

// Check current state
Button("Check Current State") {
    Task {
        await NotificationScheduler.shared.logCurrentNotificationState()
    }
}
```

## Benefits of Simplified System

1. **No Multiple Notifications**: Users receive maximum one notification per day
2. **Easy to Understand**: Simple on/off toggle and time picker
3. **No Per-Game Configuration**: Works automatically for all games
4. **Reliable**: Consistent behavior without complex settings
5. **User-Friendly**: Clear, actionable notifications

## Troubleshooting

### Common Issues
- **No notifications**: Check permission status and reminder settings
- **Multiple notifications**: Old system remnants - migration should clean these up
- **Wrong time**: Verify time picker settings in notification settings

### Debug Steps
1. Check notification permission status
2. Verify reminder settings are enabled
3. Check if games have active streaks
4. Use debug tools to test notification scheduling
5. Check current notification state

The simplified system is designed to be helpful without being pushy, giving users complete control while providing genuine value through smart, daily reminders.

## Notes
- Smart Reminders are currently disabled. The app uses a single user-selected time and reschedules at day change to keep content accurate.