# Session Notes: Account Linking + Firestore Rules Debugging
**Date:** 2026-05-15

## What We Built

Completed the anonymous → social provider upgrade detection feature (designed previous session), then spent the majority of the session debugging a persistent Firestore permission error that was discovered during testing.

---

## Feature: Anonymous → Social Provider Upgrade (AppContainer)

### Changes Made

**`StreakSync/App/AppContainer.swift`**
- Added `lastKnownProvider: AuthProvider` tracking alongside the existing `lastKnownUID`
- `setupAuthStateObserver()` now distinguishes two cases in the `$currentUser` subscriber:
  - **UID changed** → `handleAuthUserChanged` (full data wipe + re-sync)
  - **Same UID, anonymous → social** → `handleProviderUpgraded` (incremental sync + profile update)
- Added `handleProviderUpgraded(to:displayName:)`: writes updated authProvider + displayName to Firestore, then syncs
- Added two static helpers:
  - `private static func deriveProvider(from user: User?) -> AuthProvider` — thin wrapper, handles `isAnonymous` check
  - `internal nonisolated static func deriveProvider(fromProviderIDs ids: [String]) -> AuthProvider` — pure string logic, `nonisolated` so tests can call it without hopping to MainActor

**`StreakSync/Core/Services/Social/FirebaseAuthStateManager.swift`**
- Removed 5 direct `authProvider = .X` assignments from sign-in handlers (Apple and Google)
- `setupAuthListener`'s `detectProvider(for:)` is now the sole source of truth for `authProvider`

**`StreakSync/Core/Services/Social/FirebaseSocialService.swift`**
- Fixed `ensureProfile()` provider detection: was hardcoded `"apple"`, now uses `AppContainer.deriveProvider(fromProviderIDs:)` from the actual Firebase user's `providerData`
- Removed dead `"friends": [String]()` field from profile creation payload

**`StreakSyncTests/AuthProviderDerivationTests.swift`** (new file)
- 9 unit tests for `AppContainer.deriveProvider(fromProviderIDs:)` and `AuthProvider.rawValue` stability
- `nonisolated` on the static func was the key to making synchronous XCTest calls work with a `@MainActor` class

---

## Bug Hunt: Firestore Permission Error on Friendships

### The Symptom
```
[FirebaseFirestore][I-FST000001] Listen for query at friendships/{docId} failed: Missing or insufficient permissions.
```
This appeared consistently after the app backgrounded, even after a fresh install. The friendship collection was confirmed empty via Firebase MCP.

### Failed Approaches

**Attempt 1: `resource == null` in `allow read`**
```javascript
allow read: if isSignedIn()
  && (resource == null
      || resource.data.userId1 == request.auth.uid
      || resource.data.userId2 == request.auth.uid);
```
Did not fix it. Deployed. Error persisted.

**Attempt 2: Split `allow read` into `allow get` + `allow list`**
```javascript
allow get: if isSignedIn()
  && (resource == null || resource.data.userId1 == request.auth.uid || ...);
allow list: if isSignedIn()
  && (resource.data.userId1 == request.auth.uid || ...);
```
Did not fix it. Error persisted.

### Root Cause 1: `getDocument()` + Offline Persistence + Watch API

`sendFriendRequest` called `getDocument()` on a deterministic friendship document path to check if a friendship already existed. With Firestore offline persistence (`PersistentCacheSettings`), **even one-time `getDocument()` calls use the gRPC Watch/Listen API internally**. The Firestore SDK logs this as `"Listen for query at {path}"`.

For Watch streams on non-existent documents, **Firestore evaluates security rules _prospectively_** — it asks "would this user ever be allowed to see this document?", not "what is the current state?". This means `resource == null` **never fires** for Watch streams. The rule evaluation always uses `resource.data.X`, which throws when the document doesn't exist, causing the permission denial.

### Fix for Root Cause 1

Changed `sendFriendRequest` from `getDocument()` to two collection queries:

```swift
// Before — triggers Watch on specific non-existent doc path
let existingDoc = try await db.collection("friendships").document(docId).getDocument()

// After — collection queries use allow-list semantics, no resource==null needed
let snap1 = try await db.collection("friendships")
    .whereField("userId1", isEqualTo: currentUID)
    .whereField("userId2", isEqualTo: targetId)
    .limit(to: 1).getDocuments()
let snap2 = try await db.collection("friendships")
    .whereField("userId1", isEqualTo: targetId)
    .whereField("userId2", isEqualTo: currentUID)
    .limit(to: 1).getDocuments()
let existingDoc = snap1.documents.first ?? snap2.documents.first
```

The `allow list` rule (`resource.data.userId2 == request.auth.uid`) is satisfied by the query constraint (`whereField("userId2", isEqualTo: currentUID)`), so Firestore can prove the rule holds without needing `resource == null`.

Also reverted the friendship `allow get` to the clean original (no `resource == null`):
```javascript
allow get: if isSignedIn()
  && (resource.data.userId1 == request.auth.uid
      || resource.data.userId2 == request.auth.uid);
```

### Root Cause 2: Collection Queries + `areFriends()` in Security Rules

