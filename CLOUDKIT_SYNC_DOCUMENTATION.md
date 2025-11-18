# CloudKit/iCloud Sync Implementation Documentation

## Executive Summary

The StreakSync app implements **three CloudKit-integrated systems**:

1. **Per-Result CloudKit Sync** (for `GameResult` records) – Always-on sync via a custom `UserDataZone` in the private database, implemented by `UserDataSyncService`.
2. **Manual CloudKit Sync for Tiered Achievements** – Feature-flagged, optional sync of the single `UserAchievements` record in `AchievementsZone` via `AchievementSyncService`.
3. **Social Features CloudKit Integration** (Friends/Leaderboards) – CKShare-based architecture defined and partially implemented, with local `MockSocialService` still used as a fallback in many cases.

**Current Status**:
- Local storage (UserDefaults + App Group JSON) remains the canonical on-device store.
- CloudKit sync is **active** for per-result user data and **optional** for tiered achievements.
- CloudKit entitlements and container are configured for `iCloud.com.mitsheth.StreakSync2`.
- Social features are partially implemented; some operations still rely on `MockSocialService` while full CloudKit-backed leaderboards are rolled out.

---

## 1. Architecture Overview

### 1.1 CloudKit Container Configuration

**Container Identifier**: `iCloud.com.mitsheth.StreakSync2`

**Location**: Defined in `CloudKitConfiguration.swift`

```swift
static let containerIdentifier = "iCloud.com.mitsheth.StreakSync2"
```

**Current Status**: CloudKit capability is enabled for the app target, and entitlements reference `iCloud.com.mitsheth.StreakSync2` alongside the App Group.

### 1.2 Sync Strategy

The app uses **manual CloudKit sync** (not `NSPersistentCloudKitContainer`). There is **no Core Data integration** – all persistence uses `UserDefaults` with JSON encoding, and CloudKit is used as a sync layer, not a backup/restore system.

**Three Sync Systems**:

1. **UserDataSyncService** – Per-result sync for `GameResult` records
   - Uses a custom `UserDataZone` in the private database.
   - Maintains a `CKServerChangeToken` in UserDefaults for incremental fetch.
   - Uses an in-memory `UploadQueue` plus a persistent `OfflineQueue` and `SyncTracker` to safely upload results and recover from crashes/offline periods.
   - Listens to CloudKit zone subscriptions (via `CloudKitSubscriptionManager`) to refresh on silent pushes.

2. **AchievementSyncService** – Manual push/pull for tiered achievements
   - Uses `CKContainer.default().privateCloudDatabase` and the `AchievementsZone`.
   - Feature-flagged via `AppConstants.Flags.cloudSyncEnabled` (default: `false`).
   - Bidirectional sync: pull (merge) then push, using a custom merge strategy for tiered achievements.

3. **HybridSocialService** – Social features with CloudKit fallback
   - Integrates with `LeaderboardSyncService` for CKShare-based leaderboards.
   - Falls back to `MockSocialService` (local storage) when CloudKit is unavailable or not yet fully configured.

### 1.3 Conflict Resolution

**AchievementSyncService** uses a **merge strategy**:

```swift
internal func merge(local: [TieredAchievement], remote: [TieredAchievement]) -> [TieredAchievement]
```

**Merge Logic**:
- Takes the **higher progress value** between local and remote
- Takes the **higher tier** if one is unlocked
- **Unions unlock dates** (keeps the latest date for each tier)
- Missing achievements from remote are added to local

**No conflict resolution** for social features (CloudKit implementation is stubbed).

---

## 2. Data Models & Schema

### 2.1 Core Data Entities

**None**. The app does **not use Core Data**. All persistence is via `UserDefaults` with JSON encoding.

### 2.2 CloudKit Record Types

#### 2.2.1 UserAchievements (Private Database)

**Record Type**: `UserAchievements`  
**Record ID**: `"user_achievements"` (fixed record name)  
**Database**: Private Cloud Database

**Fields**:
- `version` (Int64) - Schema version (currently 1)
- `payload` (Bytes/Data) - JSON-encoded `[TieredAchievement]` array
- `lastUpdated` (Date) - Last sync timestamp
- `summary` (Bytes/Data) - NSKeyedArchiver-encoded summary dictionary `[String: Int]` (category -> unlocked count)

