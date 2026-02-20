# Notification Runtime Device Shakedown

Date: 2026-02-17  
Scope: Real-device runtime validation for notification delivery behavior under permission and timezone/clock changes.

## Why this exists

Unit tests now cover DST-safe date computation. This runbook covers the remaining runtime risks that require actual device behavior:

- permission prompt and denied/re-enabled flows
- background delivery timing
- timezone and clock mutation effects on scheduled notifications
- deep-link/action handling from delivered notifications

## Prerequisites

- Physical iPhone with latest iOS supported by current build
- StreakSync debug build installed
- Notification permission reset for StreakSync before starting
- At least one game with an active streak for realistic reminder content

## Device matrix

- Timezones:
  - `America/Los_Angeles` (DST-observing baseline)
  - `America/New_York` (DST-observing alternate)
  - `Asia/Kolkata` (non-DST control)
- Permission states:
  - not determined
  - denied
  - authorized
- App states:
  - foreground
  - background (screen on)
  - background (screen off/locked)

## Test cases

1. **Permission prompt path (not determined -> allow)**
   - Open `Settings -> Notifications` in app.
   - Tap enable; accept system prompt.
   - Expected:
     - app shows enabled state and reminder controls
     - no crashes or stuck permission sheet

2. **Denied path and recovery**
   - Deny notifications in system settings.
   - Re-open app notification settings.
   - Expected:
     - disabled/denied UI appears
     - path to system settings is available
   - Re-enable in system settings and re-open app.
   - Expected:
     - app reflects authorized state without restart issues

3. **Daily reminder schedule integrity**
   - Set reminder time to current time +2 minutes.
   - Background app.
   - Expected:
     - one reminder arrives near selected local time
     - content matches active at-risk games

4. **Snooze action runtime behavior**
   - From a delivered reminder, tap `Remind Tomorrow`.
   - Expected:
     - one-off reminder is scheduled
     - daily repeating reminder is not permanently lost (next day schedule still active)

5. **Timezone change while reminders exist**
   - With reminders scheduled, change timezone (e.g. LA -> New York).
   - Keep same local reminder preference.
   - Expected:
     - reminder remains aligned to local clock expectation
     - no duplicate notifications appear

6. **DST boundary sanity (if date window allows)**
   - Around DST transition date:
     - spring-forward: verify no crash/missed schedule loop around nonexistent hour
     - fall-back: verify no duplicate delivery from ambiguous hour

7. **Notification tap/action deep-link checks**
   - Tap delivered notification body and `Play Now`.
   - Expected:
     - app opens and navigates to intended game context
     - no stale navigation loop or incorrect destination

## Evidence capture template

For each run:

- device + iOS version
- timezone
- permission state
- reminder time
- app foreground/background state
- observed delivery timestamp
- action taken
- pass/fail + notes

## Exit criteria

- All core cases pass in at least two distinct timezones.
- No duplicate deliveries or dropped daily schedule after snooze.
- Deep-link actions consistently route correctly from notification interactions.