After fixing the friendship issue, friends still showed as 0. The new error:
```
Listen for query at users failed: Missing or insufficient permissions.
Failed to fetch profiles: Missing or insufficient permissions.
```

`fetchProfiles` and `fetchDisplayNames` used batch collection queries:
```swift
db.collection("users").whereField(FieldPath.documentID(), in: chunk).getDocuments()
```

The `users` `allow read` rule uses `areFriends()`, which internally calls `get()` and `exists()` on friendship documents. **Firestore validates collection query rules against query constraints, not per-document.** It checks whether the query's `where` clauses _prove_ the rule will pass for all returned documents. Since `areFriends()` requires cross-document reads, Firestore cannot express it as a constraint proof — it rejects the entire collection query, even when `areFriends()` would actually return `true` for all returned documents.

This is different from `allow get` (individual document reads), where Firestore DOES execute `get()`/`exists()` per document and `areFriends()` works correctly.

### Fix for Root Cause 2

Changed both functions to individual `document(id).getDocument()` calls:

```swift
// Before — collection query, allow-list semantics, areFriends() can't be proved as constraint
for chunk in userIds.chunked(into: 10) {
    let snap = try await db.collection("users")
        .whereField(FieldPath.documentID(), in: chunk)
        .getDocuments()
    ...
}

// After — individual reads, allow-get semantics, areFriends() evaluated per-document
for userId in userIds {
    let doc = try await db.collection("users").document(userId).getDocument()
    ...
}
```

This applies to:
- `fetchProfiles` in `FirebaseSocialService+Friends.swift`
- `fetchDisplayNames` in `FirebaseSocialService+Leaderboard.swift`

---

## Firestore Security Rules: Key Behaviors Learned

| Scenario | Behavior |
|---|---|
| `getDocument()` with offline persistence | Uses Watch/Listen API internally; logs as `"Listen for query at {path}"` |
| Watch/Listen on non-existent doc | Rules evaluated **prospectively**; `resource == null` does NOT fire |
| `allow get` (individual document read) | Rules evaluated per-document; `get()`/`exists()` in `areFriends()` work correctly |
| `allow list` (collection query) | Rules validated against **query constraints**; `get()`/`exists()` in rule cannot be a constraint → query rejected |
| `allow read` | Covers both `get` and `list`; same constraint limitation applies for list operations |

### Practical Rules

1. **Never call `getDocument()` on a path you don't own if the document might not exist.** Use collection queries with constraints you own instead. The Watch API will probe non-existent paths and the `resource == null` escape hatch doesn't work.

2. **Never use `areFriends()` (or any function with `get()`/`exists()`) in rules that gate collection queries.** Use it only in `allow get` rules. For `allow list`, the query constraints must prove the rule without cross-document reads.

3. **The `"Listen for query at X"` log format applies to both document-level Watches and collection query Watches.** When X ends in a document ID, it's a document Watch (from `getDocument()` or `addSnapshotListener()` on a doc). When X is a collection path, it's a collection query Watch.

---

## Final State of `firestore.rules` (Friendships section)

```javascript
match /friendships/{friendshipId} {
  // get: party-based. resource==null intentionally NOT included — sendFriendRequest
  // uses collection queries for existence checks to avoid Watch prospective evaluation.
  allow get: if isSignedIn()
    && (resource.data.userId1 == request.auth.uid
        || resource.data.userId2 == request.auth.uid);

  // list: collection queries — any returned doc is guaranteed to satisfy the rule
  // because the query constrains userId1 or userId2 to the caller's UID.
  allow list: if isSignedIn()
    && (resource.data.userId1 == request.auth.uid
        || resource.data.userId2 == request.auth.uid);
  ...
}
```

---

## Files Changed This Session

| File | Change |
|---|---|
| `StreakSync/App/AppContainer.swift` | Provider upgrade detection, `deriveProvider` helpers |
| `StreakSync/Core/Services/Social/FirebaseAuthStateManager.swift` | Removed direct `authProvider =` assignments |
| `StreakSync/Core/Services/Social/FirebaseSocialService.swift` | Fixed `ensureProfile()` provider derivation |
| `StreakSync/Core/Services/Social/FirebaseSocialService+Friends.swift` | `sendFriendRequest` → collection queries; `fetchProfiles` → individual reads |
| `StreakSync/Core/Services/Social/FirebaseSocialService+Leaderboard.swift` | `fetchDisplayNames` → individual reads |
| `StreakSyncTests/AuthProviderDerivationTests.swift` | New: 9 unit tests for `deriveProvider` |
| `firestore.rules` | Reverted friendship rule; no `resource == null` |
| `firestore-rules-tests/firestore.rules.test.mjs` | Updated test cases to match final rules |

---

## Outstanding / Next Session

- Crashlytics integration still pending (noted in post-launch backlog)
- Firebase budget alert still pending
- End-to-end test of friend flow from both devices needed (send request → accept → leaderboard shows friend's scores with correct display name)
- Account linking UX gap (merge prompt for Apple↔Google switch) still open — see `docs/superpowers/specs/2026-05-15-account-linking-design.md` for the design
