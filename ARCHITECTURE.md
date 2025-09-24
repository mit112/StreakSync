StreakSync Architecture Overview

Layers
- App entry: `StreakSync/App` bootstraps the app, requests permissions, and injects the `AppContainer`.
- Dependency container: `AppContainer` wires all services (state, navigation, notifications, sync, design system singletons).
- State: `Core/State/AppState*` holds domain data (games, streaks, results, achievements) and coordinates persistence, streak logic, and achievements.
- Persistence: `Core/Services/Persistence` (UserDefaults/App Group JSON) with ISO8601 dates.
- Sync & Deep Links: `Core/Services/Sync` bridges the Share Extension, Darwin notifications, and `streaksync://` URL scheme.
- Navigation: `Core/Services/Navigation` provides tabbed stacks and routing helpers.
- Design System: `Design System/*` defines colors, haptics, animations.

Key flows
- Share → App: Share Extension saves to App Group → `AppGroupBridge` detects → `NotificationCoordinator` → `AppState.addGameResult` → UI refresh.
- Deep links: `AppGroupURLSchemeHandler` parses scheme and posts typed payloads → `NotificationCoordinator` navigates.
- App lifecycle: `StreakSyncApp.initializeApp()` loads state once; `AppContainer` forwards lifecycle to services.

Decisions
- Duplicate achievement helpers removed from `AppState+GameLogic`; single source lives in `AppState+TieredAchievements`.
- URL payload keys centralized under `AppConstants.DeepLinkKeys`.
- Notification names exposed as typed `Notification.Name` static constants.
- Avoid `UserDefaults.synchronize()` for performance; rely on the system.

