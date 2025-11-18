## CloudKit Implementation Reference

This document is the source of truth for our CloudKit/iCloud implementation. It captures our architecture, schemas, subscriptions, identity model, error handling, initialization flows, entitlements, schema promotion, testing, retry/queue, migration/rollback, and recommended file layout — aligned to our current codebase and planned features.

### 1) Architecture Overview

ASCII Diagram

```
                       iCloud Container: iCloud.com.mitsheth.StreakSync2
                                     (Development | Production)
┌─────────────────────────────────────────────────────────────────────────────┐
│                             Private Database                                 │
│                                                                             │
│  ┌─────────────── AchievementsZone (custom) ────────────────┐               │
│  │  Record: UserAchievements                                │               │
│  │  - version:Int64                                         │               │
│  │  - payload:Bytes (JSON [TieredAchievement])              │               │
│  │  - lastUpdated:Date                                      │               │
│  │  - summary:Bytes ([AchievementCategory:String:Int])      │               │
│  │  Subscription: CKRecordZoneSubscription (silent push)    │               │
│  └──────────────────────────────────────────────────────────┘               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                              Shared Database                                 │
│                                                                             │
│  ┌──────────── LeaderboardGroup Zone (shared per group) ─────────────┐      │
│  │  Root Record: LeaderboardGroup (share anchor)                     │      │
│  │    - title:String                                                 │      │
│  │    - createdBy:Reference (owner)                                  │      │
│  │    - createdAt:Date                                               │      │
│  │                                                                   │      │
│  │  Records: DailyScore (many)                                       │      │
│  │    - id: "{userId}|{yyyyMMdd}|{gameId}"                           │      │
│  │    - userId:String (ownerRecordID.recordName)                     │      │
│  │    - dateInt:Int64 (UTC yyyymmdd)                                 │      │
│  │    - gameId:String (UUID string)                                  │      │
│  │    - gameName:String                                              │      │
│  │    - score:Int64?                                                 │      │
│  │    - maxAttempts:Int64                                            │      │
│  │    - completed:Boolean                                            │      │
│  │    - updatedAt:Date (conflict resolution)                         │      │
│  │  Subscription: CKRecordZoneSubscription (silent push)             │      │
│  └───────────────────────────────────────────────────────────────────┘      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

Flow
- Achievements: App pulls/merges/pushes one UserAchievements record in Private DB (AchievementsZone). Zone subscription enables real-time updates if enabled.
- Leaderboards: Each friend group has its own shared zone. Members write/read DailyScore in that zone. Zone subscription drives near real-time refresh.
- Operations: Zone creation, record CRUD, share creation/acceptance, zone subscriptions, background silent push handling with fallback to manual/periodic refresh.
```

### 2) CloudKit Containers & Databases
- Container ID: `iCloud.com.mitsheth.StreakSync2`
- Databases used:
  - Private Database (achievements; one record per user)
  - Shared Database (leaderboards via CKShare; one shared zone per group)
  - Public Database (reserved for future discovery; not MVP)
- Environments:
  - Development: during local device testing (schema evolves here)
  - Production: required for TestFlight and App Store builds

### 3) Zone Definitions

AchievementsZone (Custom Private Zone)
- Zone ID: `"AchievementsZone"`
- Purpose: Store the user’s achievements with optional real-time sync via zone subscription
- Created: On first successful achievements sync
- Deleted: Never (user data)
- Records: `UserAchievements`
- Subscription: `CKRecordZoneSubscription` (silent push)

LeaderboardGroup Zones (Custom Shared Zones)
- Zone ID format: `"leaderboard_{groupUUID}"`
- Purpose: One shared zone per friend group for shared scores
- Created: When user creates a new leaderboard group
- Shared via: `CKShare` of the `LeaderboardGroup` record (root)
- Records: `LeaderboardGroup` (1), `DailyScore` (many)
- Deleted: When owner deletes group OR all participants leave
- Subscription: `CKRecordZoneSubscription` per zone

### 4) Record Type Schemas

UserAchievements
- Record Type: `"UserAchievements"`
- Zone: AchievementsZone (custom private)
- Record ID: `"user_achievements"` (constant)
- Fields:
  - `version: Int64` — schema version (currently 1)
  - `payload: Bytes` — JSON-encoded `[TieredAchievement]` (matches our app models)
  - `lastUpdated: Date` — last modification timestamp
  - `summary: Bytes` — keyed archive of `[String: Int]` (AchievementCategory.rawValue → unlocked count)
