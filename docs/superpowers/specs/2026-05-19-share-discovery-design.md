# Share-Sheet Discovery — Design Spec

**Date:** 2026-05-19
**Status:** Draft — pending user review
**Owner:** Mit

---

## Problem

Sharing a game result from Wordle/NYT Games/etc. into StreakSync via the iOS share sheet is the app's primary input mechanism — it is *the* way users record streaks. Today, nothing in-app meaningfully teaches that flow:

- There is no first-launch onboarding of any kind.
- The only existing pointer is `EmptyStateGuidanceCard` on the Dashboard, whose copy ("Tap any game and share your results to start tracking") is ambiguous about *where* the share happens (inside the game, not inside StreakSync).
- Active users figured it out, but new installs and existing users with zero results have no path of discovery.

The cost is silent: users install, open the app, see a grid of game tiles, see no obvious next step, and leave. Crashlytics/analytics won't surface this because nothing crashed — they just churned.

## Goals

1. Teach new users (and existing users with zero results) the share-sheet flow on their next qualifying launch.
2. Reinforce the loop with a celebration when the user successfully shares their first result.
3. Keep the existing surface (`EmptyStateGuidanceCard`) but tighten its copy so it points to the right mechanic.
4. Provide a re-access path from Settings, so a user who dismissed the sheet can re-open it.

## Non-Goals (explicitly out of scope)

- Multi-page onboarding carousel (introducing achievements, friends, etc.). Those are best discovered organically.
- "Try it now" deep-link mechanics (opening Wordle from inside StreakSync). Considered, rejected — depends on the user actually playing a game; engineering weight is too high for the value.
- Tutorial for enabling StreakSync in the share sheet's "More" menu. StreakSync's extension appears by default in iOS 17+; revisit only if data shows users hitting the More-menu hidden-extension problem.
- Re-prompting lapsed users ("you haven't shared in N days"). No nags.
- Animated walkthrough video. A single, static, well-crafted iPhone mockup of the share sheet is enough.

---

## Surface 1 — First-Launch Teaching Sheet

A single full-screen modal sheet that appears the first time a qualifying user lands on the Dashboard.

### Trigger

Fires from `ImprovedDashboardView.onAppear` when **both** conditions hold:

- `AppState.recentResults.count == 0` (the user has never logged a result), and
- `UserDefaults.standard.bool(forKey: "hasSeenShareOnboarding") == false`

Once shown, `hasSeenShareOnboarding` is set to `true` on dismiss. Never re-shown automatically.

The trigger lives on the Dashboard, not at `StreakSyncApp` root, because root-level presentation feels jarring before the user has even seen the app's primary surface.

### Content (single page)

- **Visual:** An iPhone mockup at the top, illustrating a finished Wordle puzzle with the iOS share sheet half-presented underneath. The StreakSync app icon in the share sheet pulses/glows to direct attention. The mockup should reuse StreakSync's actual icon and brand colors to make the recognition cue clear.
- **Headline:** "Save your streak in 3 taps."
- **Body:** "Finish a game in Wordle (or any of 16 supported games). Tap **Share**, then pick **StreakSync**. We'll record the result automatically."
- **CTA:** Single primary button — "Got it." On tap, sets the flag, dismisses, returns user to Dashboard.

No "skip" or "remind me later." One button — dismiss.

### Audience

- New installs (zero results, flag absent).
- Existing users currently sitting at zero results when this ships (covered by the same condition — they qualify automatically).
- Users who have ≥1 result never see it (they figured it out).

### Re-access

Settings → "How StreakSync works" row. On tap, presents the same sheet. No flag check, no flag mutation — always available.

### Implementation hooks

- **New view:** `StreakSync/Features/Onboarding/Views/ShareDiscoverySheet.swift` (new folder `Features/Onboarding/`).
- **Trigger added to:** `ImprovedDashboardView.swift` — a `@State` for presentation, a check in `.onAppear`, and a `.sheet(isPresented:)` modifier.
- **Settings entry added to:** `SettingsView.swift` — new row routing to the same sheet.

### Persistence key

- `UserDefaults` key: `"hasSeenShareOnboarding"` (Bool). Stored in standard `UserDefaults` (not App Group — this is main-app-only UX state).
- No Firestore mirror. The teaching is per-device, per-install; if the user reinstalls, re-teaching them is fine.

---

## Surface 2 — First-Share Celebration

A confetti toast that fires when a user shares their first result ever.

### Trigger

Inside `AppState.addGameResult` (in `AppState+ResultAddition.swift`), immediately after the result is successfully inserted and before async save work:

