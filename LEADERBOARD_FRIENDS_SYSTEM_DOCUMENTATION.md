# Leaderboard & Friends System - Comprehensive Documentation

## Overview

The StreakSync app implements a sophisticated social leaderboard and friends system that enables users to compete with friends across multiple daily puzzle games. The system supports both local-only operation (for privacy/offline use) and cloud-based real-time synchronization via CloudKit.

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    UI Layer (SwiftUI)                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │ FriendsView  │  │FriendMgmtView│  │GameLeaderboard│   │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘   │
└─────────┼──────────────────┼──────────────────┼──────────┘
          │                  │                  │
          └──────────────────┼──────────────────┘
                             │
          ┌──────────────────▼──────────────────┐
          │      FriendsViewModel                │
          │  (State Management & Coordination)   │
          └──────────────────┬──────────────────┘
                             │
          ┌──────────────────▼──────────────────┐
          │      SocialService Protocol          │
          └──────────────────┬──────────────────┘
                             │
          ┌──────────────────▼──────────────────┐
          │   HybridSocialService                │
          │  (CloudKit vs Local Selection)        │
          └──────┬───────────────────┬──────────┘
                 │                   │
    ┌────────────▼──────┐  ┌─────────▼──────────┐
    │ LeaderboardSync   │  │ MockSocialService  │
    │ Service (CloudKit)│  │  (Local Storage)    │
    └────────────┬──────┘  └────────────────────┘
                 │
    ┌────────────▼──────┐
    │   CloudKit        │
    │   (CKShare Zones) │
    └───────────────────┘
```

### Core Components

#### 1. **SocialService Protocol** (`Core/Services/Social/SocialService.swift`)

The foundational protocol that defines the social features contract:

```swift
protocol SocialService: Sendable {
    // Profile Management
    func ensureProfile(displayName: String?) async throws -> UserProfile
    func myProfile() async throws -> UserProfile
    
    // Friends Management
    func generateFriendCode() async throws -> String
    func addFriend(using code: String) async throws
    func listFriends() async throws -> [UserProfile]
    
