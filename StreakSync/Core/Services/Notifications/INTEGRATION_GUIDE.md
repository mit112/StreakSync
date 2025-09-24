# Notification System Integration Guide

## Quick Start

### 1. Initialize the Notification System

In your main app file (`StreakSyncApp.swift`), the notification delegate is already initialized:

```swift
.onAppear {
    // Initialize notification delegate
    NotificationDelegate.shared.appState = container.appState
    NotificationDelegate.shared.navigationCoordinator = container.navigationCoordinator
}
```

### 2. Add Notification Settings to Your Settings View

The notification settings are already integrated into your main settings view. Users can access them via:
- Settings → Notifications

### 3. Add Contextual Nudges

Add notification nudges to your views where appropriate:

```swift
struct YourView: View {
    var body: some View {
        VStack {
            // Global notification nudge
            NotificationNudgeView()
            
            // Your existing content
            // ...
            
            // Game-specific nudges
            ForEach(games) { game in
                VStack {
                    GameCardView(game: game)
                    GameNotificationNudgeView(game: game)
                }
            }
        }
    }
}
```

### 4. Schedule Notifications

When you want to schedule notifications, use the `NotificationScheduler`:

```swift
// Schedule a streak reminder
Task {
    await NotificationScheduler.shared.scheduleStreakReminder(
        for: game, 
        at: preferredTime
    )
}

// Schedule achievement notification
Task {
    await NotificationScheduler.shared.scheduleAchievementNotification(
        for: achievementUnlock
    )
}
```

### 5. Handle Achievement Unlocks

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
- Comprehensive settings for all notification preferences
- Per-game customization
- Global controls (quiet hours, frequency caps)

### NotificationNudgeView
- Smart contextual suggestions
- Only shows after 3+ days of usage
- Non-intrusive presentation

### NotificationScheduler
- Handles all notification scheduling
- Respects user preferences
- Manages frequency caps and quiet hours

### NotificationDelegate
- Handles notification interactions
- Manages foreground display
- Routes actions to appropriate app sections

## User Experience Flow

1. **First Launch**: No permission request (respectful)
2. **After 3 Days**: Contextual nudge appears suggesting notifications
3. **User Enables**: Permission flow with clear benefits
4. **Settings**: Full control over all notification preferences
5. **Notifications**: Smart, contextual, actionable reminders

## Best Practices

- Always check permission status before scheduling
- Respect quiet hours and frequency caps
- Provide clear value in notification content
- Make it easy to disable or customize
- Test thoroughly in all app states

## Testing

Use the preview files to test different notification states:

```swift
#Preview("Permission Flow") {
    NotificationPermissionFlowView()
}

#Preview("Settings") {
    NotificationSettingsView()
        .environment(AppState(persistenceService: MockPersistenceService()))
}
```

The system is designed to be helpful without being pushy, giving users complete control while providing genuine value through smart, contextual reminders.