- If, before this insertion, `recentResults.count == 0` (i.e., this is going from 0 → 1), AND
- `UserDefaults.standard.bool(forKey: "hasSeenFirstShareCelebration") == false`,

then post a new notification — `.firstShareCelebrationRequested` with the inserted `GameResult` as payload — and set the flag.

This computation must happen *before* the `recentResults.insert(result, at: 0)` call (otherwise count is no longer 0). Capture the pre-insert count in a `let`.

Guest Mode is excluded (consistent with existing `isGuestMode` gating on streak/achievement updates).

### View

A new SwiftUI overlay component, `FirstShareCelebrationOverlay`, mounted at the root of the main app shell (likely `MainAppView` or wherever the Dashboard sits in the navigation hierarchy). It listens for `.firstShareCelebrationRequested` via the existing `NotificationCoordinator` pattern.

- **Animation:** Native SwiftUI confetti. Use `TimelineView` + `Canvas` to draw ~30–50 particle paths falling from the top with random horizontal velocity and rotation. ~50 lines of SwiftUI, no SPM dependency. Particles fade out at ~2.5s.
- **Banner:** A small horizontal pill near the top safe area: "🎉 First streak started! [Game Name]". Auto-dismisses ~3s.
- **Haptic:** `HapticManager.shared.trigger(.success)` (already used elsewhere in the project) on appear.

### Persistence key

- `UserDefaults` key: `"hasSeenFirstShareCelebration"` (Bool).
- One-shot: if user later wipes data and starts over, the celebration does *not* re-fire. (Avoids a re-celebration loop on data-management resets.)

---

## Surface 3 — Existing Empty-State Card Copy Update

The current `EmptyStateGuidanceCard` text ("Tap any game and share your results to start tracking") is ambiguous about where the share happens. Update wording to be unambiguous about the mechanic.

### New copy

**New user variant (current title: "Start Your First Streak!"):**
- Title: unchanged — "Start Your First Streak!"
- Message: "Finish a Wordle. Tap **Share** inside the game, then pick **StreakSync**."

**Returning user variant (current title: "Reignite Your Streaks!"):**
- Title: unchanged — "Reignite Your Streaks!"
- Message: "Play a quick game. Tap **Share**, then **StreakSync** to log it."

Bolding can be applied via `AttributedString` in SwiftUI. Plain text fallback is also acceptable if AttributedString is awkward — the wording itself is the win.

### Implementation hooks

- File: `StreakSync/Features/Dashboard/Views/EmptyStateGuidanceCard.swift`
- Update the `cardContent` computed property's `message` strings only. No structural changes.

---

## Component Inventory

| Component | New/Modified | File |
|---|---|---|
| `ShareDiscoverySheet` | New | `StreakSync/Features/Onboarding/Views/ShareDiscoverySheet.swift` |
| `ShareSheetMockup` (sub-view of the sheet) | New | same file, or sibling file in the same folder |
| `FirstShareCelebrationOverlay` | New | `StreakSync/Features/Onboarding/Views/FirstShareCelebrationOverlay.swift` |
| `ConfettiView` (Canvas-based particle system) | New | `StreakSync/Features/Onboarding/Views/ConfettiView.swift` |
| `ImprovedDashboardView` | Modified | existing — add trigger + sheet presentation |
| `AppState+ResultAddition` | Modified | existing — detect 0→1 transition, post notification |
| `NotificationCoordinator` / notification name constants | Modified | existing — add `.firstShareCelebrationRequested` |
| Root shell (likely `RootView` / `MainAppView`) | Modified | existing — mount `FirstShareCelebrationOverlay` to receive the notification |
| `SettingsView` | Modified | existing — add "How StreakSync works" row |
| `EmptyStateGuidanceCard` | Modified | existing — copy update only |

Estimated net new lines: ~250–350. Estimated touched files: 6 modified, 3 new.

---

## State & Persistence

Two `UserDefaults` keys, both Bool, both stored in standard `UserDefaults`:

| Key | Initial | Set when |
|---|---|---|
| `hasSeenShareOnboarding` | `false` | User dismisses the teaching sheet via "Got it" (not when re-opened from Settings). |
| `hasSeenFirstShareCelebration` | `false` | First successful `addGameResult` call that takes count 0 → 1 (host mode only). |

Both keys should be added to `AppConstants` if there's a precedent for UserDefaults key constants there — verify during implementation. (`grep` for `UserDefaults.standard.bool(forKey:` patterns to match convention.)

Neither flag is mirrored to Firestore. They are device-local UX state.

---

## Data Flow