**Implementation**: `AchievementSyncService.swift`

#### 2.2.2 Social Features Record Types (Planned, Not Implemented)

Defined in `CloudKitConfiguration.swift` but **not implemented**:

**UserProfile** (Private Database):
- `id` (String)
- `displayName` (String)
- `friendCode` (String)
- `createdAt` (Date)
- `updatedAt` (Date)

**DailyScore** (Private Database):
- `id` (String)
- `userId` (String)
- `gameId` (String)
- `dateInt` (Int64)
- `score` (Int64)
- `maxAttempts` (Int64)
- `completed` (Bool)
- `publishedAt` (Date)

**FriendConnection** (Private Database):
- `friendCode` (String)
- `addedAt` (Date)

### 2.3 Transformable Attributes

**None** - All data is JSON-encoded or NSKeyedArchiver-encoded before storage.

### 2.4 Relationships

**None** - CloudKit records are independent. The app uses flat data structures.

---

## 3. Sync Implementation Details

### 3.1 AchievementSyncService

**File**: `StreakSync/Core/Services/Sync/AchievementSyncService.swift`

**Purpose**: Syncs tiered achievements to/from iCloud Private Database

**Initialization**:
- Created in `AppContainer.init()` (line 188)
- Automatically triggers `syncIfEnabled()` on app launch (line 199)

**Sync Trigger**:
- **Automatic**: On app launch (if feature flag enabled)
- **Manual**: Can be called via `syncIfEnabled()` method
- **Feature Flag**: `AppConstants.Flags.cloudSyncEnabled` (default: `false`)

**Sync Flow**:
1. Check feature flag (`cloudSyncEnabled`)
2. Get `CKContainer.default()`
3. Check iCloud account status
4. **Pull**: Fetch remote record, decode, merge with local
5. **Push**: Encode local achievements, save to CloudKit

**Code Reference**:
```22:37:StreakSync/Core/Services/Sync/AchievementSyncService.swift
func syncIfEnabled() async {
    guard AppConstants.Flags.cloudSyncEnabled else { return }
    do {
        let container = CKContainer.default()
        let database = container.privateCloudDatabase
        let status = try await container.accountStatus()
        guard status == .available else {
            logger.info("iCloud not available: \(String(describing: status))")
            return
        }
        try await pull(database: database)
        try await push(database: database)
    } catch {
        logger.error("CloudKit sync failed: \(error.localizedDescription)")
    }
}
```

**Pull Implementation**:
```44:62:StreakSync/Core/Services/Sync/AchievementSyncService.swift
private func pull(database: CKDatabase) async throws {
    let recordID = CKRecord.ID(recordName: AppConstants.CloudKitKeys.recordID)
    do {
        let record = try await database.record(for: recordID)
        guard let payloadData = record[AppConstants.CloudKitKeys.fieldPayload] as? Data else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let remote = try? decoder.decode([TieredAchievement].self, from: payloadData) {
            let merged = merge(local: appState.tieredAchievements, remote: remote)
            if merged != appState.tieredAchievements {
                appState.tieredAchievements = merged
                logger.info("✅ Pulled and merged tiered achievements from iCloud")
            }
        }
    } catch {
        // Missing record is not a failure on first run
        logger.info("No existing cloud record to pull (\(error.localizedDescription))")
    }
}
```

**Push Implementation**:
```64:83:StreakSync/Core/Services/Sync/AchievementSyncService.swift
private func push(database: CKDatabase) async throws {
    let recordID = CKRecord.ID(recordName: AppConstants.CloudKitKeys.recordID)
    let record: CKRecord
    do {
        record = try await database.record(for: recordID)
    } catch {
        record = CKRecord(recordType: AppConstants.CloudKitKeys.recordTypeUserAchievements, recordID: recordID)
    }
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let payload = (try? encoder.encode(appState.tieredAchievements)) ?? Data()
    record[AppConstants.CloudKitKeys.fieldVersion] = 1 as CKRecordValue
    record[AppConstants.CloudKitKeys.fieldPayload] = payload as CKRecordValue
    record[AppConstants.CloudKitKeys.fieldLastUpdated] = Date() as CKRecordValue
    let summary: [String: Int] = summarize(appState.tieredAchievements)
    record[AppConstants.CloudKitKeys.fieldSummary] = try? NSKeyedArchiver.archivedData(withRootObject: summary, requiringSecureCoding: false) as CKRecordValue
    _ = try await database.save(record)
    logger.info("☁️ Pushed tiered achievements to iCloud")
}
```