    // Score Publishing & Leaderboards
    func publishDailyScores(dateUTC: Date, scores: [DailyGameScore]) async throws
    func fetchLeaderboard(startDateUTC: Date, endDateUTC: Date) async throws -> [LeaderboardRow]
}
```

**Key Data Models:**
- `UserProfile`: User identity with display name and friend code
- `DailyGameScore`: Individual game result with composite ID `userId|dateInt|gameId`
- `LeaderboardRow`: Aggregated leaderboard entry with total points and per-game breakdown

#### 2. **HybridSocialService** (`Core/Services/Social/HybridSocialService.swift`)

The adaptive service that automatically selects between CloudKit and local storage:

**Key Features:**
- **Automatic Detection**: Checks CloudKit availability on initialization
- **Graceful Fallback**: Falls back to `MockSocialService` when CloudKit unavailable
- **Dual Storage**: When CloudKit is available, stores both in cloud and locally for offline access
- **User ID Normalization**: Maps local user IDs to CloudKit record names when publishing

**Service Status:**
- `.cloudKit`: Real-time sync enabled, scores sync across devices
- `.local`: Local-only mode, scores stored on device only

**Implementation Details:**
- CloudKit availability is checked asynchronously on init
- User record name is cached after first fetch
- Scores are normalized to use CloudKit user IDs when publishing to shared groups

#### 3. **MockSocialService** (`Core/Services/Social/MockSocialService.swift`)

Local-only implementation using UserDefaults:

**Storage Keys:**
- `social_mock_user_profile`: Current user's profile
- `social_mock_friends`: Array of friend codes
- `social_mock_scores`: Array of `DailyGameScore` records

**Features:**
- Device-stable user ID generation (stored in UserDefaults)
- Friend code generation from user ID suffix
- Local score aggregation for leaderboards
- Zero external dependencies

**Limitations:**
- No cross-device sync
- Friend codes are local-only (no remote lookup)
- Scores only visible on local device

#### 4. **LeaderboardSyncService** (`Core/Services/Social/LeaderboardSyncService.swift`)

CloudKit-based synchronization using CKShare for friend groups:

**Architecture:**
- **One Zone Per Group**: Each leaderboard group has its own shared zone (`leaderboard_{groupId}`)
- **CKShare-Based**: Uses CloudKit's sharing mechanism for friend discovery
- **Root Record**: `LeaderboardGroup` record serves as the share root
- **Score Records**: `DailyScore` records stored in the shared zone

**Key Operations:**

1. **Creating a Group (Owner)**:
   ```swift
   func createGroup(title: String) async throws -> (groupId: UUID, share: CKShare)
   ```
   - Creates a new zone with unique UUID
   - Creates `LeaderboardGroup` root record
   - Creates `CKShare` for the root record
   - Sets up zone subscription for real-time updates
   - Returns share ready for `UICloudSharingController`

2. **Accepting a Share (Recipient)**:
   ```swift
   func acceptShare(metadata: CKShare.Metadata) async throws
   ```
   - Accepts share via `CKAcceptSharesOperation`
   - Sets up zone subscription in shared database
   - Extracts group ID from root record name
   - Stores group ID in `LeaderboardGroupStore`

3. **Publishing Scores**:
   ```swift
   func publishDailyScore(groupId: UUID, score: DailyGameScore) async throws
   ```
   - Upserts score record in shared zone
   - Uses composite ID: `userId|dateInt|gameId`
   - Stores in shared database (accessible to all participants)

4. **Fetching Scores**:
   ```swift
   func fetchScores(groupId: UUID, dateInt: Int?) async throws -> [CKRecord]
   ```
   - Queries `DailyScore` records from shared zone
   - Optional date filtering
   - Returns raw CloudKit records (converted to `DailyGameScore` by caller)

5. **Participant Display Names**:
   ```swift
   func participantDisplayNames(for groupId: UUID) async -> [String: String]
   ```
   - Extracts participant list from `CKShare`
   - Uses `PersonNameComponentsFormatter` for display names
   - Maps CloudKit user record names to display names

**Zone Subscription:**
- Each group zone has a subscription: `leaderboard_{groupId}_sub`
- Enables silent push notifications for real-time updates
- Subscription created automatically when group is created/accepted

#### 5. **LeaderboardGroupStore** (`Core/Services/Social/LeaderboardGroupStore.swift`)

Simple persistence for the active leaderboard group:

**Storage:**
- `selectedLeaderboardGroupId`: UUID of active group (UserDefaults)
- `selectedLeaderboardGroupTitle`: Display name of active group

**Purpose:**
- Tracks which shared group the user is currently participating in
- Used by `HybridSocialService` to determine where to publish scores
- Persists across app launches

#### 6. **LeaderboardScoring** (`Core/Models/Social/LeaderboardScoring.swift`)

Centralized scoring logic that normalizes different game types:

**Scoring Models:**

1. **lowerAttempts / lowerGuesses** (Wordle, Nerdle, etc.):
   - Formula: `maxAttempts - score + 1`
   - Example: Wordle with 6 max attempts, solved in 3 → 4 points

2. **lowerHints** (Strands):
   - Formula: `maxAttempts - usedHints + 1`
   - Example: 10 max hints, used 2 → 9 points

3. **lowerTimeSeconds** (Mini Crossword, etc.):
   - Time buckets mapped to 1-7 scale:
     - 0-29s: 7 points
     - 30-59s: 6 points
     - 60-89s: 5 points
     - 90-119s: 4 points
     - 120-149s: 3 points
     - 150-179s: 2 points
     - ≥180s: 1 point

4. **higherIsBetter** (Spelling Bee):
   - Raw score capped at 7 points
   - Direct mapping: score → points (max 7)

**Metric Labels:**
- Converts points back to human-readable format
- Examples: "3 guesses", "<1m", "5 pts", "2 hints"

**Key Design Decisions:**
- All scoring produces positive integers (higher is better)
- Points normalized to 1-7 range for UI consistency
- Incomplete games score 0 points
- Scoring is per-game (comparison only within same game)

#### 7. **FriendsViewModel** (`Features/Friends/ViewModels/FriendsViewModel.swift`)

The main coordinator for social features:

**State Management:**
- `@Published` properties for all UI state
- Persists UI state (selected date, game page, range) to UserDefaults
- Manages loading states and error messages

**Key Features:**

1. **Date Range Management**:
   - `.today`: Single day leaderboard
   - `.sevenDays`: Rolling 7-day window
   - Date paging with bounds checking (can't go past today)

2. **Rank Delta Calculation**:
   - Compares today's rank vs yesterday's rank
   - Shows ↑/↓ indicators for rank changes
   - Only computed for `.today` range

3. **Real-time Refresh**:
   - Periodic refresh every 30 seconds when CloudKit enabled
   - Debounced refresh for UI changes (180ms delay)
   - Manual refresh via pull-to-refresh

4. **Game Filtering**:
   - Only shows `Game.popularGames` (games displayed on homepage)
   - TabView for swiping between games
   - Per-game leaderboard projection

5. **Leaderboard Aggregation**:
   - Fetches scores for date range
   - Aggregates per user with per-game breakdown
   - Sorts by total points (descending)

**UI State Persistence:**
- `friends_last_selected_date`: Last viewed date
- `friends_last_game_page`: Last viewed game index
- `friends_last_range`: Last selected range (today/sevenDays)

#### 8. **FriendsView** (`Features/Shared/Views/FriendsView.swift`)

Main UI for social features:

**Layout:**
- Header with service status indicators
- TabView for swiping between games
- Game icon carousel at bottom
- Pull-to-refresh support
- Error overlay for user feedback

**Service Status Indicators:**
- CloudKit: Shows "Real-time Sync" with iCloud icon
- Local: Shows "Local Storage" with external drive icon
- Sharing: Shows "Sharing" / "Not sharing" based on active group

**Date Controls:**
- Segmented control for Today/7 Days
- Date pager with chevrons
- Long-press date for calendar picker

**Game Leaderboard Pages:**
- Each game gets its own `GameLeaderboardPage`
- Shows rank, avatar, name, metric, rank delta
- Highlights current user's row
- Empty state with invite friends CTA

#### 9. **FriendManagementView** (`Features/Friends/Views/FriendManagementView.swift`)

UI for managing friends and sharing:

**Sections:**

1. **Your Code**:
   - Displays friend code
   - Copy button
   - Share button (UIActivityViewController)

2. **Add a Friend**:
   - Text field for friend code
   - Add button (calls `socialService.addFriend`)

3. **Friends List**:
   - Shows all friends from `listFriends()`
   - Displays name and friend code

4. **Friends Sharing** (CloudKit):
   - Shows active group status
   - "Invite Friends" button (creates/ensures share)
   - "Stop Sharing" button (clears local group selection)
   - Note: Clearing local selection doesn't revoke CloudKit share

**Share Flow:**
1. User taps "Invite Friends"
2. Calls `leaderboardSyncService.ensureFriendsShare()`
3. Gets or creates `CKShare`
4. Presents `ShareInviteView` (wraps `UICloudSharingController`)
5. User shares via Messages, Mail, etc.
6. Recipient accepts share link
7. App receives share metadata in `AppDelegate`
8. Calls `acceptShare` to join group

#### 10. **GameLeaderboardPage** (`Features/Shared/Components/GameLeaderboardPage.swift`)

Individual game leaderboard display:

**Features:**
- Rank number (1, 2, 3...)
- Gradient avatar with initials
- Display name (bold for current user)
- Rank delta indicator (↑/↓ with color)
- Metric text (game-specific)
- Empty state with invite CTA
- Loading skeleton placeholders

**Accessibility:**
- Full VoiceOver labels
- Rank delta announcements
- Proper accessibility traits

## Data Flow

### Publishing a Score

```
1. User completes a game
   ↓
