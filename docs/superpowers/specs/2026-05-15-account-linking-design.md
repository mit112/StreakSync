# Account Linking: Anonymous → Social Provider

**Date:** 2026-05-15
**Status:** Approved

---

## Problem

When an anonymous user signs in with Apple or Google for the first time, Firebase's `user.link(with: credential)` preserves the UID. All Firestore data (game results, friendships, friend code, scores) carries over automatically. However, two things are not done after the link:

1. The Firestore user profile still shows `authProvider: "anonymous"` and `displayName: "Player"`.
2. `AppContainer`'s auth observer skips the event entirely (`guard newUID != previousUID else { return }`) because the UID didn't change, so no sync runs.

Additionally, `ensureProfile()` hardcodes `"apple"` as the provider string for any non-anonymous user, silently misidentifying Google users.

A companion bug: `sendFriendRequest` calls `getDocument()` on a friendship path that doesn't exist yet. The Firestore read rule checks `resource.data.userId1/2`, which evaluates to `null` for non-existent documents, causing "Missing or insufficient permissions" on every first friend request.

---

## What Does Not Change

- The `user.link(with: credential)` happy path already works. UID is preserved and no data migration is needed.
- The `credentialAlreadyInUse` path (Apple/Google credential already on a different Firebase account) already switches to the correct existing account. This is correct behavior — social accounts are independent identities. No merging.
- All Firestore data, friendships, friend codes, and pending scores are tied to the UID and carry over automatically.

---

## Architecture

Two Combine subscribers in `AppContainer`, each with one responsibility:

| Subscriber | Signal | Condition | Handler |
|---|---|---|---|
| Existing | `$currentUser` | UID changed | `handleAuthUserChanged(from:to:)` — wipes stale data, full sync |
| New | `$authProvider` | `.anonymous` → social | `handleProviderUpgraded()` — updates Firestore profile, incremental sync |

The new `$authProvider` subscriber tracks `lastKnownProvider` and uses `removeDuplicates()` + `dropFirst()`. It only acts when the provider transitions from `.anonymous` to a social provider. During an account switch (`credentialAlreadyInUse`), both handlers run: `handleAuthUserChanged` does the full sync (correct), and `handleProviderUpgraded` follows with a no-op incremental sync and a harmless profile update. The final state is correct in all cases.

**Why not guard `uid == lastKnownUID`:** `$currentUser` fires before `$authProvider` (sequential assignments in `FirebaseAuthStateManager.setupAuthListener`), so by the time `$authProvider` fires during an account switch, `lastKnownUID` has already been updated to the new UID — making the guard always true and useless. Tracking `lastKnownProvider` is the clean signal.

---

## Data Flow: Anonymous → Apple/Google (Happy Path)

```
User taps "Sign in with Apple"
    → FirebaseAuthStateManager.handleAppleSignIn()
        → user.link(with: credential)      ← UID preserved
        → updateDisplayNameFromApple()     ← sets Firebase Auth displayName
        → authProvider = .apple            ← @Published fires

AppContainer.$authProvider subscriber fires
    → newProvider == .apple, UID unchanged
    → handleProviderUpgraded()
        → socialService.updateProfile(
              displayName: firebaseAuthManager.displayName,  ← Apple name or nil
              authProvider: "apple"
          )                                ← merge: true, safe to call always
        → gameResultSyncService.syncIfNeeded()
        → appState.rebuildStreaksFromResults()
        → achievementSyncService.syncIfEnabled()
```

After this, the Firestore profile reflects the real provider and name. On a future reinstall, signing in with the same Apple account returns the same Firebase UID and the user's data syncs back from Firestore.

---

## Data Flow: credentialAlreadyInUse (Existing Account)

```
User taps "Sign in with Apple" — credential already linked to UID-B
    → FirebaseAuthStateManager catches credentialAlreadyInUse
        → auth.signIn(with: updatedCredential)   ← UID changes: UID-A → UID-B
        → authProvider = .apple

AppContainer.$currentUser subscriber fires first (UID changed)
    → handleAuthUserChanged(from: UID-A, to: UID-B)
        → clears stale UID-A data
        → full sync for UID-B

AppContainer.$authProvider subscriber fires after (on same @MainActor queue)
    → previousProvider == .anonymous, newProvider == .apple → guard passes
    → handleProviderUpgraded() runs after handleAuthUserChanged completes
        → updateProfile(authProvider: "apple") — no-op, profile already correct
        → syncIfNeeded() — no-op, full sync already ran
```