### 3.2 HybridSocialService

**File**: `StreakSync/Core/Services/Social/HybridSocialService.swift`

**Purpose**: Provides social features (friends, leaderboards) with CloudKit fallback

**Current Behavior**: Always uses `MockSocialService` (local storage) because CloudKit is unavailable.

**CloudKit Detection**:
```133:136:StreakSync/Core/Services/Social/HybridSocialService.swift
private func checkCloudKitAvailability() async {
    isCloudKitAvailable = false
    print("⚠️ CloudKit disabled (no entitlements) - using local storage")
}
```

**Fallback Pattern**: Every method tries CloudKit first, falls back to local on error:
```140:151:StreakSync/Core/Services/Social/HybridSocialService.swift
func ensureProfile(displayName: String?) async throws -> UserProfile {
    if isCloudKitAvailable {
        do {
            return try await cloudKitService.ensureProfile(displayName: displayName)
        } catch {
            print("CloudKit profile creation failed, falling back to local: \(error)")
            return try await mockService.ensureProfile(displayName: displayName)
        }
    } else {
        return try await mockService.ensureProfile(displayName: displayName)
    }
}
```

### 3.3 CloudKitSocialService

**File**: `StreakSync/Core/Services/Social/CloudKitSocialService.swift`

**Status**: **Stub implementation** - All methods throw `SocialServiceError.cloudKitUnavailable`

**Methods** (all stubbed):
- `ensureProfile()` - Throws error
- `myProfile()` - Throws error
- `generateFriendCode()` - Throws error
- `addFriend()` - Throws error
- `listFriends()` - Throws error
- `publishDailyScores()` - Throws error
- `fetchLeaderboard()` - Throws error
- `setupRealTimeSubscriptions()` - Empty implementation

### 3.4 Initialization & Setup

**AppContainer Initialization**:
```187:200:StreakSync/App/AppContainer.swift
// 10. CloudKit achievements sync (feature-flagged)
self.achievementSyncService = AchievementSyncService(appState: appState)


// Wire up dependencies
setupDependencies()

// Start day change detection
DayChangeDetector.shared.startMonitoring()

// Kick off cloud sync if enabled
Task { @MainActor in
    await self.achievementSyncService.syncIfEnabled()
}
```

**No automatic sync** - Only triggered on app launch if feature flag is enabled.

### 3.5 Sync Status Indicators

**Service Status** (HybridSocialService):
```247:253:StreakSync/Core/Services/Social/HybridSocialService.swift
var serviceStatus: ServiceStatus {
    if isCloudKitAvailable {
        return .cloudKit
    } else {
        return .local
    }
}
```

**ServiceStatus Enum**:
```258:279:StreakSync/Core/Services/Social/HybridSocialService.swift
enum ServiceStatus {
    case cloudKit
    case local
    
    var displayName: String {
        switch self {
        case .cloudKit:
            return "Real-time Sync"
        case .local:
            return "Local Storage"
        }
    }
    
    var description: String {
        switch self {
        case .cloudKit:
            return "Scores sync automatically across devices"
        case .local:
            return "Scores stored locally on this device"
        }
    }
}
```

**No UI indicators** for AchievementSyncService sync status.

### 3.6 Error Handling

**AchievementSyncService**:
- Logs errors but doesn't surface to UI
- Missing record on first pull is not treated as error
- Sync failures are logged but don't block app functionality

**HybridSocialService**:
- Catches CloudKit errors and falls back to local storage
- Errors are logged to console but not shown to user

---

## 4. Current State & Issues

### 4.1 Functional Status