2. AppState.addGameResult() called
   ↓
3. Creates DailyGameScore from GameResult
   ↓
4. Calls socialService.publishDailyScores()
   ↓
5. HybridSocialService checks CloudKit availability
   ├─ CloudKit Available + Group Selected
   │  ├─ Normalize userId to CloudKit record name
   │  ├─ Call leaderboardSyncService.publishDailyScore()
   │  │  └─ Upsert CKRecord in shared zone
   │  └─ Also store locally (mockService)
   │
   └─ CloudKit Unavailable OR No Group
      └─ Store locally only (mockService)
```

### Fetching Leaderboard

```
1. User opens FriendsView
   ↓
2. FriendsViewModel.load() called
   ↓
3. Calls socialService.fetchLeaderboard(startDate, endDate)
   ↓
4. HybridSocialService checks CloudKit availability
   ├─ CloudKit Available + Group Selected
   │  ├─ Call leaderboardSyncService.fetchScores()
   │  │  └─ Query DailyScore records from shared zone
   │  ├─ Filter by date range
   │  ├─ Get participant display names
   │  ├─ Convert CKRecords to DailyGameScore
   │  └─ Aggregate per user
   │
   └─ CloudKit Unavailable OR No Group
      └─ Fetch from local storage (mockService)
         └─ Aggregate per user
   ↓
5. For each score, compute points via LeaderboardScoring.points()
   ↓
6. Aggregate: userId → (totalPoints, perGameBreakdown)
   ↓
7. Sort by totalPoints descending
   ↓
8. Return [LeaderboardRow]
```

### Real-time Updates

```
1. CloudKit detects change in shared zone
   ↓
2. Sends silent push notification
   ↓
3. AppDelegate.didReceiveRemoteNotification() called
   ↓
4. CloudKitSubscriptionManager.handleRemoteNotification()
   ↓
5. Extracts zone ID from notification
   ↓
6. If leaderboard zone:
   ├─ Fetch changed records
   ├─ Update local cache
   └─ Trigger UI refresh (if foreground)
   ↓
7. FriendsViewModel.refreshLeaderboard() called
   ↓
