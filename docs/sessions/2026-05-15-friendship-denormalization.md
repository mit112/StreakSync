# Session Notes: Friendship Real-Time Updates + Denormalization
**Date:** 2026-05-15 (afternoon — follow-on to the morning's `account-linking-and-firestore-rules` session)

## Symptoms Reported

1. With the `Manage Friends` sheet open on both devices, sending a friend request from device A did **not** show up on device B's open sheet until B closed and reopened it.
2. Accepting a friend request produced a `Missing or insufficient permissions` toast on the accepting device. The friendship doc **was** committed correctly on Firestore (verified via Firebase MCP) but neither device showed the new friend.

## Root Causes

### 1. The sheet had no real-time listener
`FriendManagementView` loaded `friends` and `pendingRequests` only inside its initial `.task { await load() }`. `FriendsViewModel` already owned a Firestore friendship listener that called `refresh()`, but that updated the VM's state — never the sheet's `@State`.

### 2. `reconcileAllowedReadersForFriendshipChange` query was unprovable
```swift
db.collection("scores")
  .whereField("userId", isEqualTo: currentUID)
  .whereField("dateInt", isGreaterThanOrEqualTo: cutoffInt)
```
The score read rule is `request.auth.uid in resource.data.allowedReaders`. Firestore validates list-query rules against query constraints — `userId == me` doesn't prove `me ∈ allowedReaders`, so the whole query was rejected. Owners are always in `allowedReaders` by the create rule, so the constraint is satisfiable; just had to add it.

### 3. `getDocument()` under offline persistence routes through Watch
The previous session concluded "individual `getDocument()` reads make `areFriends()` work per-document." That turned out to be **wrong** when the iOS SDK has `PersistentCacheSettings` enabled (the default). Even one-shot `getDocument()` calls go through the gRPC Watch API internally, and Watch streams don't reliably honor `get()`/`exists()` cross-doc lookups inside rule bodies. Result: `Listen for query at users/{id} failed: Missing or insufficient permissions` even when the friendship was committed and `accepted` on the server.

### 4. `listFriends()` cache was stale on the sender's side
60-second TTL cache, invalidated only on local mutations (`acceptFriendRequest`, `removeFriend`). When the **other** party accepted, the sender's listener fired but `listFriends()` returned the cached empty array.

## Fixes Applied

| Layer | Change |
|---|---|
| Schema | Friendship doc gains `recipientDisplayName` alongside the existing `senderDisplayName`. Sender writes it at send time (from `lookupByFriendCode` result, fallback to `friendCodes` query); recipient refreshes it on accept. |
| `firestore.rules` | Friendship `create` accepts `recipientDisplayName`; `update` (accept) permits refreshing it; enforces createdAt + senderDisplayName immutability. Audit date bumped. |
| `FirebaseSocialService+Friends.swift` | `sendFriendRequest(toUserId:recipientDisplayName:)` (new optional param). `acceptFriendRequest` uses `source: .server` for the existence check and refreshes `recipientDisplayName`. `listFriends` derives friend identity from friendship docs (no `/users` reads). `fetchProfiles` (now a rare fallback) uses `source: .server`. |
| `FirebaseSocialService+Leaderboard.swift` | `fetchDisplayNames` derives from cached `listFriends` + self profile. No `/users` reads. The friendship listener handler now also clears `cachedFriends` before notifying consumers, so remote-driven changes surface immediately. |
| `FirebaseSocialService+Scores.swift` | `reconcileAllowedReadersForFriendshipChange` query adds `whereField("allowedReaders", arrayContains: currentUID)`. |
| `FriendsViewModel.swift` | New `@Published friendshipChangeTick: Int`, bumped inside the existing friendship listener handler. |
| `FriendManagementView.swift` | Accepts `friendshipChangeTick` parameter; `.onChange(of: friendshipChangeTick)` triggers `loadFriendshipState()`. Removed the AsyncStream that previously opened a second Firestore listener from this sheet. |
| `MockSocialService.swift` | Protocol conformance for new `sendFriendRequest` signature. |
| `firestore-rules-tests/firestore.rules.test.mjs` | New cases: create with `recipientDisplayName`, oversized rejection, accept refresh, senderDisplayName/createdAt immutability. All 99 tests pass. |

## Deployment Gotchas

- **MCP `firebase_deploy` reported success but uploaded nothing** — the deployed rules stayed at a months-old version. Likely the MCP server's working directory has no `firebase.json`. Lesson: always verify with `mcp__firebase__firebase_get_security_rules` after deploy. See `[[feedback_mcp_firebase_deploy_silent_failure]]`.
- **Firebase CLI deploy failed with 403** on a "project-XXX" ID unrelated to ours — the quota-billing project from gcloud's ADC. Fix: `GOOGLE_CLOUD_QUOTA_PROJECT=streaksync-55ca0 firebase deploy --only firestore:rules --project streaksync-55ca0`. See `[[feedback_firebase_cli_quota_project]]`.

## Sequence to Reach Working Flow

1. Initial deploy via MCP — silently no-op. Friend-request create rejected because the deployed rules didn't allow `recipientDisplayName`.
2. CLI deploy hit quota-project 403.
3. Set `GOOGLE_CLOUD_QUOTA_PROJECT` and deploy via CLI — rules actually updated.
4. Send request → succeeded; receiving device's open sheet auto-populated.
5. Accept → friend appeared on receiving device but not on sender's open sheet (the stale-cache bug).
6. Cache invalidation added to the friendship listener handler — sender's sheet now updates live too.
7. Duplicate listener cleanup: replaced the sheet's own `AsyncStream`-wrapped listener with a published `friendshipChangeTick` from `FriendsViewModel`. Only one Firestore listener per user now.

## Files Changed

| File | Lines |
|---|---|
| `StreakSync/Core/Services/Social/SocialService.swift` | +/- protocol signature, Friendship model adds `recipientDisplayName` + `otherDisplayName(me:)` |
| `StreakSync/Core/Services/Social/FirebaseSocialService.swift` | (untouched — `fetchProfiles` lives in +Friends) |
| `StreakSync/Core/Services/Social/FirebaseSocialService+Friends.swift` | listFriends rewrite, sendFriendRequest signature, acceptFriendRequest .server source + name refresh, new `fetchRecipientDisplayName` helper |
| `StreakSync/Core/Services/Social/FirebaseSocialService+Leaderboard.swift` | fetchDisplayNames rewrite, listener handler clears cache |
| `StreakSync/Core/Services/Social/FirebaseSocialService+Scores.swift` | reconcile query adds arrayContains filter |
| `StreakSync/Core/Services/Social/MockSocialService.swift` | protocol conformance for new sendFriendRequest signature (both Mock + ReviewMode) |
| `StreakSync/Features/Friends/ViewModels/FriendsViewModel.swift` | `@Published friendshipChangeTick`; listener handler bumps it |
| `StreakSync/Features/Friends/Views/FriendManagementView.swift` | Replaces AsyncStream with `.onChange`; new `loadFriendshipState`; passes recipient name into sendFriendRequest |
| `StreakSync/Features/Shared/Views/FriendsView.swift` | Passes `viewModel.friendshipChangeTick` into both sheet instantiations |
| `firestore.rules` | Friendship create/update updated for `recipientDisplayName`; immutability of senderDisplayName + createdAt |
| `firestore-rules-tests/firestore.rules.test.mjs` | New test cases (99 total, all pass) |

## Outstanding / Future Work

- AppCheck DeviceCheck failing on simulator (`App not registered: 1:828326244816:ios:...`). Firestore enforcement is currently off so it's noise, but turning enforcement on requires wiring the debug provider for sim/dev builds.
- Profile-rename fan-out to friendship docs not implemented. If a user changes displayName, friendship docs keep the stale name until the next accept (sender→stale forever; recipient refreshes on next accept). Acceptable for v1.
- Account linking UX (Apple ↔ Google merge prompt) still open from the morning session.