| Component | Status | Notes |
|-----------|--------|-------|
| UserDataSyncService | **Implemented** | Active per-result sync in private DB `UserDataZone` with change tokens, queues, and subscriptions |
| AchievementSyncService | **Implemented (Optional)** | Feature-flagged, syncs tiered achievements in `AchievementsZone` when enabled |
| CloudKitSocialService | **Stub / In Progress** | Some methods still throw or are no-ops; CKShare-based leaderboards rolling out |
| HybridSocialService | **Functional** | Uses CloudKit when available, falls back to local `MockSocialService` |
| CloudKit Entitlements | **Configured** | Entitlements include CloudKit services and the `iCloud.com.mitsheth.StreakSync2` container |
| CloudKit Capability | **Enabled** | iCloud/CloudKit capability added to the app target |

### 4.2 Known Issues & TODOs (Updated)

1. **CloudKitSocialService Coverage**
   - Some methods remain stubbed or partially implemented.
   - Real-time subscriptions for all leaderboard scenarios are not yet fully wired.

2. **Feature Flag Default (Achievements)**
   - `AppConstants.Flags.cloudSyncEnabled` still defaults to `false`.
   - Users must explicitly opt in via the Data & Privacy settings toggle.

3. **Conflict Resolution UI**
   - Merge and “server wins” conflict strategies are handled in code, but there is no dedicated UI explaining when merges occur.

4. **Background Sync Enhancements**
   - Silent push-based refresh via CloudKit subscriptions is implemented.
   - No `BGTaskScheduler`-based periodic background sync yet; foreground/notification-driven refresh is the primary mechanism.

### 4.3 Permissions & Capabilities

**Current Entitlements** (`StreakSync.entitlements`):
```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.mitsheth.StreakSync</string>
</array>
```

**Missing Entitlements**:
- CloudKit container identifiers
- CloudKit services
- Background modes (for background sync)

**Info.plist**: No CloudKit-specific configuration found.

**Required for Production**:
1. Add CloudKit capability in Xcode
2. Add CloudKit entitlements
3. Configure CloudKit container in Apple Developer Portal
4. Enable feature flag or remove feature flag check

---

## 5. Key Files

### 5.1 Core Sync Services

| File | Purpose | Status |
|------|---------|--------|
| `Core/Services/Sync/AchievementSyncService.swift` | Manual CloudKit sync for tiered achievements | ✅ Implemented (disabled) |
| `Core/Services/Social/HybridSocialService.swift` | Social features with CloudKit fallback | ✅ Functional (local only) |
| `Core/Services/Social/CloudKitSocialService.swift` | CloudKit implementation for social features | ⚠️ Stub only |
| `Core/Services/Social/CloudKitConfiguration.swift` | CloudKit configuration constants | ✅ Defined (not used) |

### 5.2 Configuration & Constants

| File | Purpose |
|------|---------|
| `Core/Models/Shared/AppConstants.swift` | Feature flag: `cloudSyncEnabled` |
| `StreakSync.entitlements` | App entitlements (missing CloudKit) |
| `Core/Services/Social/CLOUDKIT_SETUP.md` | Setup documentation |

### 5.3 Integration Points

| File | Integration |
|------|-------------|
| `App/AppContainer.swift` | Creates `AchievementSyncService`, triggers sync on launch |
| `Core/State/AppState.swift` | Holds tiered achievements data |
| `Core/State/AppState+Persistence.swift` | Local persistence (UserDefaults) |
| `Features/Settings/Components/SettingsComponents.swift` | UI toggle for `cloudSyncEnabled` |

### 5.4 Data Models

| File | Purpose |
|------|---------|
| `Core/Models/Achievement/TieredAchievementModels.swift` | `TieredAchievement` model synced to CloudKit |
| `Core/Models/Social/LeaderboardScoring.swift` | Social models (not synced yet) |

---

## 6. Code Snippets Reference

### 6.1 Feature Flag Check

```swift
// AppConstants.swift
enum Flags {
    static var cloudSyncEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "cloudSyncEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "cloudSyncEnabled") }
    }
}
```

### 6.2 CloudKit Keys

```swift
// AppConstants.swift
enum CloudKitKeys {
    static let recordTypeUserAchievements = "UserAchievements"
    static let fieldVersion = "version"
    static let fieldPayload = "payload"
    static let fieldLastUpdated = "lastUpdated"
    static let fieldSummary = "summary"
    static let recordID = "user_achievements"
}
```

### 6.3 Merge Strategy