8. Re-fetch and update UI
```

## CloudKit Schema

### Record Types

#### LeaderboardGroup
- **Type**: `"LeaderboardGroup"`
- **Zone**: Custom shared zone (`leaderboard_{groupId}`)
- **Record ID**: `"group_{UUID}"`
- **Fields**:
  - `title: String` - Group display name
  - `createdAt: Date` - Creation timestamp
- **Purpose**: Root record for CKShare, identifies the group

#### DailyScore
- **Type**: `"DailyScore"`
- **Zone**: Same shared zone as parent `LeaderboardGroup`
- **Record ID**: `"{userId}|{yyyyMMdd}|{gameId}"` (composite)
- **Fields**:
  - `userId: String` - CloudKit user record name
  - `dateInt: Int` - Date as yyyyMMdd integer
  - `gameId: String` - UUID string of game
  - `gameName: String` - Display name of game
  - `score: Int?` - Optional score value
  - `maxAttempts: Int` - Maximum attempts allowed
  - `completed: Bool` - Whether game was completed
  - `updatedAt: Date` - Last update timestamp
- **Purpose**: Individual game result, shared with group participants

### Zones

#### LeaderboardGroup Zones
- **Format**: `"leaderboard_{UUID}"`
- **Type**: Custom shared zone
- **Created**: When user creates a new group
- **Shared Via**: CKShare of LeaderboardGroup root record
- **Records**: 1 LeaderboardGroup + many DailyScore records
- **Subscription**: `CKRecordZoneSubscription` per zone
- **Database**: Shared Cloud Database (after share acceptance)

## Scoring System Details

### Point Calculation Examples

**Wordle (lowerAttempts, maxAttempts=6):**
- Solved in 1 guess → 6 points
- Solved in 3 guesses → 4 points
- Solved in 6 guesses → 1 point
- Not completed → 0 points

**Mini Crossword (lowerTimeSeconds):**
- Completed in 15 seconds → 7 points
- Completed in 45 seconds → 6 points
- Completed in 2 minutes → 3 points
- Completed in 4 minutes → 1 point

**Spelling Bee (higherIsBetter):**
- Score of 50 → 7 points (capped)
- Score of 10 → 7 points (capped)
- Score of 5 → 5 points
- Score of 0 → 0 points

**Strands (lowerHints, maxAttempts=10):**
- Used 0 hints → 11 points (maxAttempts - 0 + 1)
- Used 2 hints → 9 points
- Used 5 hints → 6 points
- Used all 10 hints → 1 point

### Aggregation Logic

1. **Filter by Date Range**: Only scores within `startDateUTC...endDateUTC`
2. **Group by User**: Aggregate all scores per `userId`
3. **Compute Points**: For each score, call `LeaderboardScoring.points()`
4. **Sum Total**: Sum all points for user's total
5. **Per-Game Breakdown**: Sum points per `gameId` for breakdown
6. **Sort**: Sort users by `totalPoints` descending

### Display Labels

The `metricLabel()` function converts points back to human-readable format:

- **lowerAttempts**: "3 guesses", "6 guesses"
- **lowerHints**: "1 hint", "5 hints"
- **lowerTimeSeconds**: "<30s", "<1m", "<2m", ">=3m"
- **higherIsBetter**: "1 pt", "7 pts"

## Friend Management

### Friend Codes (Local Mode)

**Generation:**
- Last 6 characters of device user ID
- Stored in `UserProfile.friendCode`
- Example: `"a1b2c3"`

**Adding Friends:**
- User enters friend code
- Stored in UserDefaults array
- No remote lookup (local-only simulation)

**Limitations:**
- Codes are device-specific
- No cross-device friend discovery
- Primarily for development/testing

### CloudKit Sharing (Real Mode)

**Group Creation:**
1. User taps "Invite Friends"
2. System creates new group UUID
3. Creates shared zone
4. Creates LeaderboardGroup root record
5. Creates CKShare
6. Presents UICloudSharingController
7. User shares via Messages/Mail/etc.

**Share Acceptance:**
1. Recipient taps share link
2. iOS opens app with share metadata
3. `AppDelegate.userDidAcceptCloudKitShareWith()` called
4. `LeaderboardSyncService.acceptShare()` called
5. Share accepted via `CKAcceptSharesOperation`
6. Zone subscription created
7. Group ID stored in `LeaderboardGroupStore`
8. User can now see shared leaderboard

**Participant Discovery:**
- Friends are discovered via `CKShare.participants`
- Display names extracted from `CKShare.Participant.userIdentity`
- Uses `PersonNameComponentsFormatter` for formatting
- Owner is also included in participant list

## UI Components

### FriendsView Header

**Service Status Badges:**
- **CloudKit Mode**: Blue iCloud icon + "Real-time Sync"
- **Local Mode**: Gray external drive icon + "Local Storage"
- **Sharing Status**: Green people icon + "Sharing" or gray + "Not sharing"

**Date Controls:**
- Segmented control: Today / 7 Days
- Date pager: ← Date → with bounds checking
- Long-press date: Calendar picker sheet

**Game Title:**
- Large title showing current game name
- Updates as user swipes between games

### Game Leaderboard Page

**Row Components:**
- Rank number (left-aligned, fixed width)
- Gradient avatar (initials-based, color-coded)
- Display name (bold if current user)
- Rank delta (↑/↓ with color, only for today range)
- Metric text (game-specific format)

**Empty State:**
- Message: "No scores for {game}"
- Subtitle: "Pick a different date or invite friends to compare."
- CTA: "Invite friends" button

**Loading State:**
- Skeleton placeholders (6 rows)
- Redacted with shimmer effect

### Friend Management View

**Your Code Section:**
- Monospaced friend code display
- Copy button (triggers haptic)
- Share button (UIActivityViewController)

**Add Friend Section:**
- Text field (no autocapitalization, no autocorrect)
- Add button (disabled if empty)

**Friends List:**
- Name + friend code (monospaced, secondary)
- Empty state message

**Friends Sharing Section:**
- Active group info (if sharing)
- Group title and UUID
- "Stop Sharing" button (destructive)
- "Invite Friends" button
- Help text explaining iCloud sharing

## UI/UX Connection to System Architecture

This section explains how each UI element connects to the underlying system components and data flow.

### FriendsView - Main Leaderboard Screen

#### Status Indicators (Top Header)

**Visual Elements:**
- **"Local Storage" badge** (gray, external drive icon)
- **"Not sharing" badge** (gray, person icons)
- **"Invite Friends" button** (gray, paper airplane icon)
- **Sync status message**: "Not syncing. Enable iCloud later to sync across devices."

**System Connection:**
```
UI State: viewModel.serviceStatus (.local or .cloudKit)
         ↓
