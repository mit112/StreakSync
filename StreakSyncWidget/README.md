# StreakSyncWidget

WidgetKit extension for StreakSync. Source only — the Xcode target does not exist
yet, because creating it requires editing `StreakSync.xcodeproj/project.pbxproj`,
which project rules forbid. Nothing here compiles until a human adds the target.

## Adding the target

1. Xcode → File → New → Target → **Widget Extension**.
   - Product name: `StreakSyncWidget`
   - Bundle identifier: `com.mitsheth.StreakSync.StreakSyncWidget`
   - **Uncheck** "Include Live Activity" and **check** "Include Configuration
     Intent" (the single-game widget uses App Intents configuration).
   - Do not let the template keep its generated `StreakSyncWidget.swift`,
     `AppIntent.swift`, or `StreakSyncWidgetBundle.swift` — delete them and use
     the files in this directory instead.
2. Point the target at this folder (Xcode 16 synchronized folders pick the files
   up automatically once the group is added; do not hand-edit the pbxproj).
3. Deployment target: **iOS 18.6**, Swift 6, same as the app.
4. Set `MARKETING_VERSION` to match the app and the Share Extension. Apple
   rejects an extension whose `CFBundleShortVersionString` differs from the app,
   so this has to be bumped on all three targets from now on.

## Entitlement

The widget reads the published snapshot out of the shared App Group, so the
target needs exactly one entitlement:

```
com.apple.security.application-groups = [ group.com.mitsheth.StreakSync ]
```

`StreakSyncWidget.entitlements` in this directory already declares it — set
`CODE_SIGN_ENTITLEMENTS` for the new target to that file (or copy its contents
into whatever entitlements file the template generated). The App Group already
exists on the app and Share Extension provisioning profiles; no new capability
has to be registered on the developer portal.

No other capability is required. The widget makes no network calls, uses no
Firebase, and reads no Keychain.

## Required file membership from the main app

Add exactly these four existing files to the `StreakSyncWidget` target
(File Inspector → Target Membership). They are pure Foundation/UIKit/SwiftUI
value types with no I/O, no Firebase, and no `@MainActor` isolation:

| File | Why |
|---|---|
| `StreakSync/Core/Models/Shared/WidgetSnapshot.swift` | The data contract. `WidgetSnapshot`, `WidgetGameEntry`, `loadFromAppGroup()`, `rolledForward(to:)`. |
| `StreakSync/Core/Models/Shared/SharedModels.swift` | Declares `Game`, `GameCategory`, `ScoringModel`. |
| `StreakSync/Core/Models/Shared/CodableColor.swift` | `Game.backgroundColor`'s type; used for the catalog-color fallback and for sample data. |
| `StreakSync/Core/Models/Game/GameDefinitions.swift` | `Game.allAvailableGames` (the App Intents entity query) and `URL(staticString:)` (used by `WidgetDeepLink`). |

Do **not** add anything else. In particular:

- `GameCatalog` is a `@MainActor` singleton over `UserDefaults.standard` — the
  widget cannot reach the app's standard defaults at all.
- Anything under `Core/Services/` drags in Firebase.
- The `Design System/` files are app-only; the widget restates the handful of
  tokens it needs in `Support/WidgetTheme.swift` on purpose.
- `GameStreak` uses `precondition` in its initializer, which fires in Release.
  The widget never constructs one — `WidgetGameEntry` is the only streak type it
  touches.

`SharedModels.swift` pulls in `GameResult`, `GroupedGameResult`, and
`GameDetector` as dead weight. They compile fine here (both dependencies above
are in membership) and nothing in the widget calls them.

## The app side of the contract

Nothing here renders real data until the app writes the snapshot. That publisher
lives in `StreakSync/Core/State/AppState+Widget.swift` (`publishWidgetSnapshot()`
/ `buildWidgetSnapshot()`), which encodes with `WidgetSnapshot.makeEncoder()`,
writes to `UserDefaults(suiteName: "group.com.mitsheth.StreakSync")` under
`"widgetSnapshot"`, and calls `WidgetCenter.shared.reloadAllTimelines()`.

Two consequences worth knowing while testing:

- Until an install launches the snapshot-writing build **once**, every family
  renders the "No streak data yet / Open StreakSync" placeholder, whose tap
  target is `streaksync://newresult`. That is the correct state, not a bug.
- The publisher skips guest mode and review mode, so those sessions also show
  the placeholder by design.

## What shipped

**`StreakOverviewWidget`** (`StaticConfiguration`, kind
`StreakSyncStreakOverview`) — families `systemSmall`, `systemMedium`,
`accessoryCircular`, `accessoryRectangular`, `accessoryInline`.

**`SingleGameWidget`** (`AppIntentConfiguration`, kind `StreakSyncSingleGame`) —
`systemSmall` only, configured by `SelectGameIntent`.

App Intents:

- `SelectGameIntent` — `WidgetConfigurationIntent`, `isDiscoverable = false`.
- `OpenGameStreakIntent` — opens `streaksync://game?id=<uuid>` via `OpenURLIntent`.
- `GetGameStreakIntent` — returns `Int` + spoken dialog for a chosen game.

There is deliberately **no** "mark as played" intent. Results are parsed from
real share text; a synthesized `GameResult` fails `GameResult.isValid` and would
publish a fabricated score to friends' leaderboards.

## Behaviour notes

- **Timelines never poll.** Each provider emits two entries — now, and the next
  local midnight built with `rolledForward(to:)` so the day flips correctly
  without the app relaunching — and a `.after(midnight + 60s)` reload policy.
  The shared policy lives in `Support/WidgetTimelinePlan.swift`.
- **Deep links need no main-app change.** The `streaksync` scheme is already
  registered in `StreakSync/Info.plist` and routed by
  `AppGroupURLSchemeHandler`, which reads the literal query key `id`.
- **Tap targets.** `Link` only resolves in `systemMedium`/`systemLarge`, so the
  medium family gives each chip its own `Link` and everything else uses
  `widgetURL`. `accessoryRectangular` targets the most urgent game;
  `accessoryCircular` and `accessoryInline` open the app.
- **Monochrome families.** Accessory widgets and tinted Home Screen mode render
  in `.accented`/`.vibrant`, never `.fullColor`. Every view reads
  `\.widgetRenderingMode` and drops the per-game color rather than letting the
  system flatten it into mush.
- **No animation anywhere.** A widget redraws on a timeline, not on interaction,
  so there is nothing to animate and therefore no `accessibilityReduceMotion`
  branch to maintain.
- **Accessibility.** Every numeric readout is wrapped in a sentence
  (`"Wordle, 14 day streak. Streak at risk."`); no bare number is exposed.
  Chips carry a hint naming the destination. The medium family drops from six
  chips to four at accessibility text sizes instead of clipping the last row.