```swift
// AchievementSyncService.swift
internal func merge(local: [TieredAchievement], remote: [TieredAchievement]) -> [TieredAchievement] {
    var map: [UUID: TieredAchievement] = [:]
    for a in local { map[a.id] = a }
    for r in remote {
        if var l = map[r.id] {
            // Merge by picking higher progress/currentTier and union unlock dates
            let lVal = l.progress.currentValue
            let rVal = r.progress.currentValue
            if rVal > lVal { l.progress.currentValue = rVal }
            if let rt = r.progress.currentTier {
                if l.progress.currentTier == nil || rt.rawValue > (l.progress.currentTier?.rawValue ?? 0) {
                    l.progress.currentTier = rt
                }
            }
            for (tier, date) in r.progress.tierUnlockDates {
                if let existing = l.progress.tierUnlockDates[tier] {
                    l.progress.tierUnlockDates[tier] = max(existing, date)
                } else {
                    l.progress.tierUnlockDates[tier] = date
                }
            }
            map[r.id] = l
        } else {
            map[r.id] = r
        }
    }
    return Array(map.values)
}
```

---

## 7. Activation Steps

To enable CloudKit sync:

1. **Add CloudKit Capability**:
   - Open Xcode project
   - Select app target → Signing & Capabilities
   - Click "+ Capability" → Add "iCloud" → Enable "CloudKit"
   - Container will auto-create: `iCloud.com.mitsheth.StreakSync`

2. **Update Entitlements**:
   - Add to `StreakSync.entitlements`:
     ```xml
     <key>com.apple.developer.icloud-container-identifiers</key>
     <array>
         <string>iCloud.com.mitsheth.StreakSync</string>
     </array>
     <key>com.apple.developer.icloud-services</key>
     <array>
         <string>CloudKit</string>
     </array>
     ```

3. **Enable Feature Flag**:
   - In Settings UI, toggle CloudKit sync ON
   - Or programmatically: `AppConstants.Flags.cloudSyncEnabled = true`

4. **Implement CloudKitSocialService**:
   - Replace stub methods with actual CloudKit operations
   - Implement CRUD for UserProfile, DailyScore, FriendConnection
   - Set up real-time subscriptions

5. **Test on Device**:
   - Requires iCloud account signed in
   - Test sync across multiple devices
   - Verify conflict resolution

---

## 8. Architecture Notes

### 8.1 Why No NSPersistentCloudKitContainer?

The app uses **UserDefaults + JSON** for persistence, not Core Data. `NSPersistentCloudKitContainer` requires Core Data. The manual CloudKit sync approach was chosen to:
- Keep existing UserDefaults-based persistence
- Have fine-grained control over sync logic
- Avoid Core Data migration

### 8.2 Sync Strategy Rationale

**Manual Push/Pull**:
- Simple and predictable
- Full control over conflict resolution
- No automatic sync overhead
- Requires explicit sync triggers

**Alternative Considered**: Automatic Core Data sync, but rejected due to existing architecture.

### 8.3 Future Improvements

1. **Background Sync**: Use `BGTaskScheduler` for periodic sync
2. **Push Notifications**: CloudKit subscriptions for real-time updates
3. **Conflict UI**: Show merge results to user
4. **Sync Status**: Visual indicators in UI
5. **Retry Logic**: Exponential backoff for failed syncs
6. **Incremental Sync**: Only sync changed achievements
7. **Batch Operations**: Sync multiple record types together

---

## 9. Testing

**Test File**: `StreakSyncTests/MigrationAndSyncTests.swift`

**Current Tests**: Migration tests exist, but CloudKit sync tests are limited (would require CloudKit test environment).

**Testing Challenges**:
- Requires iCloud account
- Requires CloudKit entitlements
- Hard to test in CI/CD without real device
- CloudKit Dashboard needed for schema verification

---

## Summary

**Current State**: CloudKit sync is **architecturally ready** but **not active**. The code is implemented but:
- Feature flag is disabled
- Entitlements are missing
- CloudKit capability not enabled
- Social features are stubbed

**To Activate**: Add entitlements, enable capability, flip feature flag, implement CloudKitSocialService.

**Data Synced**: Only tiered achievements (when enabled). Social features use local storage.

**Sync Method**: Manual push/pull, not automatic Core Data sync.