Source: HybridSocialService.serviceStatus
         ↓
Logic: Checks isCloudKitAvailable flag
         ↓
Display: Shows "Local Storage" if .local, "Real-time Sync" if .cloudKit
```

**Sharing Status:**
```
UI State: selectedGroupIdString (from @AppStorage)
         ↓
Source: LeaderboardGroupStore.selectedGroupId
         ↓
Logic: Checks if UUID exists in UserDefaults
         ↓
Display: "Sharing" (green) if group exists, "Not sharing" (gray) if nil
```

**Invite Friends Button:**
```
User Action: Tap paper airplane icon
         ↓
UI Handler: Sets viewModel.isPresentingManageFriends = true
         ↓
Sheet Presentation: FriendManagementView(socialService: viewModel.socialService)
         ↓
Purpose: Opens friend management interface
```

#### Date Range Controls

**Visual Elements:**
- **Segmented Control**: "Today" (selected, green) | "7 Days" (unselected)
- **Date Pager**: "← Nov 17, 2025 →" with navigation arrows

**System Connection:**
```
UI State: viewModel.range (.today or .sevenDays)
         ↓
User Action: Tap segment → Sets viewModel.range
         ↓
Persistence: Saved to UserDefaults key "friends_last_range"
         ↓
Data Fetch: Calls dateRange() → Returns (startDate, endDate)
         ↓
Leaderboard Query: socialService.fetchLeaderboard(startDate, endDate)
         ↓
UI Update: Refreshes leaderboard rows
```

**Date Pager:**
```
UI State: viewModel.selectedDateUTC
         ↓
User Action: Tap ← or → → Calls incrementDay(-1) or incrementDay(1)
         ↓
