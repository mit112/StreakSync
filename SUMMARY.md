# Firebase Social Migration Progress and Current Status

## Work Completed
- **Firebase social backend:** Replaced CKShare flows with `FirebaseSocialService` using Firestore/Auth for groups, join codes, score publishing/fetching, and basic friend discovery from group membership. Kept `MockSocialService` for offline/guest.
- **UI changes:** Removed CKShare status/UI artifacts; invite flows now use join codes.
- **Caching models:** Added `LeaderboardCacheKey(startDateInt, endDateInt, groupId?)` and `LeaderboardCacheEntry(rows, timestamp)` for leaderboard cache store.
- **Firebase integration:** Code initializes Firebase Core/Auth/Firestore; Anonymous Auth runs in `StreakSyncApp`.
- **Config cleanup:** Renamed Firebase config to `GoogleService-Info.plist` (bundle ID `com.mitsheth.StreakSync`), located under `StreakSync/`.
- **Dependencies:** FirebaseAuth and FirebaseFirestore are present via SPM.

## Current Blocker
- Firestore rules are still default-deny, causing:
  - “Missing or insufficient permissions” on `groups`/`scores` reads/writes.
  - “Join code is invalid” because group create/join is blocked.
  - Logs: `Listen for query at groups/scores failed: Missing or insufficient permissions.`

## Required Firestore Rules (replace and publish)
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isSignedIn() { return request.auth != null; }
    function isMember(groupId) {
      return isSignedIn()
        && exists(/databases/$(database)/documents/groups/$(groupId))
        && get(/databases/$(database)/documents/groups/$(groupId)).data.memberIds.hasAny([request.auth.uid]);
    }

    match /users/{userId} {
      allow read, write: if isSignedIn() && request.auth.uid == userId;
    }

    match /groups/{groupId} {
      allow read: if isSignedIn() && isMember(groupId);
      allow create: if isSignedIn()
        && request.resource.data.ownerId == request.auth.uid
        && request.resource.data.memberIds == [request.auth.uid];
      allow update: if isSignedIn()
        && isMember(groupId)
        && request.resource.data.memberIds.hasAny([request.auth.uid]);
      allow delete: if false;
    }

    match /scores/{scoreId} {
      allow read: if isSignedIn() && isMember(resource.data.groupId);
      allow create, update: if isSignedIn()
        && request.resource.data.userId == request.auth.uid
        && isMember(request.resource.data.groupId);
      allow delete: if false;
    }

    match /friendships/{friendshipId} {
      allow read, write: if false;
    }
  }
}
```

## Firestore Indexes (should be present)
1) Collection group `scores`: `groupId` ASC, `dateInt` ASC.  
2) Collection group `scores`: `groupId` ASC, `userId` ASC, `dateInt` ASC.

## Post-Rules Validation Checklist
- Create a group from Manage Friends; confirm no permission error and a join code appears.
- Join a group with a code (second device or reinstall); verify membership and leaderboard fetch.
- Publish a score; ensure it appears under the correct user in the leaderboard.
- If groups were created while rules were denying writes, recreate a fresh group after rules are updated.

## Notes
- Ensure `GoogleService-Info.plist` is included in the `StreakSync` app target membership in Xcode (share extension unchecked unless it uses Firebase).