- Indexes: None (single record per user)
- Security: Private (owner only)

LeaderboardGroup
- Record Type: `"LeaderboardGroup"`
- Zone: LeaderboardGroup zone (shared)
- Record ID: `"group_{UUID}"` (generated at creation)
- Fields:
  - `title: String` — group name (e.g., “MIT’s Friends”)
  - `createdBy: Reference` — reference to owner’s user record
  - `createdAt: Date`
  - `description: String?` — optional, future use
- Indexes: None
- Security: Shared (via CKShare); parent/root for sharing

DailyScore
- Record Type: `"DailyScore"`
- Zone: Same shared zone as parent `LeaderboardGroup`
- Record ID: `"{userId}|{yyyyMMdd}|{gameId}"` (idempotent composite)
- Fields:
  - `userId: String` — owner recordID.recordName (fetch once via `CKContainer.fetchUserRecordID`)
  - `dateInt: Int64` — UTC yyyyMMdd (e.g., 20250101)
  - `gameId: String` — UUID string
  - `gameName: String`
  - `score: Int64?`
  - `maxAttempts: Int64`
  - `completed: Boolean`
  - `updatedAt: Date` — used for conflict resolution
- Indexes (recommended):
  - By `dateInt` (fetch “today”)
  - By `userId` (user history)
- Security: Shared (read/write for group members)
- Parent: Reference to `LeaderboardGroup` (enables cascade delete)

### 5) Subscription Definitions

AchievementsZone Subscription
- Subscription ID: `"achievements_zone_sub"`
- Type: `CKRecordZoneSubscription`
- Zone: AchievementsZone
- Notification: Silent push
- Created: On first successful achievements sync
- Deleted: Never (unless feature disabled)
- Delivery handling: Background silent push → refresh achievements

LeaderboardGroup Zone Subscriptions
- Subscription ID: `"leaderboard_{groupId}_sub"`
- Type: `CKRecordZoneSubscription`
- Zone: Group’s shared zone
- Notification: Silent push
- Created: After accepting share / joining group
- Deleted: When leaving group
- Delivery handling: Background silent push → refresh that leaderboard
- Important: Approx. 20 subscriptions per DB limit; manage membership count accordingly

### 6) User Identity & Display Names

Within CKShare Groups
```swift
// Participant display names from the CKShare
for participant in share.participants {
    let identity = participant.userIdentity
    let name = identity.nameComponents?.formatted() ?? "Unknown"
    // Use this for leaderboard display
}
```

For `DailyScore.userId` (stable per account, tied to the current iCloud Apple ID)
```swift
// Fetch owner's record ID and cache its recordName for userId
let container = CKContainer.default()
let ownerRecordID = try await container.userRecordID()
let currentUserId = ownerRecordID.recordName
```

Future (not MVP): `UserProfilePublic` in Public DB (for vanity codes/discovery only)
- Fields: `displayName`, `friendCode`, `createdAt`
- Keep minimal; not needed for CKShare-based leaderboards

### 7) Sync Status State Machine
States
- `idle` — Not syncing, no recent sync
- `syncing` — Operation in progress
- `success(lastSyncedAt: Date)` — Last successful sync time
- `error(message: String)` — Fatal error details

Transitions
- `idle → syncing`: User enables sync OR app launch with sync enabled
- `syncing → success`: CloudKit operation completes successfully
- `syncing → error`: Fatal error (notAuthenticated, quotaExceeded)
- `syncing → syncing`: Transient error, retry with backoff
- `error → syncing`: User fixes issue (signs into iCloud), retry
- `success → syncing`: Next sync cycle triggered

UI Representation
- Settings shows state:
  - Success: “Last synced: 2 minutes ago”
  - Error: “iCloud sync paused: Sign into iCloud”
  - Syncing: Optional activity indicator

### 8) Error Handling Matrix