Validation: canIncrementDay() checks bounds (can't go past today)
         ↓
Update: Modifies selectedDateUTC via Calendar.date(byAdding:)
         ↓
Persistence: Saved to UserDefaults key "friends_last_selected_date"
         ↓
Refresh: Triggers Task { await viewModel.refresh() }
         ↓
Data Fetch: Re-fetches leaderboard for new date range
```

**Long-Press Date:**
```
User Action: Long-press date text
         ↓
UI Handler: Sets viewModel.isPresentingDatePicker = true
         ↓
Sheet Presentation: DatePicker with .graphical style
         ↓
User Selection: Updates selectedDateUTC
         ↓
On Dismiss: Calls refresh() and persists state
```

#### Game Leaderboard Display

**Visual Elements:**
- **Game Title**: "Wordle" (large, bold)
- **Ranked List**: 
  - Rank number (1, 2, 3...)
  - Gradient avatar (initials)
  - Display name ("Friend")
  - Metric text ("4 guesses")
  - Rank delta (↑/↓ with color, if applicable)

**System Connection:**
```
UI State: viewModel.currentGamePage (index)
         ↓
Game Selection: viewModel.availableGames[currentGamePage]
         ↓
Leaderboard Projection: viewModel.rowsForSelectedGameID(game.id)
         ↓
Data Source: Filters viewModel.leaderboard by gameId
         ↓
Point Calculation: LeaderboardScoring.points(for: score, game: game)
         ↓
Sorting: Sorted by points descending, then name ascending
         ↓
Display: GameLeaderboardPage(game: game, rows: filteredRows, ...)
```

**Rank Delta Calculation:**
```
Trigger: Only computed when range == .today
         ↓
Method: computeRankDeltasForToday()
         ↓
Data Fetch: 
  - Today: Uses current viewModel.leaderboard
  - Yesterday: Fetches via socialService.fetchLeaderboard(yesterday, yesterday)
         ↓
Rank Mapping: Creates [userId: rank] dictionaries for both days
         ↓
Delta Calculation: yesterdayRank - todayRank (positive = improved)
         ↓
UI State: viewModel.rankDeltas[userId] = delta
         ↓
Display: Shows ↑delta (green) or ↓delta (red) badge
```

**Empty State:**
```
Condition: rows.isEmpty
         ↓
Display: "No scores for {game.displayName}"
         ↓
CTA Button: "Invite friends" → Calls onManageFriends()
         ↓
Action: Opens FriendManagementView sheet
```

#### Game Selector (Bottom Carousel)

**Visual Elements:**
- Horizontal scrollable row of game icons
- Each icon shows: SF Symbol + game name
- Active game highlighted (green background, larger scale)

**System Connection:**
```
UI Component: GameIconCarousel (wrapped in CyclingDotsIndicator)
         ↓
Data Source: viewModel.availableGames (Game.popularGames)
         ↓
Current Selection: viewModel.currentGamePage
         ↓
User Action: Tap icon → onGameSelected(index)
         ↓
Update: Sets viewModel.currentGamePage = index
         ↓
Persistence: Saved to UserDefaults key "friends_last_game_page"
         ↓
TabView Sync: TabView(selection: $viewModel.currentGamePage) updates
         ↓
Leaderboard Update: New game's leaderboard loads automatically
```

**Scroll Position:**
```
State: scrollSelection (local @State)
         ↓
Initialization: Set to currentGamePage on appear
         ↓
User Scroll: Updates scrollSelection via ScrollView
         ↓
On Change: Calls onGameSelected(newIndex) → Updates currentGamePage
         ↓
Animation: Smooth scroll with .easeInOut(duration: 0.25)
```

#### Pull-to-Refresh

**User Action:**
```
User Gesture: Pull down on leaderboard
         ↓
SwiftUI: .refreshable modifier triggers
         ↓
Handler: await onRefresh?() → await viewModel.refresh()
         ↓
Data Fetch: Calls socialService.fetchLeaderboard()
         ↓
UI Update: Refreshes all leaderboard rows
         ↓
Rank Delta: Recomputes if range == .today
```

#### "Manage Friends" Button

**Visual Element:**
- Bottom button with person icons + "Manage friends" text

**System Connection:**
```
User Action: Tap button
         ↓
Handler: Calls onManageFriends()
         ↓
UI Update: Sets viewModel.isPresentingManageFriends = true
         ↓
Sheet Presentation: FriendManagementView(socialService: viewModel.socialService)
```

### FriendManagementView - Friend Management Screen

#### "Your Code" Section

**Visual Elements:**
- Friend code display: "554FEE" (monospaced font)
- "Copy" button (green text)
- "Share" button (green text)

**System Connection:**
```
Data Source: myFriendCode (from socialService.generateFriendCode())
         ↓
Load: Called in load() → await socialService.generateFriendCode()
         ↓
Source: 
  - Local: MockSocialService → Last 6 chars of device user ID
  - CloudKit: Same (friend codes not fully implemented in CloudKit mode)
         ↓
Copy Action: UIPasteboard.general.string = myFriendCode
         ↓
Share Action: UIActivityViewController with [myFriendCode] as activityItems
```

#### "Add a Friend" Section

**Visual Elements:**
- Text field: "Enter friend code" (placeholder)
- "Add" button (green text, disabled if empty)

**System Connection:**
```
UI State: friendCodeToAdd (@State String)
         ↓
User Input: TextField binds to friendCodeToAdd
         ↓
Validation: Button disabled if trimmed code isEmpty
         ↓
User Action: Tap "Add" → Calls addFriend()
         ↓
Handler: await socialService.addFriend(using: friendCodeToAdd)
         ↓
Implementation:
  - Local: MockSocialService → Appends code to UserDefaults array
  - CloudKit: Same (direct friend connections not implemented)
         ↓
Refresh: Calls listFriends() → Updates friends array
         ↓
UI Update: Clears friendCodeToAdd, refreshes friends list
```

#### "Friends" Section

**Visual Elements:**
- Empty state: "No friends yet. Share your code to connect!"
- Friend list: Name + friend code (when friends exist)

**System Connection:**
```
Data Source: friends (@State [UserProfile])
         ↓
Load: Called in load() → await socialService.listFriends()
         ↓
Source:
  - Local: MockSocialService → Maps friend codes to UserProfile objects
  - CloudKit: Same (direct friend lists not implemented, uses CKShare participants)
         ↓
Display: ForEach(friends) → Shows displayName and friendCode
         ↓
Empty State: Shows message if friends.isEmpty
```

#### "Friends Sharing" Section

**Visual Elements:**
- Status: "Not sharing yet" or group info (if sharing)
- "Invite Friends" button (green, prominent)
- Help text: "Shares your leaderboard with invited friends using iCloud."

**System Connection:**

**When Not Sharing:**
```
State: LeaderboardGroupStore.selectedGroupId == nil
         ↓
Display: "Not sharing yet" message
         ↓
Action Available: "Invite Friends" button enabled
```

**When Sharing:**
```
State: LeaderboardGroupStore.selectedGroupId != nil
         ↓
Data Load: 
  - activeGroupTitle from LeaderboardGroupStore.selectedGroupTitle
  - activeGroupIdText from LeaderboardGroupStore.selectedGroupId
         ↓
Display: Shows group title and UUID
         ↓
Stop Sharing Button: 
  - Action: LeaderboardGroupStore.clearSelectedGroup()
  - Effect: Removes group ID from UserDefaults (local only)
  - Note: Doesn't revoke CloudKit share (others keep access)
```

**Invite Friends Flow:**
```
User Action: Tap "Invite Friends"
         ↓
State: Sets isCreatingGroup = true (shows "Preparing...")
         ↓
Handler: await inviteFriends()
         ↓
CloudKit Operation: await leaderboardSyncService.ensureFriendsShare()
         ↓
Logic:
  1. Checks if selectedGroupId exists
  2. If exists: Fetches existing share or creates new one
  3. If not: Creates new group via createGroup()
     - Generates UUID
     - Creates zone: "leaderboard_{groupId}"
     - Creates LeaderboardGroup root record
     - Creates CKShare
     - Sets up zone subscription
         ↓
Storage: LeaderboardGroupStore.setSelectedGroup(id: groupId, title: "Friends")
         ↓
UI State: Sets createdShare = share, showShareSheet = true
         ↓
Sheet Presentation: ShareInviteView(share: share, container: container)
         ↓
UIKit Integration: Wraps UICloudSharingController
         ↓
User Action: Shares via Messages, Mail, etc.
         ↓
Recipient: Receives share link → Taps → iOS opens app
         ↓
AppDelegate: userDidAcceptCloudKitShareWith(metadata:)
         ↓
Acceptance: await leaderboardSyncService.acceptShare(metadata:)
         ↓
Result: Recipient joins group, sees shared leaderboard
```

### GameLeaderboardPage - Individual Game Leaderboard

#### Leaderboard Rows

**Visual Elements:**
- Rank number (left, fixed width)
- Gradient avatar (initials, color-coded)
- Display name (bold if current user)
- Rank delta badge (↑/↓ with color)
- Metric text (game-specific)

**System Connection:**
```
Data Source: rows: [(row: LeaderboardRow, points: Int)]
         ↓
Source: viewModel.rowsForSelectedGameID(game.id)
         ↓
Processing:
  1. Filters leaderboard by gameId
  2. Extracts points from perGameBreakdown[gameId]
  3. Sorts by points descending, then name ascending
         ↓
Row Rendering: ForEach(rows.indices) { index in ... }
         ↓
Rank Delta: rankDelta?[row.userId] (from viewModel.rankDeltas)
         ↓
Current User Highlight: row.userId == myUserId → Bold font
         ↓
Metric Text: metricText(points) → LeaderboardScoring.metricLabel(for: game, points: points)
```

**Gradient Avatar:**
```
Component: GradientAvatar(initials: String(displayName.prefix(1)))
         ↓
Color Selection: palette(for: initials) → Hash-based color palette
         ↓
Display: OptimizedAnimatedGradient with initials overlay
```

#### Loading State

**Visual Elements:**
- Skeleton placeholders (6 rows)
- Redacted appearance with shimmer

**System Connection:**
```
Condition: isLoading == true
         ↓
Display: ForEach(0..<6) → RoundedRectangle with .redacted(reason: .placeholder)
         ↓
Shimmer Effect: Optional shimmer modifier (not shown in current implementation)
```

#### Empty State

**Visual Elements:**
- Message: "No scores for {game.displayName}"
- Subtitle: "Pick a different date or invite friends to compare."
- CTA: "Invite friends" button

**System Connection:**
```
Condition: rows.isEmpty && !isLoading
         ↓
Display: VStack with message, subtitle, and button
         ↓
Button Action: onManageFriends() → Opens FriendManagementView
```

### Real-Time Updates

#### Periodic Refresh

**System Connection:**
```
Condition: viewModel.isRealTimeEnabled == true (CloudKit available)
         ↓
Initialization: startPeriodicRefresh() called in load()
         ↓
Timer: Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true)
         ↓
