# Notification System

## Overview

The StreakSync notification system provides a simple, user-friendly way to get daily reminders about games with streaks at risk. The system is designed to be easy to understand and use, with minimal configuration required.

## Design Philosophy

**"One thoughtful reminder > Multiple annoying alerts"**

The notification system is built on the principle that users should receive helpful, timely reminders without being overwhelmed by notifications. Instead of multiple alerts throughout the day, users get a single, well-timed daily reminder that shows all games requiring attention.

## Core Principles

1. **Simplicity**: One notification per day maximum
2. **User Value**: Clear, actionable reminders about streak maintenance
3. **Respect**: Non-intrusive and easily customizable
4. **Reliability**: Consistent, predictable notification behavior
5. **Privacy**: All notification logic runs locally on device - no data sent to servers

## Components

### NotificationScheduler
- **Purpose**: Centralized notification scheduling and management
- **Key Features**:
  - Permission handling and status checking
  - Single daily streak reminder scheduling
  - Achievement notifications
  - Result imported notifications
  - Comprehensive cancellation methods
  - Test notification support for debugging

### NotificationDelegate
- **Purpose**: Handles notification presentation and user interactions
- **Key Features**:
  - Foreground notification presentation
  - User interaction handling (tap, action buttons)
  - Deep linking to specific game details
  - Action button responses (Play Now, Remind Tomorrow, Mark as Played)

### NotificationPermissionFlow
- **Purpose**: Guides users through the notification permission process
- **Key Features**:
  - Educational content about notification benefits
  - Permission request handling
  - Settings redirection for denied permissions

### NotificationSettingsView
- **Purpose**: Simple user interface for configuring notification preferences
- **Key Features**:
  - Enable/disable streak reminders toggle
  - Time picker for daily reminder time
  - Debug tools for testing

## Notification Types

### 1. Daily Streak Reminder
- **Trigger**: Sent once per day at user's preferred time
- **Content**: Lists all games with active streaks that haven't been played today
- **Actions**: Play Now, Remind Tomorrow, Mark as Played

### 2. Achievement Notifications
- **Trigger**: When user unlocks a new achievement
- **Content**: Achievement title and description
- **Actions**: View achievement details

### 3. Result Imported Notifications
- **Trigger**: When game results are imported via share extension
- **Content**: Confirmation of successful import
- **Actions**: View imported results

## Settings and Customization

### Simplified Settings
- **Enable Streak Reminders**: Master toggle for all streak reminders
- **Reminder Time**: Single time picker for daily reminder (default: 7 PM)

### Smart Reminders (Learning Mode)
- **Smart Toggle**: When ON, the system learns from the last 30 days of completed plays and adjusts the reminder time.
- **How it picks a time**: Builds a 24-hour histogram, finds the best 2-hour window, and sets a reminder 30 minutes before that window (clamped 06:00–22:00).
- **Recompute cadence**: At most once every 2 days (triggered on day change).
- **Smart OFF**: The user’s manual time is preserved and never auto-adjusted.

Persistence Keys
- `smartRemindersEnabled` (Bool)
- `smartRemindersLastComputed` (Date)
- `smartReminderWindowStartHour` / `smartReminderWindowEndHour` (Int)
- `smartReminderCoveragePercent` (Int)
- `streakRemindersEnabled` (Bool)
- `streakReminderHour` / `streakReminderMinute` (Int)

### How It Works
1. **Daily Check**: App checks all games with active streaks
2. **Risk Assessment**: Identifies games not played today
3. **Single Notification**: Sends one notification listing all at-risk games
4. **Smart Content**: Adapts message based on number of games at risk
5. **Smart Reminders (optional)**: If Smart is enabled, time is recomputed every ~2 days and rescheduled.

### Smart Default Time
If no history is available, default reminder time is 7 PM. With Smart enabled, the engine computes a smarter time as described above and keeps it up-to-date.

### Privacy & Data Handling
- **Local Processing**: All notification logic runs on the user's device
- **No Server Communication**: No game data or play patterns are sent to external servers
- **User Control**: Users can disable notifications or change timing at any time
- **Minimal Data**: Only stores user's preferred reminder time locally

## Technical Implementation

### Notification Categories
- **streakReminder**: Streak-related notifications with action buttons
- **achievement**: Achievement notifications with view action
- **resultImported**: Import confirmation notifications

### Action Buttons
- **Play Now**: Opens the specific game
- **Remind Tomorrow**: Schedules reminder for next day
- **Mark as Played**: Marks game as completed for today
- **View Achievement**: Opens achievement details

### Deep Linking
- **Game Details**: `streaksync://game/{gameId}`
- **Achievements**: `streaksync://achievements`
- **Settings**: `streaksync://settings`

## Benefits of Simplified System

1. **No Multiple Notifications**: Users receive maximum one notification per day
2. **Easy to Understand**: Simple on/off toggle and time picker
3. **No Per-Game Configuration**: Works automatically for all games
4. **Reliable**: Consistent behavior without complex settings
5. **User-Friendly**: Clear, actionable notifications

## Migration

The system automatically migrates from the previous complex system:
- Cleans up old notification settings
- Sets sensible defaults (enabled, 7 PM)
- Cancels all old notifications
- Schedules new simplified daily reminder

## Debug and Testing

The system includes debug tools:
- Test notification scheduling
- Current notification state logging
- Notification cleanup tools

## Best Practices

1. **Permission First**: Always check permission status before scheduling
2. **Cleanup**: Cancel old notifications before scheduling new ones
3. **User Control**: Respect user preferences and settings
4. **Testing**: Use debug tools to test notification behavior
5. **Error Handling**: Gracefully handle permission denials and errors

## Usage Examples

### Basic Setup
```swift
// Initialize in app startup
NotificationDelegate.shared.appState = appState
NotificationDelegate.shared.navigationCoordinator = navigationCoordinator
```

### Settings Integration
```swift
NavigationLink {
    NotificationSettingsView()
} label: {
    SettingsRow(
        icon: "bell",
        title: "Notifications",
        subtitle: remindersEnabled ? "Enabled" : "Disabled"
    )
}
```

### Manual Scheduling
```swift
// Schedule daily reminder
await NotificationScheduler.shared.scheduleDailyStreakReminder(
    games: gamesAtRisk,
    hour: 19,
    minute: 0
)

// Cancel all reminders
await NotificationScheduler.shared.cancelAllStreakReminders()
```

### Smart Reminder Snippets
```swift
// Enable Smart and apply immediately
Task { await appState.applySmartReminderNow() }

// Periodic recompute if needed (day change)
Task { await appState.updateSmartRemindersIfNeeded() }
```

## Future Enhancements

- (Implemented) Smart learning: see Smart Reminders section above
- **Streak prediction**: Warn users before streaks are at risk
- **Achievement progress**: Notify when close to unlocking achievements
- **Weekly summaries**: Digest of weekly progress and achievements
- **Focus mode integration**: Respect iOS Focus modes and notification summaries