Both handlers run; the result is correct. `handleAuthUserChanged` does the authoritative work. `handleProviderUpgraded` is redundant but harmless on this path.

---

## Component Changes

### `AppContainer.swift`

**`setupAuthStateObserver()`** — add `lastKnownProvider` property and a second subscriber:

```swift
// New property alongside lastKnownUID:
private var lastKnownProvider: AuthProvider = .anonymous

// In setupAuthStateObserver(), initialize alongside lastKnownUID:
lastKnownProvider = firebaseAuthManager.authProvider

// New subscriber:
firebaseAuthManager.$authProvider
    .removeDuplicates()
    .dropFirst()
    .sink { [weak self] newProvider in
        guard let self else { return }
        let previousProvider = self.lastKnownProvider
        self.lastKnownProvider = newProvider
        guard previousProvider == .anonymous, newProvider != .anonymous else { return }
        Task { @MainActor [weak self] in
            await self?.handleProviderUpgraded()
        }
    }
    .store(in: &cancellables)
```

**`handleProviderUpgraded()`** — new private method:

```swift
private func handleProviderUpgraded() async {
    let provider = firebaseAuthManager.authProvider.rawValue
    let displayName = firebaseAuthManager.displayName
    logger.info("Auth: provider upgraded to \(provider) — updating profile")
    try? await socialService.updateProfile(displayName: displayName, authProvider: provider)
    await gameResultSyncService.syncIfNeeded()
    await appState.rebuildStreaksFromResults()
    await achievementSyncService.syncIfEnabled()
    logger.info("Auth: provider upgrade complete")
}
```

### `FirebaseSocialService.swift`

**`ensureProfile()`** — fix hardcoded provider:

```swift
// Before
let provider = authUser?.isAnonymous == true ? "anonymous" : "apple"

// After
let provider: String
if authUser?.isAnonymous == true {
    provider = "anonymous"
} else if authUser?.providerData.contains(where: { $0.providerID == "apple.com" }) == true {
    provider = "apple"
} else if authUser?.providerData.contains(where: { $0.providerID == "google.com" }) == true {
    provider = "google"
} else {
    provider = "anonymous"
}
```

### `firestore.rules`

**Friendship read rule** — allow existence checks on non-existent documents:

```javascript
// Before
allow read: if isSignedIn()
  && (resource.data.userId1 == request.auth.uid
      || resource.data.userId2 == request.auth.uid);

// After
allow read: if isSignedIn()
  && (resource == null
      || resource.data.userId1 == request.auth.uid
      || resource.data.userId2 == request.auth.uid);
```

`resource == null` only allows `exists: false` to be returned — no document content is exposed. Collection queries are unaffected (returned documents always have `resource != null`).

---

## Error Handling

- **Profile update failure**: `try?` — non-fatal. The user is signed in with the correct UID; the Firestore profile being stale for one session is an acceptable degraded state. It will be corrected on the next `ensureProfile()` call.
- **Sync failure**: handled by existing `syncIfNeeded()` error handling (same as cold launch).
- **`$authProvider` double-fire**: `removeDuplicates()` suppresses re-emissions of the same provider value.

---

## Testing

Existing: `StreakSyncTests` covers auth state manager and sync pipeline independently.

New tests to add in `FirebaseAuthStateManagerTests` (or integration test):
1. Provider upgrade subscriber fires `handleProviderUpgraded` when `authProvider` changes from `.anonymous` to `.apple` with same UID.
2. Provider subscriber skips when UID also changes (defers to UID-change handler).
3. `ensureProfile()` stores `"google"` when current user's providerData contains `"google.com"`.

Firestore rules tests (in `firestore-rules-tests/`):
4. Authenticated user can `getDocument()` on a non-existent friendship path (returns `exists: false`).
5. Authenticated user cannot `getDocument()` on an existing friendship path where they are not a party.

---

## Files Changed

| File | Change |
|---|---|
| `StreakSync/App/AppContainer.swift` | Add `$authProvider` subscriber + `handleProviderUpgraded()` |
| `StreakSync/Core/Services/Social/FirebaseSocialService.swift` | Fix provider detection in `ensureProfile()` |
| `firestore.rules` | Add `resource == null` to friendship read rule |