Handler: await refreshLeaderboard()
         ↓
Data Fetch: Re-fetches leaderboard without full reload
         ↓
UI Update: Updates leaderboard rows, recomputes rank deltas
```

#### CloudKit Push Notifications

**System Connection:**
```
CloudKit Event: Change in shared zone
         ↓
Push Notification: Silent push to device
         ↓
AppDelegate: didReceiveRemoteNotification(userInfo:)
         ↓
Handler: CloudKitSubscriptionManager.handleRemoteNotification()
         ↓
Zone Detection: Extracts zoneID from CKNotification
         ↓
If Leaderboard Zone:
  - Fetches changed records
  - Updates local cache
  - Triggers UI refresh (if foreground)
         ↓
UI Update: FriendsViewModel.refreshLeaderboard() called
         ↓
Visual: Leaderboard rows update automatically
```

### State Persistence

#### UI State Persistence

**Persisted Values:**
```
UserDefaults Keys:
  - "friends_last_selected_date": Date
  - "friends_last_game_page": Int
  - "friends_last_range": String (LeaderboardRange.rawValue)
  - "selectedLeaderboardGroupId": String (UUID.uuidString)
  - "selectedLeaderboardGroupTitle": String
```

**Persistence Flow:**
```
User Interaction: Changes date, game page, or range
         ↓
ViewModel: Updates @Published properties
         ↓
onChange Modifier: Detects change
         ↓
Persistence: Calls persistUIState() or direct UserDefaults.set()
         ↓
Restoration: On init, reads from UserDefaults
         ↓
UI Update: Restores previous state
```

### Error Display

**Visual Element:**
- Error overlay at top of screen
- Yellow warning icon + message + "Dismiss" button

**System Connection:**
```
State: viewModel.errorMessage (@Published String?)
         ↓
Source: Set when async operations throw errors
         ↓
Display: .overlay(alignment: .top) { if let message = errorMessage { ... } }
         ↓
Dismiss: Button sets errorMessage = nil
         ↓