| CKError                   | User Message                                | Code Action                                 | Retry |
|---------------------------|---------------------------------------------|----------------------------------------------|-------|
| notAuthenticated          | “Sign into iCloud to sync”                  | Set error status; stop                       | No    |
| networkUnavailable        | “Offline - will sync when connected”        | Backoff retry                                | Yes   |
| serviceUnavailable        | (silent)                                     | Backoff retry                                | Yes   |
| requestRateLimited        | (silent)                                     | Backoff retry (longer delay)                 | Yes   |
| quotaExceeded             | “iCloud storage full - sync paused”         | Pause writes; set error status               | No    |
| zoneNotFound              | (silent)                                     | Create zone; retry once                      | Yes   |
| unknownItem               | (silent)                                     | Bootstrap record; retry                      | Yes   |
| serverRecordChanged       | (silent)                                     | Fetch/merge; retry save                      | Yes   |
| partialFailure            | Depends on sub-errors                       | Inspect per-item errors                      | Per   |
| permissionFailure         | “Access removed from group”                 | Remove membership; clean local caches        | No    |
| other                     | “Sync error: …”                             | Log; set error status                        | No    |

Backoff schedule
- Start: 1s → multiply ×2 up to max 60s; reset on success

### 9) Initialization Sequences

First Launch — Achievements Setup
```
1. User enables “iCloud Sync” toggle in Settings
2. Check CKContainer.accountStatus()
   - If not .available: set status error; stop
3. Create AchievementsZone (CKRecordZone) if missing
4. Create CKRecordZoneSubscription for AchievementsZone (id: achievements_zone_sub)
5. Initial pull: fetch UserAchievements
   - If not found: proceed; will create on first push
6. Merge with local tiered achievements
7. Push merged result to CloudKit
8. Set sync status = success(Date())
```

Creating a Leaderboard Group (Owner)
```
1. User enters group name and taps “Create”
2. Generate groupId = UUID()
3. Create zone: "leaderboard_{groupId}"
4. Create LeaderboardGroup record in that zone (root/shareable)
5. Create CKShare for LeaderboardGroup; present UICloudSharingController
6. Create CKRecordZoneSubscription (id: "leaderboard_{groupId}_sub")
7. Owner sees group locally
```

Accepting a Share (Recipient)
```
1. User taps iCloud share link
2. System delivers share metadata to app
3. App runs CKAcceptSharesOperation with metadata
4. On success:
   a. Shared zone available in Shared DB
   b. Fetch LeaderboardGroup (title, owner)
   c. Fetch existing DailyScore
   d. Create zone subscription: "leaderboard_{groupId}_sub"
   e. Confirm “Joined [group name]” and navigate
```

Background Notification Handling
```
1. CloudKit sends silent push for zone changes
2. App receives in didReceiveRemoteNotification
3. Extract zoneID from CKNotification
4. If AchievementsZone: fetch changed records, merge, update UI if foreground
5. If leaderboard zone: fetch changed DailyScore, update UI for that group
6. Call the completion handler
```

### 10) Entitlements & Capabilities Checklist
Xcode
- Target: StreakSync → Signing & Capabilities
  - Add iCloud capability → enable CloudKit
  - Select container: `iCloud.com.mitsheth.StreakSync2`
  - Add Background Modes → Remote notifications (for subscriptions)

Entitlements (app)
```xml
<key>com.apple.developer.icloud-services</key>
<array>
    <string>CloudKit</string>
</array>
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.com.mitsheth.StreakSync2</string>
</array>
```

Share Extension
- App Group only (no CloudKit) unless it will directly use CloudKit APIs

### 11) Schema Promotion Workflow
1) Build/run on a physical device (Development environment)
2) Perform actions that create records:
   - Enable sync (AchievementsZone + UserAchievements)
   - Create a test leaderboard (shared zone + LeaderboardGroup + DailyScore)
3) CloudKit Dashboard: `https://icloud.developer.apple.com/dashboard`
4) Select container → Schema → Development
5) Review record types, fields, indexes
6) Click “Deploy Schema Changes” to Production
7) Wait for deployment to complete (1–5 minutes)
8) Verify Production schema matches
9) Archive a Release build (Production env) and upload to TestFlight
Important: TestFlight uses the Production database.

### 12) Testing Scenarios Checklist

Basic Sync
- Enable on Device A → achievements upload
- Enable on Device B → achievements download and merge
- Unlock on A → appears on B (if subscriptions enabled) or on next sync
- Offline on A → sync when back online

Multi-Device Edge Cases
- Same achievement unlocked offline on two devices → merge keeps higher progress; union of tier unlocks
- Conflicting progress (5 vs 7) → 7 wins; lastUpdated respected

iCloud Account Status
- Not signed in → status shows guidance; stop sync
- Sign out while running → error; stop sync; resume on sign-in
- Switch accounts → independent data per account

