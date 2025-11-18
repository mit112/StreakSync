## Account & Identity Model

- One StreakSync account per **iCloud Apple ID**:
  - All CloudKit-backed data (game results, streaks, tiered achievements, leaderboard scores) is scoped to the Apple ID signed into iOS.
  - There is no in-app login/logout; to use a different account, the user changes the iCloud account in iOS Settings.
- Private database:
  - Container: `iCloud.com.mitsheth.StreakSync2` as configured in `CloudKitConfiguration` and the app entitlements.
  - Custom zones:
    - `AchievementsZone` for the single `UserAchievements` record (tiered achievements sync via `AchievementSyncService`).
    - `UserDataZone` for per-result `GameResult` records (synced via `UserDataSyncService`).
- Shared database:
  - CKShare-based leaderboard groups using `LeaderboardGroup` and `DailyScore` records per friend group.
- Account changes & privacy:
  - The app listens for `CKAccountChanged` and compares the current `userRecordID.recordName` with the last seen value.
  - On a real Apple ID change, local data is cleared, sync tokens/queues are reset, and data for the new account is fetched from CloudKit.
  - This ensures data from one Apple ID is never shown when another Apple ID is signed in.
- Guest Mode:
  - A local-only mode that lets someone temporarily use StreakSync without syncing their data to iCloud.
  - While Guest Mode is active, CloudKit sync and leaderboard publishing are disabled and host data is kept isolated.

## Analytics Definitions (Source of Truth)

- Time ranges
  - today = start of day → now
  - week = last 7 days, month = last 30, quarter = 90, year = 365
- Streak consistency
  - Percentage of days within selected time range that have ≥1 result
- Completion rate
  - Completed results ÷ total results within time range
- Scoring models
  - lowerAttempts: fewer attempts is better (Wordle, Nerdle)
  - lowerTimeSeconds: lower time is better (Mini, Pips, LinkedIn Zip/Tango/Queens/Crossclimb)
  - lowerGuesses: fewer guesses is better (Pinpoint)
  - lowerHints: fewer hints is better (Strands)
  - higherIsBetter: larger value is better (e.g., Spelling Bee)
- Personal best
  - Uses scoring model semantics; where lower is better we take the minimum completed score
- Weekly summary
  - Group by ISO week, compute total/completed, average streak length (current streak average), longest streak (all-time), completion rate, and consistency (active days/7)
- Achievements analytics
  - Totals from basic achievements
  - Tier distribution and recent unlocks from tiered achievements’ progress
  - Category progress: fraction of tiered achievements per category with any unlocked tier



## Social: Friends & Leaderboard

Architecture
- Social service abstraction `SocialService` defines profile, friends, publish, and leaderboard APIs.
- `HybridSocialService` selects CloudKit when available, else local `MockSocialService`.
- `CloudKitSocialService` is compile-gated; when enabled, uses Private DB and subscriptions.

Scoring & Aggregation
- Centralized in `Core/Models/Social/LeaderboardScoring.swift` mapping `Game.scoringModel` to normalized points.
- Points are per-game, positive (higher is better) and comparable within the game page.
- UI labels are game-aware (attempts, hints, time buckets, or points).

UI & View Models
- `FriendsViewModel` in `Features/Friends/ViewModels` manages state, persistence, and refresh.
- `FriendsView` renders per-game pages and exposes Manage Friends.
- `FriendManagementView` supports copying/sharing your code and adding friends by code.

Real-time
- When CloudKit is available, `HybridSocialService` enables periodic refresh and CK subscriptions.
- Today view shows rank delta vs yesterday for added engagement.

Enablement Plan
- Works fully offline/local now.
- Add Apple Developer account, enable CloudKit capability, and real-time sync will activate without code churn.