### Teaching sheet
1. App launches → user reaches Dashboard.
2. `ImprovedDashboardView.onAppear` fires.
3. Check: `recentResults.count == 0 && !hasSeenShareOnboarding`.
4. If true, set `@State` for `isShowingOnboarding = true`.
5. `.sheet(isPresented: $isShowingOnboarding)` presents `ShareDiscoverySheet`.
6. User taps "Got it" → `UserDefaults` flag set → sheet dismissed.

### First-share celebration
1. User shares result from Wordle → Share Extension writes to App Group → main app wakes → `AppState.addGameResult` invoked on `@MainActor`.
2. Inside `addGameResult`, before `recentResults.insert`, capture `let wasFirstResult = !isGuestMode && recentResults.count == 0 && !UserDefaults.standard.bool(forKey: "hasSeenFirstShareCelebration")`.
3. Insert continues as normal.
4. After successful insert (in the existing `postResultAddedNotifications` block, or directly after), if `wasFirstResult`, post `.firstShareCelebrationRequested` with the result payload, then set `hasSeenFirstShareCelebration = true`.
5. Root view's `FirstShareCelebrationOverlay` receives the notification → triggers confetti + banner → auto-dismisses after ~3s.

The notification fires *after* the existing `gameResultReceived` notification, so any other UI (toast, badge update, animation) sequences naturally. The celebration is purely additive.

---

## Edge Cases

- **User dismisses sheet, then deletes all data via Data Management.** Flag remains true; sheet won't reshow automatically. User can reopen from Settings if they want a refresher. This is intentional — they explicitly opted out by dismissing.
- **User shares before opening main app at all.** The Share Extension can record results without the main app ever being opened. When the main app is eventually launched, `recentResults.count` will be ≥1, so the teaching sheet won't show, and the first-share celebration will *not* fire either (the celebration only fires inside `addGameResult` in the main app process). This is correct — the user already proved they know the mechanic.
- **User is in Guest Mode.** Teaching sheet still shows (Guest mode users are exactly the audience). First-share celebration is skipped (matches existing pattern of Guest-mode gating).
- **User has 0 results because Firestore sync is still loading.** `recentResults` is populated from local UserDefaults at app launch, before any network. The sheet trigger fires on Dashboard `.onAppear` *after* `AppState` initialization, so if local data has results, they're already in `recentResults`. Edge case: a user who only ever played via the cloud-sync side (rare) might briefly see the sheet during a slow first sync. Acceptable.
- **Confetti animation on iPad / Mac Catalyst.** Out of scope — StreakSync is iOS-only per `CLAUDE.md`. No special handling needed.
- **Accessibility.** Confetti overlay must respect `Reduce Motion` (`@Environment(\.accessibilityReduceMotion)`). If true, skip the particle animation but still show the banner + haptic. The teaching sheet's pulsing share-icon animation should also respect Reduce Motion.

---

## Testing

- **Unit:** `AppState+ResultAdditionTests` — add a test verifying that the `firstShareCelebrationRequested` notification is posted exactly once on the 0→1 transition, and that subsequent additions do not re-post.
- **Unit:** Persistence test that the `hasSeenFirstShareCelebration` flag is set correctly.
- **UI / Snapshot (if existing infra supports it):** Render `ShareDiscoverySheet` at typical Dynamic Type sizes; confirm the iPhone mockup scales.
- **Manual smoke test:**
  1. Fresh install → open app → confirm sheet appears, dismiss.
  2. Share a Wordle result → confirm confetti + banner.
  3. Share a second result → confirm no celebration.
  4. Settings → "How StreakSync works" → confirm sheet re-opens.

---

## Open Questions

None. All design decisions are settled.

## Anti-Goals / Things We Considered and Rejected

- **Animated GIF/video walkthrough.** Maintenance burden; static mockup with a single pulsing-icon animation is enough.
- **"Open Wordle now" deep-link.** Adds engineering weight, depends on user actually playing. Discussed and dropped.
- **Multi-page carousel.** Discussed and dropped — single concept doesn't need multiple pages.
- **Bottom sheet / inline card-only.** Discussed and dropped — full-screen sheet is the right weight for a once-per-install moment.

---

## Acceptance Criteria

1. A new user installing the app sees the teaching sheet on their first Dashboard appearance.
2. An existing user with 0 results sees the teaching sheet on their next Dashboard appearance after the update ships.
3. A user who shares a result for the first time (count goes 0 → 1) sees confetti and a banner.
4. The teaching sheet never auto-fires twice for the same user.
5. The celebration never fires twice for the same user.
6. Settings has a "How StreakSync works" row that re-opens the teaching sheet.
7. `EmptyStateGuidanceCard`'s message clearly references "tap Share inside the game."
8. All UI respects Reduce Motion accessibility setting.