Network Conditions
- Airplane mode → queued writes drain later
- Weak network → backoff retry
- Rate limit → respect retry-after delays

Leaderboard Sharing
- Owner creates group → share link works
- Recipient accepts → sees group and scores
- Both post scores → both see each other
- Owner deletes group → recipient sees “group removed”
- Participant leaves → no longer sees group

Time Boundaries
- 23:59 vs 00:01 posting → correct UTC `dateInt`
- Different device timezones → aligned by UTC

Schema & Environment
- Dev build → Development DB
- TestFlight build → Production DB
- Changing schema post-Production deploy → blocked (expected)

Subscription Delivery
- Push arrives → data refreshes
- Push missing → manual refresh fallback works
- Join multiple groups → subscriptions created; leaving cleans them up

### 13) Local Queue & Retry Implementation (reference)

Achievements Queue (in-memory, backoff)
```swift
private var pendingAchievementsSync: [TieredAchievement]? = nil
private var retryDelay: TimeInterval = 1.0

func queueAchievementsSync(_ achievements: [TieredAchievement]) {
    pendingAchievementsSync = achievements
    Task { await attemptAchievementsSyncWithBackoff() }
}

func attemptAchievementsSyncWithBackoff() async {
    guard let pending = pendingAchievementsSync else { return }
    do {
        try await pushAchievements(pending)
        pendingAchievementsSync = nil
        retryDelay = 1.0
        syncStatus = .success(Date())
    } catch {
        if shouldRetry(error) {
            try? await Task.sleep(for: .seconds(retryDelay))
            retryDelay = min(retryDelay * 2, 60.0)
            await attemptAchievementsSyncWithBackoff()
        } else {
            syncStatus = .error(error.localizedDescription)
        }
    }
}
```

DailyScore Queue (persisted)
```swift
private let pendingScoresKey = "pendingDailyScores"

func queueScore(_ score: DailyGameScore) {
    var queue = loadPendingScores()
    queue.removeAll { $0.id == score.id } // dedupe by composite id
    queue.append(score)
    savePendingScores(queue)
    Task { await drainScoreQueue() }
}

func drainScoreQueue() async {
    let queue = loadPendingScores()
    var remaining: [DailyGameScore] = []
    for score in queue {
        do {
            try await publishScore(score)
        } catch {
            if shouldRetry(error) {
                remaining.append(score)
            }
        }
    }
    savePendingScores(remaining)
}
```

### 14) Migration & Rollback Strategy
Migration (UserDefaults → CloudKit)
- Local UserDefaults is canonical until first successful CloudKit push
- On enable: Pull from CloudKit → Merge with local → Push result
- Achievements: merge (higher progress/tier; union unlock dates)
- No data loss: CloudKit is additive; local is never deleted due to CK errors

Rollback
- Feature flag can disable CloudKit any time (app remains fully offline-capable)
- Pending queues persist until re-enabled (or manual clear)
- If CloudKit issues arise: disable via feature flag; resume later

Data Integrity
- Always save locally first, then CloudKit
- Prefer local on ambiguous conflict unless remote clearly newer by `updatedAt`
- Never delete local data due to CloudKit failures

### 15) File Structure & Code Organization (recommended)
```
CloudKit/
├── Services/
│   ├── AchievementSyncService.swift            // exists; enhance for zone + retry/subscriptions
│   ├── LeaderboardSyncService.swift            // new: CKShare groups CRUD & score sync
│   └── CloudKitSubscriptionManager.swift       // new: create/verify/cleanup subscriptions
├── Models/
│   ├── CloudKitZones.swift                     // zone ids, builders
│   ├── CloudKitRecordTypes.swift               // record type & field constants
│   └── SyncStatus.swift                        // enum and helpers
├── Operations/
│   ├── CloudKitZoneSetup.swift                 // idempotent zone creation
│   ├── ShareAcceptanceHandler.swift            // CKAcceptSharesOperation wrapper
│   └── CloudKitRetryHandler.swift              // backoff and retry policies
└── UI/
    ├── CloudKitSettingsView.swift              // minimal status UI
    └── ShareInviteView.swift                   // UICloudSharingController wrapper
```

---

Readiness to start Phase 1
- We are ready to implement Phase 1 (Achievements sync using custom AchievementsZone with optional zone subscription), followed by Phase 2 (CKShare-based leaderboards).


