# Leaderboard Score Display Issue - Comprehensive Analysis

**Date**: Current Session  
**Status**: 🔍 **Under Investigation**  
**Issue**: User's own scores not appearing on leaderboard despite games being completed

---

## Table of Contents

1. [System Architecture Overview](#system-architecture-overview)
2. [Complete Data Flow](#complete-data-flow)
3. [Potential Failure Points](#potential-failure-points)
4. [What We've Tried](#what-weve-tried)
5. [Systematic Debugging Approach](#systematic-debugging-approach)
6. [Generic Patterns & Lessons](#generic-patterns--lessons)

---

## System Architecture Overview

### High-Level Components

```
┌─────────────────────────────────────────────────────────────┐
│                    User Completes Game                     │
└───────────────────────┬───────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│                    AppState.addGameResult()                  │
│  - Validates result                                         │
│  - Updates streaks/achievements                             │
│  - Saves to local persistence                               │
│  - Publishes to social service (if !isGuestMode)           │
└───────────────────────┬───────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│            CloudKitSocialService.publishDailyScores()       │
│  - Filters via shouldShare()                                │
│  - Normalizes userId (local_user → CloudKit ID)            │
│  - Stores locally (MockSocialService)                      │
│  - Optionally stores in CloudKit (if group exists)          │
└───────────────────────┬───────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              MockSocialService.publishDailyScores()         │
│  - Upserts scores in UserDefaults                           │
│  - Key: "social_mock_scores"                                │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│              User Opens Friends Tab                         │
└───────────────────────┬───────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              FriendsViewModel.load()                        │
│  - Calls socialService.fetchLeaderboard()                  │
│  - Filters by date range                                    │
│  - Aggregates per user                                      │
└───────────────────────┬───────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│        CloudKitSocialService.fetchLeaderboard()             │
│  - Checks cache first                                       │
│  - Fetches from CloudKit (if available + group exists)     │
│  - Fetches from local (MockSocialService)                   │
│  - Merges results                                           │
│  - Returns [LeaderboardRow]                                 │
└───────────────────────┬───────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              FriendsView displays leaderboard               │
└─────────────────────────────────────────────────────────────┘
```

### Key Data Structures

**DailyGameScore**:
```swift
struct DailyGameScore {
    let id: String              // Composite: "userId|dateInt|gameId"
    let userId: String          // "local_user" or CloudKit record name
    let dateInt: Int            // yyyyMMdd format (UTC)
    let gameId: UUID
    let gameName: String
    let score: Int?
    let maxAttempts: Int
    let completed: Bool
}
```

**LeaderboardRow**:
```swift
struct LeaderboardRow {
    let id: String              // userId
    let userId: String
    let displayName: String
    let totalPoints: Int
    let perGameBreakdown: [UUID: Int]
}
```

---

## Complete Data Flow

### Phase 1: Score Publishing (Game Completion → Storage)

#### Step 1.1: Game Result Creation
**Location**: `AppState.addGameResult(_:)`

**What Happens**:
1. Game result is validated (not duplicate, valid date, etc.)
2. Result is added to `recentResults` array
3. Streaks and achievements are updated
4. Data is persisted to UserDefaults
5. **Score publishing is triggered** (if `!isGuestMode`)

**Critical Check**: `if !isGuestMode`
- If `isGuestMode == true`, score publishing is **completely skipped**
- This is intentional for guest sessions

**Code Path**:
```swift
// AppState.addGameResult()
if !isGuestMode {
    Task {
        guard let social = self.socialService else { return }
        let userId = "local_user"
        let dateInt = result.date.utcYYYYMMDD  // ← UTC date conversion
        let score = DailyGameScore(...)
        try? await social.publishDailyScores(dateUTC: result.date, scores: [score])
    }
}
```

**Potential Issues**:
- ❌ `isGuestMode` might be `true` unexpectedly
- ❌ `socialService` might be `nil` (not initialized)
- ❌ `try?` silently swallows errors - no logging if publish fails
- ❌ Date conversion might be wrong timezone

---

#### Step 1.2: Score Filtering
**Location**: `CloudKitSocialService.publishDailyScores()`

**What Happens**:
1. Scores are filtered through `shouldShare(score:)`
2. If all scores are filtered out, function returns early
3. Remaining scores are normalized (userId conversion)
4. Scores are sent to storage

**Critical Filter**: `shouldShare(score:)`
```swift
func shouldShare(score: DailyGameScore) -> Bool {
    let game = Game.allAvailableGames.first(where: { $0.id == score.gameId })
    return socialSettingsService.shouldShare(score: score, game: game)
}
```

**Filter Checks** (in `SocialSettingsService.shouldShare()`):
1. **Incomplete Games**: If `!shareIncompleteGames && !score.completed` → **FILTERED OUT**
2. **Zero Points**: If `hideZeroPointScores && points == 0` → **FILTERED OUT**
3. **Privacy Scope**: If `scope(for: gameId) == .privateScope` → **FILTERED OUT**

**Potential Issues**:
- ❌ Game might be set to `.privateScope` in settings
- ❌ Incomplete games might be filtered out
- ❌ Zero-point scores might be filtered out
- ❌ Game might not be found in `Game.allAvailableGames` (returns `nil`, might cause issues)

---

#### Step 1.3: User ID Normalization
**Location**: `CloudKitSocialService.normalizeScores()`

**What Happens**:
1. If CloudKit is available, fetches current user's CloudKit record name
2. Replaces `userId = "local_user"` with CloudKit record name
3. Updates composite `id` to match new userId

**Example Transformation**:
```
Before: userId = "local_user", id = "local_user|20251119|wordle-uuid"
After:  userId = "_41be6d6ba28aca2ea78efff25c1e94a6", id = "_41be6d6...|20251119|wordle-uuid"
```

**Potential Issues**:
- ❌ CloudKit user ID fetch might fail silently
- ❌ If CloudKit unavailable, userId stays as "local_user"
- ❌ Normalized ID might not match what we search for later

---

#### Step 1.4: Local Storage
**Location**: `MockSocialService.publishDailyScores()`

**What Happens**:
1. Loads existing scores from UserDefaults (`social_mock_scores`)
2. Upserts new scores by `id` (composite key)
3. Saves back to UserDefaults

**Storage Key**: `"social_mock_scores"`  
**Format**: Array of `DailyGameScore` (Codable)

**Potential Issues**:
- ❌ UserDefaults might fail to save (rare, but possible)
- ❌ Encoding/decoding might fail silently
- ❌ Scores might be overwritten incorrectly
- ❌ Storage might be cleared elsewhere

---

#### Step 1.5: CloudKit Storage (Optional)
**Location**: `LeaderboardSyncService.publishDailyScore()`

**What Happens** (only if CloudKit available + group exists):
1. Creates/updates `DailyScore` CKRecord in shared zone
2. Uses composite record ID: `"{userId}|{dateInt}|{gameId}"`
3. Stores in shared CloudKit database

**Potential Issues**:
- ❌ Group might not exist yet (beta mode)
- ❌ Zone might not exist
- ❌ CloudKit operation might fail
- ❌ Record might be created but not queryable immediately

---

### Phase 2: Score Retrieval (Storage → Leaderboard Display)

#### Step 2.1: Leaderboard Request
**Location**: `FriendsViewModel.load()`

**What Happens**:
1. User opens Friends tab
2. `load()` is called
3. Date range is calculated: `dateRange()` → `(startDateUTC, endDateUTC)`
4. `socialService.fetchLeaderboard(startDateUTC, endDateUTC)` is called

**Date Range Calculation**:
```swift
func dateRange() -> (Date, Date) {
    let cal = Calendar(identifier: .gregorian)
    let startDay = cal.startOfDay(for: selectedDateUTC)  // ← Uses selectedDateUTC
    switch range {
    case .today:
        return (startDay, startDay)  // Same day for start and end
    case .sevenDays:
        let end = startDay
        let start = cal.date(byAdding: .day, value: -6, to: end) ?? end
        return (start, end)
    }
}
```

**Potential Issues**:
- ❌ `selectedDateUTC` might be wrong date
- ❌ Date conversion to UTC might be incorrect
- ❌ Timezone issues (local time vs UTC)

---

#### Step 2.2: Cache Check
**Location**: `CloudKitSocialService.fetchLeaderboard()`

**What Happens**:
1. Creates cache key from date range and group ID
2. Checks if cached result exists and is fresh (< TTL)
3. If cached, returns immediately

**Cache Key**: `LeaderboardCacheKey(startDateInt, endDateInt, groupId)`  
**TTL**: Configurable (default seems to be short)

**Potential Issues**:
- ❌ Stale cache might be returned
- ❌ Cache might not be invalidated when scores are published
- ❌ Cache key might not match (date format mismatch)

---

#### Step 2.3: CloudKit Fetch (If Available)
**Location**: `LeaderboardSyncService.fetchScores()`

**What Happens**:
1. Queries `DailyScore` records from shared zone
2. Filters by date if `dateInt` provided
3. Returns array of `CKRecord`

**Potential Issues**:
- ❌ Zone might not exist → throws error
- ❌ Group might not exist → throws error
- ❌ Query might return empty (no scores yet)
- ❌ Date filtering might be wrong

---

#### Step 2.4: Local Fetch
**Location**: `MockSocialService.fetchLeaderboard()`

**What Happens**:
1. Loads all scores from UserDefaults
2. Filters by date range: `score.dateInt >= start && score.dateInt <= end`
3. Aggregates per user
4. Returns `[LeaderboardRow]`

**Date Filtering**:
```swift
let start = startDateUTC.utcYYYYMMDD  // e.g., 20251118
let end = endDateUTC.utcYYYYMMDD      // e.g., 20251118
let filtered = all.filter { $0.dateInt >= start && $0.dateInt <= end }
```

**Potential Issues**:
- ❌ Date format mismatch (`dateInt` vs `utcYYYYMMDD`)
- ❌ Scores might have wrong `dateInt` value
- ❌ UserDefaults might be empty (scores not saved)
- ❌ `userId` mismatch (searching for wrong ID)

---

#### Step 2.5: Score Merging
**Location**: `CloudKitSocialService.fetchLeaderboard()`

**What Happens**:
1. Fetches CloudKit scores (if available)
2. Fetches local scores (always)
3. Merges results, ensuring current user appears

**Merging Logic**:
```swift
// Find current user's local row
let myLocalRow = localRows.first(where: { 
    $0.userId == myLocalProfile.id || 
    $0.userId == "local_user" 
})

// Use CloudKit user ID if available
let userIdToUse = ckUserId ?? myLocalRow.userId

// Add to results if not already present
if !perUser.keys.contains(userIdToUse) {
    perUser[userIdToUse] = myLocalRow
}
```

**Potential Issues**:
- ❌ `myLocalProfile` might not exist
- ❌ `myLocalRow` might not be found (userId mismatch)
- ❌ `ckUserId` might be wrong
- ❌ Merging logic might have bugs

---

#### Step 2.6: Aggregation & Sorting
**Location**: `CloudKitSocialService.fetchLeaderboard()`

**What Happens**:
1. Aggregates scores per user
2. Calculates points using `LeaderboardScoring.points()`
3. Sorts by `totalPoints` descending
4. Returns `[LeaderboardRow]`

**Potential Issues**:
- ❌ Point calculation might be wrong
- ❌ Aggregation might miss some scores
- ❌ Sorting might be incorrect

---

#### Step 2.7: UI Display
**Location**: `FriendsView` → `GameLeaderboardPage`

**What Happens**:
1. Receives `[LeaderboardRow]` from view model
2. Filters by selected game
3. Displays rows with rank, name, points

**Potential Issues**:
- ❌ Empty state shown if `rows.isEmpty`
- ❌ Game filtering might exclude user's row
- ❌ UI might not update when data changes

---

## Potential Failure Points

### Category 1: Score Publishing Failures

#### 1.1 Guest Mode Active
**Symptom**: Scores never published  
**Check**: `appState.isGuestMode == false`  
**Fix**: Exit guest mode or ensure guest mode is properly managed

#### 1.2 Social Service Not Initialized
**Symptom**: `socialService` is `nil`  
**Check**: `AppContainer` initialization, `socialService` assignment  
**Fix**: Ensure `AppContainer` properly initializes `CloudKitSocialService`

#### 1.3 Score Filtered Out
**Symptom**: Score passes through but doesn't appear  
**Check**: `shouldShare()` returns `true`  
**Possible Causes**:
- Game set to `.privateScope` in settings
- `hideZeroPointScores` enabled and score is 0 points
- `shareIncompleteGames` disabled and game incomplete
- Game not found in `Game.allAvailableGames`

**Debug**:
```swift
// Add logging in shouldShare()
let shouldShare = socialSettingsService.shouldShare(score: score, game: game)
print("🔍 shouldShare(\(score.gameName)): \(shouldShare)")
if !shouldShare {
    print("❌ Score filtered out - check privacy settings")
}
```

#### 1.4 Silent Error Swallowing
**Symptom**: Publish fails but no error shown  
**Check**: `try?` in `AppState.addGameResult()`  
**Fix**: Add proper error logging

**Current Code**:
```swift
try? await social.publishDailyScores(...)  // ← Silently fails!
```

**Better**:
```swift
do {
    try await social.publishDailyScores(...)
} catch {
    logger.error("Failed to publish score: \(error)")
}
```

---

### Category 2: Storage Failures

#### 2.1 UserDefaults Save Failure
**Symptom**: Scores not persisted  
**Check**: UserDefaults write succeeds  
**Debug**: Add logging in `MockSocialService.publishDailyScores()`

#### 2.2 Encoding/Decoding Failure
**Symptom**: Scores corrupted or lost  
**Check**: `DailyGameScore` Codable implementation  
**Fix**: Ensure all properties are Codable

#### 2.3 Storage Key Mismatch
**Symptom**: Scores saved but not loaded  
**Check**: Key consistency (`"social_mock_scores"`)  
**Fix**: Use constant for key

---

### Category 3: Date/Time Issues

#### 3.1 Date Format Mismatch
**Symptom**: Scores exist but don't match date filter  
**Check**: `dateInt` format consistency

**Example**:
```
Score stored: dateInt = 20251119 (Nov 19)
Filter range: start = 20251118, end = 20251118 (Nov 18)
Result: Score doesn't match filter!
```

**Debug**:
```swift
print("📅 Score dateInt: \(score.dateInt)")
print("📅 Filter range: \(startDateUTC.utcYYYYMMDD) - \(endDateUTC.utcYYYYMMDD)")
```

#### 3.2 Timezone Issues
**Symptom**: Scores appear on wrong day  
**Check**: UTC conversion consistency

**Issue**: `utcYYYYMMDD` uses UTC, but `selectedDateUTC` might be local time

**Debug**:
```swift
let scoreDate = Date() // When score was created
let scoreDateInt = scoreDate.utcYYYYMMDD
let viewDate = selectedDateUTC
let viewDateInt = viewDate.utcYYYYMMDD
print("📅 Score: \(scoreDate) → \(scoreDateInt)")
print("📅 View:  \(viewDate) → \(viewDateInt)")
```

---

### Category 4: User ID Mismatch

#### 4.1 Local vs CloudKit ID Mismatch
**Symptom**: Scores stored with one ID, searched with another

**Scenario**:
```
Score published: userId = "local_user"
Score normalized: userId = "_41be6d6ba28aca2ea78efff25c1e94a6" (CloudKit ID)
Score stored: userId = "_41be6d6..." (normalized)
Search: Looking for userId = "local_user" or profile.id
Result: Not found!
```

**Debug**:
```swift
print("🆔 Score userId: \(score.userId)")
print("🆔 Profile id: \(myLocalProfile?.id ?? "nil")")
print("🆔 CloudKit userId: \(ckUserId ?? "nil")")
print("🆔 Searching for: \(userIdToUse)")
```

#### 4.2 Profile Not Created
**Symptom**: `myLocalProfile` is `nil`  
**Check**: `MockSocialService.ensureProfile()` called  
**Fix**: Ensure profile is created on first use

---

### Category 5: Fetch/Merge Logic Issues

#### 5.1 CloudKit Fetch Fails Silently
**Symptom**: CloudKit error caught but local scores not returned  
**Check**: Error handling in `fetchLeaderboard()`  
**Fix**: Ensure local scores are always returned on CloudKit failure

#### 5.2 Local Row Not Found
**Symptom**: Local scores exist but `myLocalRow` is `nil`  
**Check**: Matching logic in merge code  
**Debug**: Print all local rows and their userIds

#### 5.3 Cache Stale
**Symptom**: Old cached results returned  
**Check**: Cache invalidation on score publish  
**Fix**: Invalidate cache when scores are published

---

## What We've Tried

### Attempt 1: Merge Local Scores with CloudKit
**Approach**: Always fetch local scores and merge with CloudKit results  
**Why It Failed**: 
- CloudKit fetch might throw error before merge happens
- Local row matching logic might be wrong
- Date filtering might exclude scores

### Attempt 2: Non-Blocking CloudKit Fetch
**Approach**: Wrap CloudKit fetch in try-catch, continue with local scores  
**Why It Failed**:
- Still had issues with local row matching
- Date filtering still problematic

### Attempt 3: Improved Local Row Matching
**Approach**: Check multiple userId formats ("local_user", profile.id, etc.)  
**Why It Failed**:
- Might not cover all cases
- Still depends on scores being stored correctly

### Attempt 4: Direct Local Return on CloudKit Failure
**Approach**: If CloudKit fails or empty, return local scores directly  
**Why It Failed**:
- Assumes local scores are correct
- Doesn't address root cause (scores might not be published)

---

## Systematic Debugging Approach

### Step 1: Verify Score Publishing

Add comprehensive logging:

```swift
// In AppState.addGameResult()
if !isGuestMode {
    logger.info("📤 Attempting to publish score for \(result.gameName)")
    Task {
        guard let social = self.socialService else {
            logger.error("❌ socialService is nil!")
            return
        }
        // ... create score ...
        do {
            try await social.publishDailyScores(dateUTC: result.date, scores: [score])
            logger.info("✅ Score published successfully")
        } catch {
            logger.error("❌ Failed to publish score: \(error)")
        }
    }
} else {
    logger.warning("⚠️ Guest mode active - skipping score publish")
}
```

### Step 2: Verify Score Filtering

```swift
// In CloudKitSocialService.publishDailyScores()
let publishableScores = scores.filter { shouldShare(score: $0) }
logger.info("📊 Filtered \(scores.count) scores → \(publishableScores.count) publishable")
if publishableScores.isEmpty {
    logger.warning("⚠️ All scores filtered out!")
    // Log why each was filtered
    for score in scores {
        let game = Game.allAvailableGames.first(where: { $0.id == score.gameId })
        let shouldShare = socialSettingsService.shouldShare(score: score, game: game)
        logger.info("  - \(score.gameName): shouldShare=\(shouldShare)")
    }
}
```

### Step 3: Verify Local Storage

```swift
// In MockSocialService.publishDailyScores()
logger.info("💾 Storing \(scores.count) scores locally")
var existing = load([DailyGameScore].self, forKey: scoresKey) ?? []
logger.info("📦 Existing scores: \(existing.count)")
// ... upsert logic ...
logger.info("💾 Saving \(existing.count) total scores")
try save(existing, forKey: scoresKey)

// Verify save succeeded
let verify = load([DailyGameScore].self, forKey: scoresKey) ?? []
logger.info("✅ Verified: \(verify.count) scores in storage")
```

### Step 4: Verify Date Formatting

```swift
// In fetchLeaderboard()
logger.info("📅 Fetching leaderboard:")
logger.info("  - startDateUTC: \(startDateUTC) → \(startDateUTC.utcYYYYMMDD)")
logger.info("  - endDateUTC: \(endDateUTC) → \(endDateUTC.utcYYYYMMDD)")

// In MockSocialService.fetchLeaderboard()
let all = load([DailyGameScore].self, forKey: scoresKey) ?? []
logger.info("📦 Loaded \(all.count) total scores from storage")
for score in all {
    logger.info("  - \(score.gameName): dateInt=\(score.dateInt), userId=\(score.userId)")
}
let filtered = all.filter { $0.dateInt >= start && $0.dateInt <= end }
logger.info("📊 Filtered to \(filtered.count) scores in date range")
```

### Step 5: Verify User ID Matching

```swift
// In fetchLeaderboard merge logic
let myLocalProfile = try? await mockService.myProfile()
logger.info("👤 My profile: \(myLocalProfile?.id ?? "nil")")
logger.info("👤 CloudKit userId: \(ckUserId ?? "nil")")
logger.info("📋 Local rows: \(localRows.count)")
for row in localRows {
    logger.info("  - userId: \(row.userId), name: \(row.displayName), points: \(row.totalPoints)")
}
```

### Step 6: Check Cache

```swift
// In fetchLeaderboard()
let key = LeaderboardCacheKey(...)
if let cached = cachedLeaderboard(for: key) {
    logger.info("📦 Returning cached leaderboard: \(cached.count) rows")
    return cached
} else {
    logger.info("🔄 Cache miss - fetching fresh data")
}
```

---

## Generic Patterns & Lessons

### Pattern 1: Silent Failure Anti-Pattern

**Problem**: Using `try?` without logging
```swift
try? await social.publishDailyScores(...)  // ❌ Silent failure
```

**Solution**: Always log errors
```swift
do {
    try await social.publishDailyScores(...)
} catch {
    logger.error("Failed: \(error)")  // ✅ Logged
}
```

### Pattern 2: Early Return Without Fallback

**Problem**: Filtering out data without fallback
```swift
guard !publishableScores.isEmpty else { return }  // ❌ No fallback
```

**Solution**: Log why filtered, consider fallback
```swift
guard !publishableScores.isEmpty else {
    logger.warning("All scores filtered - check privacy settings")
    return  // ✅ At least logged
}
```

### Pattern 3: ID Normalization Mismatch

**Problem**: Storing with one ID, searching with another
```swift
// Store: userId = normalizedCloudKitId
// Search: userId = "local_user"
// Result: Not found!
```

**Solution**: Consistent ID mapping
```swift
// Always use same ID for same user
let userIdToUse = ckUserId ?? localUserId  // ✅ Consistent
```

### Pattern 4: Date Format Inconsistency

**Problem**: Different date formats in storage vs filtering
```swift
// Store: dateInt = localTime.yyyyMMdd
// Filter: dateInt = utcTime.yyyyMMdd
// Result: Mismatch!
```

**Solution**: Always use UTC for dates
```swift
let dateInt = date.utcYYYYMMDD  // ✅ Always UTC
```

### Pattern 5: Cache Invalidation

**Problem**: Cache not invalidated when data changes
```swift
// Publish score → Cache still has old data
// Fetch leaderboard → Returns stale cache
```

**Solution**: Invalidate on write
```swift
func publishDailyScores(...) {
    // ... save scores ...
    invalidateLeaderboardCache()  // ✅ Invalidate
}
```

### Pattern 6: Hybrid Storage Complexity

**Problem**: Multiple storage layers (local + CloudKit) create complexity
```swift
// Fetch from CloudKit → merge with local → handle errors → normalize IDs
// Too many moving parts!
```

**Solution**: Clear separation, fallback strategy
```swift
// 1. Always fetch local (source of truth)
// 2. Try CloudKit (enhancement)
// 3. Merge intelligently
// 4. Fallback to local on any error
```

---

## Recommended Next Steps

1. **Add Comprehensive Logging**
   - Log every step of publish flow
   - Log every step of fetch flow
   - Log date conversions
   - Log user ID transformations

2. **Verify Score Storage**
   - Check UserDefaults directly: `UserDefaults.standard.array(forKey: "social_mock_scores")`
   - Verify scores are actually saved
   - Check dateInt values match expected format

3. **Test Date Filtering**
   - Add test score with known dateInt
   - Query with matching date range
   - Verify it appears

4. **Test User ID Matching**
   - Print all userIds in storage
   - Print profile ID
   - Print CloudKit user ID
   - Verify matching logic works

5. **Check Privacy Settings**
   - Verify game is not set to `.privateScope`
   - Verify `shareIncompleteGames` setting
   - Verify `hideZeroPointScores` setting

6. **Simplify for Debugging**
   - Temporarily bypass all filters
   - Return all local scores regardless of date
   - Verify basic flow works
   - Then add filters back one by one

---

## Conclusion

The issue is likely one of these:
1. **Scores not being published** (guest mode, service nil, filtered out)
2. **Scores not being stored** (UserDefaults failure, encoding issue)
3. **Date mismatch** (wrong dateInt, timezone issue)
4. **User ID mismatch** (searching for wrong ID)
5. **Cache stale** (old cached results returned)

The systematic debugging approach above will identify which one. Start with Step 1 (verify publishing) and work through each step until you find where the flow breaks.