Animation: .transition(.move(edge: .top).combined(with: .opacity))
```

### Bottom Navigation Integration

**Visual Element:**
- Bottom tab bar with "Friends" tab highlighted

**System Connection:**
```
Tab Selection: MainTabView manages tab state
         ↓
Friends Tab: Contains FriendsView
         ↓
Initialization: FriendsView(socialService: socialService)
         ↓
Data Load: .task { await viewModel.load() } on appear
         ↓
State Management: FriendsViewModel manages all social state
```

## Error Handling

### CloudKit Errors

**Common Errors:**
- `.notAuthenticated`: User not signed into iCloud
- `.networkUnavailable`: Offline, will retry
- `.quotaExceeded`: iCloud storage full
- `.permissionFailure`: Access removed from group
- `.zoneNotFound`: Zone doesn't exist (shouldn't happen)

**Handling Strategy:**
- Network errors: Silent retry with backoff
- Auth errors: Show user-friendly message
- Permission errors: Remove group, clean cache
- Other errors: Log and show generic message

### Local Storage Errors

**UserDefaults Failures:**
- Encoding errors: Log and continue
- Decoding errors: Return empty/default values
- Storage full: System handles (rare)

## Performance Considerations

### Caching

**User Record Name:**
- Cached after first fetch in `HybridSocialService`
- Avoids repeated CloudKit calls

**Leaderboard Data:**
- Not explicitly cached (fetched on demand)
- Real-time updates refresh automatically
- Debounced refresh prevents rapid reloads

### Optimization

**Score Aggregation:**
- Done in-memory after fetching
- Efficient dictionary-based grouping
- Single pass through scores

**UI Updates:**
- Debounced refresh (180ms) for rapid changes
- Periodic refresh (30s) only when CloudKit enabled
- Pull-to-refresh for manual updates

**CloudKit Queries:**
- Date filtering done in CloudKit query
- Reduces data transfer
- Efficient zone-based queries

## Testing

### Unit Tests

**LeaderboardScoringTests:**
- Tests all scoring models
- Validates point calculations
- Tests edge cases (zero scores, max scores)
- Validates metric label formatting

### Integration Points

**Score Publishing:**
- Triggered from `AppState.addGameResult()`
- Non-blocking (fire-and-forget)
- Best-effort (errors logged, not shown)

**Share Acceptance:**
- Handled in `AppDelegate`
- Requires `AppContainer` initialization
- Logs errors for debugging

## Future Enhancements

### Potential Improvements

1. **Multiple Groups:**
   - Support multiple leaderboard groups
   - Group switching UI
   - Per-group settings

2. **Friend Profiles:**
   - Direct friend connections (not just via groups)
   - Friend requests/approval system
   - Friend activity feed

3. **Advanced Leaderboards:**
   - All-time leaderboards
   - Monthly/weekly competitions
   - Custom date ranges
   - Filter by game

4. **Social Features:**
   - Comments on scores
   - Reactions/celebrations
   - Achievement sharing
   - Streak comparisons

5. **Performance:**
   - Leaderboard caching
   - Incremental updates
   - Background prefetching
   - Optimistic UI updates

## Key Files Reference

### Core Services
- `Core/Services/Social/SocialService.swift` - Protocol definition
- `Core/Services/Social/HybridSocialService.swift` - Main service implementation
- `Core/Services/Social/MockSocialService.swift` - Local fallback
- `Core/Services/Social/LeaderboardSyncService.swift` - CloudKit sync
- `Core/Services/Social/LeaderboardGroupStore.swift` - Group persistence
- `Core/Services/Social/CloudKitConfiguration.swift` - CloudKit config

### Models
- `Core/Models/Social/LeaderboardScoring.swift` - Scoring logic
- `Core/Models/Social/` - Data models (UserProfile, DailyGameScore, LeaderboardRow)

### View Models
- `Features/Friends/ViewModels/FriendsViewModel.swift` - Main coordinator

### Views
- `Features/Shared/Views/FriendsView.swift` - Main UI
- `Features/Friends/Views/FriendManagementView.swift` - Friend management
- `Features/Shared/Components/GameLeaderboardPage.swift` - Leaderboard display
- `Features/Shared/Components/ShareInviteView.swift` - Share UI wrapper

### App Integration
- `StreakSync/App/AppDelegate.swift` - Share acceptance handling
- `StreakSync/App/AppContainer.swift` - Service initialization

## Summary

The leaderboard/friends system is a sophisticated hybrid architecture that:

1. **Works Offline**: Full local mode via `MockSocialService`
2. **Syncs When Available**: Automatic CloudKit integration when enabled
3. **Uses Modern Patterns**: CKShare for friend discovery, zone subscriptions for real-time updates
4. **Normalizes Scoring**: Unified point system across different game types
5. **Provides Rich UI**: Swipeable game leaderboards, rank deltas, real-time updates
6. **Handles Errors Gracefully**: Fallbacks, retries, user-friendly messages

The system is designed to be:
- **Privacy-First**: Local mode available, CloudKit optional
- **User-Friendly**: Simple friend codes, easy sharing
- **Performant**: Efficient queries, debounced updates
- **Extensible**: Protocol-based, easy to add features

