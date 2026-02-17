# Firebase Social Refactor Plan

## Goal

Reduce coupling in `FirebaseSocialService` and remove direct singleton usage outside `AppContainer` so dependencies are explicit, mockable, and easier to evolve.

## Current Pain Points

- `FirebaseSocialService` owns profile, friendships, leaderboard queries, pending score retries, and listener setup.
- `HapticManager.shared`, `NotificationScheduler.shared`, `GameCatalog.shared`, and related singletons are called from many feature files.
- Testing critical flows requires concrete Firebase and global state.

## Target Shape

- `AppContainer` remains the composition root.
- Social domain split into smaller services:
  - `ProfileService`
  - `FriendshipService`
  - `LeaderboardService`
  - `ScorePublishService`
- `SocialService` becomes a facade that coordinates specialized services.
- UI and state layers consume protocols, not `.shared` singletons.

## Phase 1: Extract Interfaces (Low Risk)

1. Create protocol contracts for each social responsibility.
2. Add adapter types around singleton dependencies (`HapticClient`, `NotificationScheduling`, `GameCatalogProviding`).
3. Update `AppContainer` to build concrete adapters and inject them.
4. Keep behavior unchanged while replacing direct `.shared` usage in high-traffic paths.

## Phase 2: Split FirebaseSocialService (Medium Risk)

1. Move profile and friend-code methods into `FirebaseProfileService`.
2. Move friendship methods and backfill helpers into `FirebaseFriendshipService`.
3. Move leaderboard reads into `FirebaseLeaderboardService`.
4. Move score publish + flush/retry into `FirebaseScorePublishService`.
5. Keep existing `SocialService` API stable by delegating internally.

## Phase 3: Isolation and Concurrency Cleanup (Medium Risk)

1. Restrict `@MainActor` to state mutation boundaries.
2. Keep pure Firestore query and parse operations nonisolated where safe.
3. Add deterministic retry/backoff policy for pending score flush.
4. Add per-service log categories for clearer production observability.

## Phase 4: Testability and Contract Tests (High Value)

1. Add fake protocol implementations for each new service.
2. Add integration tests for:
   - friend request lifecycle
   - score publish + pending queue flush
   - leaderboard aggregation and visibility
3. Add regression tests for listener cancellation and first-snapshot behavior.

## Definition of Done

- No direct `.shared` references outside composition root for migrated dependencies.
- `FirebaseSocialService` reduced to orchestration facade with focused collaborators.
- New tests cover critical social/sync flows without live Firebase dependencies.
- Public architecture docs match implementation boundaries.
