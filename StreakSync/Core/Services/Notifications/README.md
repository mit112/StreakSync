# Notification System

A comprehensive, user-respectful notification system for StreakSync that provides gentle reminders while giving users full control over their experience.

## Overview

The notification system is designed with these principles:
- **User value first**: Only notify when it's clearly helpful
- **Respect and control**: Explicit opt-in, quiet hours, per-game control, easy snooze/pause
- **Non-intrusive UX**: Don't interrupt flow; in-app surfaces are subtle and contextual

## Components

### 1. NotificationPermissionFlow.swift
**Purpose**: In-app permission flow with clear benefits and user control

**Key Features**:
- Deferred permission request (not on first launch)
- Clear explanation of benefits before asking
- Fallback to system settings if denied
- Beautiful, non-pushy UI

**Usage**:
```swift
.sheet(isPresented: $showingPermissionFlow) {
    NotificationPermissionFlowView()
}
```

### 2. NotificationScheduler.swift
**Purpose**: Smart notification scheduling with frequency caps and quiet hours

**Key Features**:
- Per-game reminder scheduling
- Achievement unlock notifications
- Result import confirmations
- Quiet hours respect
- Daily frequency caps
- Digest mode support

**Usage**:
```swift
// Schedule a streak reminder
await NotificationScheduler.shared.scheduleStreakReminder(
    for: game, 
    at: preferredTime
)

// Schedule achievement notification
await NotificationScheduler.shared.scheduleAchievementNotification(
    for: unlock
)
```

### 3. NotificationDelegate.swift
**Purpose**: Handles notification interactions and foreground display

**Key Features**:
- Foreground notification handling
- Action button responses (Open Game, Snooze, Mark Played)
- In-app banner display
- Deep linking to specific games/achievements

**Usage**:
```swift
// Initialize in app startup
NotificationDelegate.shared.appState = appState
NotificationDelegate.shared.navigationCoordinator = navigationCoordinator
```

### 4. NotificationSettingsView.swift
**Purpose**: Comprehensive notification settings with per-game controls

**Key Features**:
- Global settings (quiet hours, frequency caps, digest mode)
- Per-game reminder customization
- Time preferences and frequency options
- Easy enable/disable toggles

**Usage**:
```swift
NavigationLink {
    NotificationSettingsView()
} label: {
    // Settings row
}
```

### 5. NotificationNudgeView.swift
**Purpose**: Contextual nudges to suggest enabling notifications

**Key Features**:
- Smart timing (only after 3+ days of usage)
- Game-specific nudges
- Streak risk warnings
- Non-intrusive presentation

**Usage**:
```swift
// Global nudge
NotificationNudgeView()

// Game-specific nudge
GameNotificationNudgeView(game: game)

// Streak risk nudge
StreakRiskNudgeView(game: game, streakCount: 7)
```

## Notification Types

### 1. Streak Reminders
- **Trigger**: Based on user's preferred play time for each game
- **Content**: "Keep your [Game] streak alive! Play now to maintain your progress."
- **Actions**: Play Now, Remind Tomorrow, Already Played

### 2. Achievement Notifications
- **Trigger**: When a tiered achievement is unlocked
- **Content**: "🎉 Achievement Unlocked! [Achievement Name] - [Tier Name]"
- **Actions**: View Achievement

### 3. Result Import Confirmations
- **Trigger**: When a result is imported via Share Extension
- **Content**: "Result Imported - Your [Game] result has been added to your streak!"
- **Actions**: None (informational)

## User Controls

### Global Settings
- **Quiet Hours**: 9 PM - 9 AM (customizable)
- **Max Daily Notifications**: 3 (customizable, 1-10 range)
- **Digest Mode**: Group multiple notifications into daily summary
- **Pause All**: Temporarily disable all notifications

### Per-Game Settings
- **Enable/Disable**: Toggle reminders for specific games
- **Preferred Time**: Custom time for each game
- **Frequency**: Daily, Weekdays Only, Weekends Only, Custom
- **Days of Week**: Custom day selection for custom frequency

## Implementation Notes

### Permission Flow
1. **No permission request on first launch** - respects user boundaries
2. **Contextual requests** - only when user enables a reminder
3. **Clear benefits** - explains value before asking
4. **Easy fallback** - direct link to system settings if denied

### Smart Scheduling
1. **Learned preferences** - adapts to user's play patterns
2. **Quiet hours respect** - never sends during sleep hours
3. **Frequency caps** - prevents notification spam
4. **Streak risk detection** - warns when streaks are at risk

### User Experience
1. **Non-intrusive nudges** - subtle suggestions, not demands
2. **Contextual placement** - appears where relevant
3. **Easy dismissal** - one-tap to dismiss or snooze
4. **Actionable notifications** - buttons to take immediate action

## Integration Examples

### Dashboard Integration
```swift
struct DashboardView: View {
    var body: some View {
        VStack {
            NotificationNudgeView() // Global nudge
            
            ForEach(games) { game in
                VStack {
                    GameCardView(game: game)
                    GameNotificationNudgeView(game: game) // Per-game nudge
                }
            }
        }
    }
}
```

### Settings Integration
```swift
struct SettingsView: View {
    var body: some View {
        List {
            NavigationLink {
                NotificationSettingsView()
            } label: {
                SettingsRow(
                    icon: "bell",
                    title: "Notifications",
                    subtitle: notificationsEnabled ? "Enabled" : "Disabled"
                )
            }
        }
    }
}
```

### Achievement Integration
```swift
// In achievement unlock handler
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

## Best Practices

1. **Always check permission status** before scheduling
2. **Respect user preferences** - honor quiet hours and frequency caps
3. **Provide clear value** - explain why the notification is helpful
4. **Make it easy to disable** - prominent settings and quick actions
5. **Test thoroughly** - ensure notifications work in all app states
6. **Monitor feedback** - track user engagement and adjust accordingly

## Future Enhancements

- **Smart learning**: Adapt reminder times based on actual play patterns
- **Streak prediction**: Warn users before streaks are at risk
- **Achievement progress**: Notify when close to unlocking achievements
- **Weekly summaries**: Digest of weekly progress and achievements
- **Focus mode integration**: Respect iOS Focus modes and notification summaries
