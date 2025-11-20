# CloudKit User Data Sync - Implementation Plan (Final)

**Status**: ✅ Approved for Implementation  
**Date**: 2025  
**Reference**: Based on `CloudKit_Sync_Spec_v1_Final.md` with refinements from architecture review

---

## Executive Summary

This document defines the production-ready CloudKit sync architecture for StreakSync. The approach uses **proper CloudKit sync** (individual records, automatic sync) rather than a backup/restore system, matching how Apple's own apps (Notes, Reminders, Health) work.

**Key Principle**: Sync atomic data (GameResult records), compute derived data locally (streaks). This eliminates conflicts and complexity.

---

## Table of Contents

1. [Architecture Decisions](#architecture-decisions)
2. [What We Sync (and What We Don't)](#what-we-sync)
3. [CloudKit Schema](#cloudkit-schema)
4. [Sync Flow](#sync-flow)
5. [Conflict Resolution](#conflict-resolution) ⚠️ CRITICAL
6. [Account Changes & Privacy](#account-changes--privacy)
7. [Implementation Details](#implementation-details)
8. [Migration from Existing Users](#migration-from-existing-users)
9. [Testing Strategy](#testing-strategy)
10. [Implementation Estimate](#implementation-estimate)
11. [Critical Checklist](#critical-checklist)

---

## Architecture Decisions

### ✅ Decision: Proper CloudKit Sync (Not Backup/Restore)

**Why**: CloudKit is a sync service, not a backup service. Treating it as backup leads to:
- Complex merge logic
- Manual restore buttons
- Debouncing complexity
- Validation overhead
- Fighting CloudKit's design

**Solution**: Use CloudKit as intended:
- Each GameResult is its own CKRecord
- CloudKit automatically syncs changes
- Delete app → reinstall → data automatically appears
- No manual restore needed
- Works seamlessly across devices

**Reference**: This matches how Apple Notes, Reminders, Health, and Photos work.

### ✅ Decision: Only Sync Results, Compute Streaks Locally

**Why**: Streaks are derived from results. Syncing them creates perpetual conflicts:

```
Device A: Adds result #6 → computes streak = 6 → saves streak record
Device B: Adds result #7 → computes streak = 6 → saves streak record
Both sync → streak records conflict forever
```

**Solution**: 
- Sync only GameResult records
- After sync, recompute streaks locally from all synced results
- Single source of truth (results) = no conflicts

### ✅ Decision: Server Wins Conflict Resolution

**Why**: CloudKit does NOT automatically resolve conflicts. You must handle `CKError.serverRecordChanged`.

**Strategy**: 
- Results are immutable once created → conflicts should be rare
- When conflict occurs: Accept server version (cloud is source of truth)
- Log warning for debugging
- Edge case: UUID collision → server wins

**⚠️ CRITICAL**: This is the #1 thing developers get wrong about CloudKit. You MUST handle conflicts in code.

### ✅ Decision: Immediate Data Clearing on Account Change

**Why**: Privacy issue. Without clearing:
```
User A's data visible → User B signs in → 2-3s of mixed data → Privacy leak
```

**Solution**:
1. Immediately clear all local data (`recentResults = []`, `streaks = []`)
2. Clear UI (show empty state or loading)
3. Clear sync token
4. Re-ensure zone for new account
5. Sync new account's data

### ✅ Decision: Batching for Performance

**Why**: CloudKit rate limits ~40 requests/second. User imports 50 results → 50 individual saves = throttling.

**Solution**:
- Upload queue actor
- Flush immediately if queue >= 5 items
- Otherwise, wait 2s for more results, then flush
- Use `CKModifyRecordsOperation` for batch uploads

---

## What We Sync

### ✅ Sync These
- **GameResult records only** (individual CKRecords, not JSON blobs)
- Each result is its own atomic CloudKit record

### ❌ Don't Sync These
- **GameStreak**: Computed locally from synced results (derived data, not synced)
- **Achievements**: Separate sync path (already implemented)
- **Game definitions**: Embedded in app, not synced

---

## CloudKit Schema

### Zone
- **Zone ID**: `UserDataZone` (custom zone, separate from `AchievementsZone`)
- **Purpose**: Custom zones support subscriptions and change tracking (default zone doesn't)

### Record Type: GameResult

| Field | Type | Description | Indexed |
|-------|------|-------------|---------|
| recordName | String | `result.id.uuidString` (primary key) | Yes |
| gameID | String | UUID of the game | Yes |
| gameName | String | Display name (redundant but works offline) | No |
| gameType | String | e.g. "wordle", "connections" | Yes |
| date | Date | When the game was played | Yes |
| score | Int? | Optional score value | No |
| maxAttempts | Int | Maximum attempts for this game | No |
| completed | Bool | Whether user completed successfully | Yes |
| sharedText | String | Raw shared text from game | No |
| parsedData | String | JSON-encoded game-specific data | No |

**System Fields** (CloudKit manages):
- `modificationDate`: Used for conflict resolution
- `creationDate`: When record was first created

---

## Sync Flow

### On App Launch
1. `await appState.loadPersistedData()` (loads local data first, instant)
2. If `accountStatus == .available`:
   - Show sync state `.syncing` if local is empty (loading indicator)
   - `await syncService.syncIfNeeded()` (fetches changes since last sync token)
   - Show sync state `.synced(Date())` on success
3. `appState.recomputeStreaks()` (always recompute from synced results)

### When User Adds Result
1. Add to local state immediately (instant UI update)
2. `syncService.queueForUpload(result)` (queue for CloudKit)
3. `syncService.flushQueueIfNeeded()` (batch upload if queue > 5 items or after 2s debounce)

### When Remote Changes Arrive
- Via push notification (zone subscription)
- In `AppDelegate.didReceiveRemoteNotification`:
  - Check if `CKNotification.subscriptionID == "user-data-zone-changes"`
  - `await syncService.syncIfNeeded()` (fetch delta since last token)
  - `appState.recomputeStreaks()` (recompute after sync)

### Sync Algorithm (Incremental)
- Store `CKServerChangeToken` in UserDefaults key `com.streaksync.sync.serverChangeToken` (archived)
- Use `CKFetchRecordZoneChangesOperation` with previous token
- Fetch only changes since last sync (not entire dataset)
- On first launch or token missing: Fetch all records (no token = full sync)

---

## Conflict Resolution

⚠️ **CRITICAL**: CloudKit does NOT automatically resolve conflicts.

When saving a record that was modified elsewhere, CloudKit throws `CKError.serverRecordChanged`. You MUST handle this in code. This is the #1 thing developers get wrong about CloudKit.

### Strategy for GameResult

Results are immutable once created → conflicts should be rare.

**On `CKError.serverRecordChanged`**:
```swift
catch let error as CKError where error.code == .serverRecordChanged {
    let serverRecord = error.serverRecord // Newer version from cloud
    let clientRecord = error.clientRecord // Your attempted save
    
    // Strategy: Server wins (cloud is source of truth)
    // Accept server version, discard local changes
    logger.warning("Conflict for result \(result.id), using server version")
}
```

**Edge case**: If same result ID appears on two devices (UUID collision), server wins.

---

## Account Changes & Privacy

### Detecting Account Changes
Observe `CKAccountChanged` notification.

### Handling Account Change
```swift
func handleAccountChanged() async {
    // 1. Immediately clear all local data (CRITICAL for privacy)
    await clearAllLocalData()
    
    // 2. Clear UI (show empty state or loading)
    showSyncState(.syncing)
    
    // 3. Clear sync token
    clearSyncToken()
    
    // 4. Check if account actually changed (compare userRecordID)
    let newUserRecordID = try? await CKContainer.default().userRecordID()
    let previousUserRecordID = loadPreviousUserRecordID()
    
    if newUserRecordID != previousUserRecordID {
        // 5. Re-ensure zone and subscription for new account
        try? await ensureUserDataZone(in: database)
        try? await ensureUserDataZoneSubscription(in: database)
        
        // 6. Sync new account's data
        await syncIfNeeded()
        appState.recomputeStreaks()
        showSyncState(.synced(Date()))
    }
}
```

**Why clear immediately**: Without clearing, User A's data visible → User B signs in → 2-3s of mixed data → Privacy leak.

---

## Implementation Details

### Files to Add

#### `StreakSync/Core/Services/Sync/UserDataSyncService.swift`
**Public API**:
- `syncIfNeeded()` - Fetch changes from CloudKit since last sync token
- `queueForUpload(_: GameResult)` - Queue result for batch upload
- `deleteResult(_: UUID)` - Delete result from CloudKit
- `syncState: SyncState` - Current sync status

**Internals**:
- `fetchChangesSinceToken()` - Use `CKFetchRecordZoneChangesOperation`
- `uploadBatch(_: [GameResult])` - Use `CKModifyRecordsOperation` for batching
- Conflict resolution (server wins)
- Retry logic with exponential backoff
- Offline queue with persistence
- Model conversion: `GameResult ↔ CKRecord` (extensions)

#### `StreakSync/Core/Services/Sync/CloudKitZoneSetup.swift`
- `userDataZoneID: CKRecordZone.ID`
- `ensureUserDataZone(in:)` - Idempotent zone creation
- `ensureUserDataZoneSubscription(in:)` - Idempotent subscription creation with silent push

#### `StreakSync/Core/Services/Sync/NetworkMonitor.swift`
- Monitor network reachability using `NWPathMonitor`
- Trigger offline queue flush when network becomes available

### Files to Modify

#### `StreakSync/App/AppContainer.swift`
```swift
// Add:
let syncService: UserDataSyncService
let networkMonitor: NetworkMonitor

// In init:
await appState.loadPersistedData()
if CKContainer.default().accountStatus() == .available {
    await syncService.ensureZoneAndSubscription()
    await syncService.syncIfNeeded()
    appState.recomputeStreaks()
}
networkMonitor.startMonitoring()
```

#### `StreakSync/Core/State/AppState.swift`
```swift
// Add methods:
func recomputeStreaks() {
    // Compute streaks from all synced results
    // Filter by game, calculate current/max streaks
    // Update streaks array
}

func clearAllData() {
    // For account changes
    self.recentResults = []
    self.streaks = games.map { GameStreak.empty(for: $0) }
    invalidateCache()
}
```

#### `StreakSync/App/StreakSyncApp.swift`
```swift
// Add AppDelegate for remote notifications:
@UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                    fetchCompletionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if let notification = CKNotification(fromRemoteNotificationDictionary: userInfo),
           notification.subscriptionID == "user-data-zone-changes" {
            Task {
                await AppContainer.shared.syncService.syncIfNeeded()
                completionHandler(.newData)
            }
        } else {
            completionHandler(.noData)
        }
    }
}
```

#### `StreakSync/Features/Settings/Components/SettingsComponents.swift`
```swift
// Add sync status display (optional, for debugging):
Section("iCloud Sync") {
    HStack {
        Text("Status")
        Spacer()
        switch syncService.syncState {
        case .syncing:
            ProgressView()
        case .synced(let date):
            Text(date.formatted(.relative(presentation: .named)))
        case .failed(let error):
            Text("Failed").foregroundColor(.red)
        case .offline:
            Text("Offline").foregroundColor(.orange)
        }
    }
}

// No manual "Back Up Now" or "Restore" buttons (automatic sync only)
```

### Capabilities Required

**Xcode Project Settings**:
1. **Signing & Capabilities** → Add:
   - **iCloud** (CloudKit)
   - **Background Modes** (Remote notifications)
2. **CloudKit Container**: Use default container or create custom
3. **CloudKit Console**: No schema setup needed in development (auto-creates on first save)

---

## Migration from Existing Users

**✅ IMPLEMENTED (January 2025)**: Existing users with local data automatically upload to CloudKit when CloudKit is detected as empty. The `UserDataSyncService` detects when:
- CloudKit returns 0 records during sync
- Local results exist that were never marked for sync
- Automatically uploads all local results to prevent data loss on reinstall

**No data loss**: Users who had data before CloudKit sync was implemented, or whose data was never successfully synced, will have their data automatically uploaded and preserved across app reinstalls.

Process is additive:
1. Local results are uploaded to cloud
2. Cloud results (if any from other devices) are downloaded
3. Union by result ID (deduplicate)
4. Recompute streaks from complete dataset

**No migration code needed** - sync handles it automatically.

---

## Testing Strategy

### Manual Testing Checklist

1. **Basic Sync**
   - Add result on Device A → Verify appears on Device B within 30s

2. **Delete/Reinstall**
   - Delete app on Device A → Reinstall → Verify data appears automatically

3. **Offline Queue**
   - Enable Airplane Mode
   - Add 10 results
   - Disable Airplane Mode
   - Verify all 10 results sync to CloudKit

4. **Account Changes**
   - Sign in as User A, add results
   - Sign out of iCloud
   - Sign in as User B
   - Verify User A's data doesn't appear, User B's data loads

5. **Conflicts** (rare, but test)
   - Offline on both devices
   - Add same result ID on both (force UUID collision in test)
   - Go online
   - Verify server wins, no crashes

6. **Batch Upload**
   - Import 50 results at once
   - Verify batched into ~10 CloudKit operations (not 50 individual)

7. **First Launch**
   - Install app with existing iCloud data
   - Verify loading indicator shows during initial sync
   - Verify data appears after sync completes

---

## Implementation Estimate

- **Core UserDataSyncService**: 3-4 days
- **Integration + Testing**: 3-4 days
- **Polish + Edge Cases**: 2-3 days

**Total: 1-2 weeks for experienced iOS developer**

---

## Critical Checklist

Before starting implementation, verify you can answer:

✅ **What happens when user adds 100 results offline?**  
→ Queue persists, batched upload when online

✅ **What happens if two devices both add result with same UUID?**  
→ Server wins (rare, logged as warning)

✅ **What happens when user switches iCloud accounts?**  
→ Clear local data immediately, sync new account

✅ **How do you know sync is complete on first launch?**  
→ SyncState tracks it, show loading until .synced

✅ **What if CloudKit push notification doesn't arrive?**  
→ Polling fallback on app foreground (every 5 min)

✅ **How do streaks stay consistent?**  
→ Always recomputed locally from synced results

---

## Error Handling

### Common CloudKit Errors

| Error | Strategy | User Message |
|-------|----------|--------------|
| `.networkUnavailable` | Queue locally, retry when online | "No internet. Will sync when online." |
| `.quotaExceeded` | Stop syncing, alert user | "iCloud storage full. Free up space in Settings → iCloud." |
| `.zoneBusy` / `.serviceUnavailable` | Retry with exponential backoff | "iCloud temporarily unavailable. Retrying..." |
| `.partialFailure` | Extract per-record errors, retry individual failures | "Some data couldn't sync. Retrying..." |
| `.serverRecordChanged` | Resolve conflict (server wins) | Silent (handled automatically) |
| `.changeTokenExpired` | Clear token, re-fetch all records | Silent (full sync) |

### Retry Strategy
- Exponential backoff for transient errors (2s, 4s, 8s)
- Max 3 retry attempts
- Don't retry quota errors (needs user action)

---

## First Launch UX

**Sync state enum**:
```swift
enum SyncState {
    case syncing
    case synced(lastSyncDate: Date)
    case failed(Error)
    case offline // iCloud unavailable
}
```

**UX Flow**:
- If `recentResults.isEmpty` and syncing: Show loading spinner + "Syncing your data..."
- Don't show "No results yet" until sync completes or fails
- If sync fails: Show error + "Using offline data"

---

## Upload Queue & Batching

### Why Batching?
CloudKit rate limits ~40 requests/second. User imports 50 results → 50 individual saves = throttling + poor battery life.

### Queue Strategy
```swift
actor UploadQueue {
    private var pending: [GameResult] = []
    private var uploadTask: Task<Void, Never>?
    
    func enqueue(_ result: GameResult) {
        pending.append(result)
        scheduleFlush()
    }
    
    private func scheduleFlush() {
        uploadTask?.cancel()
        uploadTask = Task {
            if pending.count >= 5 {
                await flush() // Flush immediately if queue is large
            } else {
                try? await Task.sleep(for: .seconds(2))
                await flush() // Wait 2s for more results
            }
        }
    }
}
```

### Batch Upload
Use `CKModifyRecordsOperation`:
- `savePolicy = .changedKeys` (only upload modified fields)
- `isAtomic = false` (continue if some records fail)
- Retry failed records individually

---

## Offline Support

### Offline Queue
```swift
actor OfflineQueue {
    private var pending: [GameResult] = []
    private let persistenceKey = "com.streaksync.sync.offlineQueue"
    
    init() {
        // Load persisted queue
        pending = loadPersistedQueue()
    }
    
    func enqueue(_ result: GameResult) {
        pending.append(result)
        persistQueue()
    }
    
    func flush() async {
        guard !pending.isEmpty else { return }
        let batch = pending
        await uploadBatch(batch)
        pending.removeAll()
        persistQueue()
    }
}
```

### Network Monitoring
```swift
import Network

class NetworkMonitor {
    private let monitor = NWPathMonitor()
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                // Network available, flush offline queue
                Task {
                    await self?.syncService.flushOfflineQueue()
                }
            }
        }
        monitor.start(queue: .global())
    }
}
```

---

## Model Conversion

### GameResult → CKRecord
```swift
extension GameResult {
    func toCKRecord(in zoneID: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(
            recordName: self.id.uuidString,
            zoneID: zoneID
        )
        let record = CKRecord(recordType: "GameResult", recordID: recordID)
        
        record["gameID"] = self.gameId.uuidString as CKRecordValue
        record["gameName"] = self.gameName as CKRecordValue
        record["gameType"] = self.gameName.lowercased() as CKRecordValue
        record["date"] = self.date as CKRecordValue
        record["score"] = self.score as? CKRecordValue
        record["maxAttempts"] = self.maxAttempts as CKRecordValue
        record["completed"] = (self.completed ? 1 : 0) as CKRecordValue
        record["sharedText"] = self.sharedText as CKRecordValue
        
        // Encode parsedData as JSON string
        if let data = try? JSONEncoder().encode(self.parsedData),
           let json = String(data: data, encoding: .utf8) {
            record["parsedData"] = json as CKRecordValue
        }
        
        return record
    }
}
```

### CKRecord → GameResult
```swift
extension GameResult {
    init?(from record: CKRecord) {
        guard 
            record.recordType == "GameResult",
            let gameIDString = record["gameID"] as? String,
            let gameID = UUID(uuidString: gameIDString),
            let gameName = record["gameName"] as? String,
            let gameTypeString = record["gameType"] as? String,
            let date = record["date"] as? Date,
            let maxAttempts = record["maxAttempts"] as? Int,
            let completedInt = record["completed"] as? Int,
            let sharedText = record["sharedText"] as? String
        else {
            return nil
        }
        
        // Reconstruct Game (use predefined games or create fallback)
        let game = Game.allAvailableGames.first(where: { $0.id == gameID }) ?? Game(
            id: gameID,
            name: gameName,
            // ... other game properties
        )
        
        let score = record["score"] as? Int
        let completed = completedInt != 0
        
        // Decode parsedData
        var parsedData: [String: String] = [:]
        if let json = record["parsedData"] as? String,
           let data = json.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            parsedData = decoded
        }
        
        self.init(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            gameId: gameID,
            gameName: gameName,
            date: date,
            score: score,
            maxAttempts: maxAttempts,
            completed: completed,
            sharedText: sharedText,
            parsedData: parsedData
        )
    }
}
```

---

## Streak Computation (Local Only)

```swift
extension AppState {
    func recomputeStreaks() {
        for game in games {
            let gameResults = recentResults
                .filter { $0.gameId == game.id }
                .sorted { $0.date > $1.date } // Newest first
            
            let streak = GameStreak.compute(from: gameResults, for: game)
            
            if let index = streaks.firstIndex(where: { $0.gameId == game.id }) {
                streaks[index] = streak
            } else {
                streaks.append(streak)
            }
        }
    }
}

extension GameStreak {
    static func compute(from results: [GameResult], for game: Game) -> GameStreak {
        guard !results.isEmpty else {
            return GameStreak.empty(for: game)
        }
        
        let totalPlayed = results.count
        let totalCompleted = results.filter { $0.completed }.count
        let lastPlayed = results.first?.date
        
        // Calculate current streak (consecutive days from most recent)
        var currentStreak = 0
        var maxStreak = 0
        var streakStartDate: Date?
        var tempStreak = 0
        
        let calendar = Calendar.current
        var expectedDate = calendar.startOfDay(for: Date())
        
        for result in results {
            let resultDate = calendar.startOfDay(for: result.date)
            
            if calendar.isDate(resultDate, inSameDayAs: expectedDate) {
                tempStreak += 1
                if currentStreak == 0 {
                    currentStreak = tempStreak
                    streakStartDate = result.date
                }
                maxStreak = max(maxStreak, tempStreak)
                expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate)!
            } else if resultDate < expectedDate {
                // Streak broken
                maxStreak = max(maxStreak, tempStreak)
                tempStreak = 0
                expectedDate = resultDate
            }
        }
        
        return GameStreak(
            id: UUID(),
            gameId: game.id,
            gameName: game.name,
            currentStreak: currentStreak,
            maxStreak: maxStreak,
            totalGamesPlayed: totalPlayed,
            totalGamesCompleted: totalCompleted,
            lastPlayedDate: lastPlayed,
            streakStartDate: streakStartDate
        )
    }
}
```

---

## Zone Setup & Subscription

### Zone Creation
```swift
func ensureUserDataZone(in database: CKDatabase) async throws {
    let zoneID = CKRecordZone.ID(zoneName: "UserDataZone")
    
    do {
        // Check if zone exists
        _ = try await database.recordZone(for: zoneID)
        logger.info("UserDataZone already exists")
    } catch let error as CKError where error.code == .zoneNotFound {
        // Create zone
        let zone = CKRecordZone(zoneID: zoneID)
        _ = try await database.save(zone)
        logger.info("Created UserDataZone")
    }
    // Other errors propagate (network, quota, etc.)
}
```

### Subscription Creation
```swift
func ensureUserDataZoneSubscription(in database: CKDatabase) async throws {
    let subscriptionID = "user-data-zone-changes"
    
    // Check if subscription already exists
    let existing = try await database.allSubscriptions()
    if existing.contains(where: { $0.subscriptionID == subscriptionID }) {
        logger.info("Subscription already exists")
        return
    }
    
    // Create zone subscription
    let subscription = CKRecordZoneSubscription(
        zoneID: CKRecordZone.ID(zoneName: "UserDataZone"),
        subscriptionID: subscriptionID
    )
    
    // Configure for silent push notifications
    let notificationInfo = CKSubscription.NotificationInfo()
    notificationInfo.shouldSendContentAvailable = true // Silent push
    notificationInfo.shouldBadge = false
    notificationInfo.shouldSendMutableContent = false
    subscription.notificationInfo = notificationInfo
    
    _ = try await database.save(subscription)
    logger.info("Created zone subscription")
}
```

**Required**: Enable **Background Modes → Remote notifications** capability.

---

## Non-Goals (v1)

### Explicitly Out of Scope
- **Share Extension CloudKit writes**: Keep extension simple, only reads from App Group
- **Game definitions sync**: Games are embedded in app bundle, not user-created
- **Attachments/media**: Results are text-only (no images/videos)
- **Collaboration/sharing**: Single-user sync only
- **Conflict UI**: Conflicts handled silently (server wins)
- **Manual backup/restore buttons**: Automatic sync only
- **GameStreak sync**: Computed locally only (derived data)

### Deferred to v1.1
- **Advanced conflict resolution**: Merge strategies beyond "server wins"
- **Selective sync**: Sync only certain games
- **Sync history**: View past sync operations
- **Data export**: Download all CloudKit data as JSON
- **Pagination**: Lazy-load very old results (only if needed)

---

## Implementation Tip

**Start with the sync service in isolation** (with mock CloudKit database) to validate the sync logic before integrating into the app. Makes debugging much easier.

---

## Summary: What Makes This "Just Work"

✅ **Delete app → reinstall → data appears automatically** (no restore button) - **VERIFIED January 2025**  
✅ **Multi-device sync** (changes on iPhone appear on iPad instantly)  
✅ **Offline-first** (local data always available, syncs when online)  
✅ **No conflicts** (derived data computed locally, atomic results synced)  
✅ **Handles account changes** (clears data immediately for privacy)  
✅ **Efficient** (batches uploads, incremental fetch with change tokens)  
✅ **Resilient** (retry logic, offline queue persists across app launches)

**Ship this for v1.** It's a solid, production-ready architecture that matches how Apple's own apps work.

---

## Reference Documents

- **Full Implementation Spec**: `CloudKit_Sync_Spec_v1_Final.md` (detailed code examples)
- **This Document**: High-level plan and critical decisions
- **Use Together**: This for planning/communication, full spec for implementation reference

---

## Next Steps

1. ✅ Review this plan (you are here)
2. Create CloudKit schema in CloudKit Console (or let auto-creation handle it)
3. Implement `UserDataSyncService.swift` (core sync logic)
4. Integrate into `AppContainer` (zone setup + initial sync)
5. Add remote notification handling (`AppDelegate`)
6. Test on two physical devices with same Apple ID
7. Ship v1, gather metrics, iterate to v1.1

**Estimated implementation time:** 1-2 weeks for experienced iOS dev.

Good luck! 🚀

