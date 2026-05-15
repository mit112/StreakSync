# Account Linking: Anonymous → Social Provider

**Date:** 2026-05-15
**Status:** Approved (revised after Opus review)

---

## Problem

When an anonymous user links their Apple/Google account (same UID preserved via `user.link(with:)`), two things are not done:

1. The Firestore user profile still shows `authProvider: "anonymous"` and `displayName: "Player"`.
2. `AppContainer.setupAuthStateObserver()` short-circuits on same-UID auth changes (`guard newUID != previousUID else { return }`), so no sync runs and no profile update fires.

Additionally, `ensureProfile()` hardcodes `"apple"` as the provider string for all non-anonymous users, silently misidentifying Google users.

A companion bug (same session): `sendFriendRequest` calls `getDocument()` on a friendship path that doesn't exist yet. The Firestore rule checks `resource.data.userId1/2`, which is `null` for non-existent documents → "Missing or insufficient permissions" on every first friend request.

---

## What Does Not Change

- `user.link(with: credential)` already preserves the UID — all Firestore data (game results, friendships, friend code, pending scores) carries over untouched.
- `credentialAlreadyInUse` path (credential already linked to a different Firebase account) already switches to the correct existing account. Social accounts are independent identities; no merging.
- On future reinstall: signing in with the same social account returns the same Firebase UID; Firestore syncs their data back automatically.

---

## Architecture

A single change to `AppContainer.setupAuthStateObserver()` replaces the existing one-signal observer with a **single `$currentUser` subscriber** that tracks both UID changes and provider transitions.

**Why not two subscribers (`$currentUser` + `$authProvider`):** The sign-in handlers (`handleAppleSignIn`, `handleGoogleSignIn`) set `authProvider = .apple/.google` *directly* before the Firebase auth state listener fires. On the `credentialAlreadyInUse` path this makes `$authProvider` fire while `currentUser` still holds the old UID — the opposite of the intended ordering. Two independent subscribers also spawn independent `Task { @MainActor }` blocks with no sequencing guarantee, allowing `handleProviderUpgraded` to race with `cleanupForSignOut`.

**The fix:** Remove the direct `authProvider = .X` assignments from `handleAppleSignIn`/`handleGoogleSignIn` (and their `credentialAlreadyInUse` catch blocks). Let `setupAuthListener`'s `detectProvider(for:)` be the single source of truth, guaranteeing `currentUser` and `authProvider` update in one deterministic tick.

With that in place, the `$currentUser` subscriber receives an updated `User` object whose `.providerData` already reflects the new provider. We derive the provider from `providerData` directly in the sink — no dependency on when `authProvider` is set on the manager. A single Task is dispatched per event; `handleAuthUserChanged` and `handleProviderUpgraded` never run concurrently.

---

## Data Flow: Provider Upgrade (Happy Path)

```
User taps "Sign in with Apple"
  → FirebaseAuthStateManager.handleAppleSignIn()
      → user.link(with: credential)        ← UID preserved
      → updateDisplayNameFromApple()       ← sets Firebase Auth displayName
      → (authProvider assignment removed)
      → Firebase auth listener fires
          → self.currentUser = linkedUser  ← $currentUser emits
          → self.authProvider = .apple     ← (fires $authProvider but not subscribed)

AppContainer.$currentUser sink runs
  → newUID == previousUID, newProvider == .apple, previousProvider == .anonymous
  → dispatches handleProviderUpgraded(provider: .apple, displayName: "John")
      → socialService.updateProfile(displayName: "John", authProvider: "apple")
      → gameResultSyncService.syncIfNeeded()
      → appState.rebuildStreaksFromResults()
      → achievementSyncService.syncIfEnabled()
```

---

## Data Flow: Account Switch (credentialAlreadyInUse)

```
User taps "Sign in with Apple" — credential linked to UID-B
  → FirebaseAuthStateManager catches credentialAlreadyInUse
      → auth.signIn(with: updatedCredential)   ← UID changes: UID-A → UID-B
      → (authProvider assignment removed)
      → Firebase auth listener fires
          → self.currentUser = uid_B_user      ← $currentUser emits
          → self.authProvider = .apple

AppContainer.$currentUser sink runs
  → newUID (UID-B) != previousUID (UID-A)
  → dispatches handleAuthUserChanged(from: UID-A, to: UID-B)
      → clears stale UID-A data
      → full sync for UID-B
  → (handleProviderUpgraded is NOT dispatched — UID-change branch returns early)
```

Exactly one Task per event. No interleaving.

---

## Component Changes

### `FirebaseAuthStateManager.swift`

Remove the direct `authProvider = .apple/.google` assignments at the end of `handleAppleSignIn` and `handleGoogleSignIn` (including their `credentialAlreadyInUse` catch blocks). `setupAuthListener` already calls `Self.detectProvider(for: user)` and assigns `authProvider` — that remains the single source.

Before removal, these lines appear in:
- `handleAppleSignIn`: line 139 (`authProvider = .apple`), line 148 (`authProvider = .apple`), line 152 (`authProvider = .apple`)
- `handleGoogleSignIn`: line 223 (`authProvider = .google`), line 232 (`authProvider = .google`)

The `currentNonce = nil` cleanup lines remain. Only the `authProvider = .X` assignments are removed.

### `AppContainer.swift`

**Add `lastKnownProvider` property** alongside `lastKnownUID`:
```swift
private var lastKnownUID: String?
private var lastKnownProvider: AuthProvider = .anonymous  // NEW
```

**Replace `setupAuthStateObserver()`** with a single `$currentUser` subscriber:

```swift
private func setupAuthStateObserver() {
    lastKnownUID = firebaseAuthManager.uid
    lastKnownProvider = firebaseAuthManager.authProvider  // NEW

    firebaseAuthManager.$currentUser
        .dropFirst()
        .sink { [weak self] newUser in
            guard let self else { return }

            let newUID = newUser?.uid
            let newProvider = Self.deriveProvider(from: newUser)  // NEW — from providerData
            let previousUID = self.lastKnownUID
            let previousProvider = self.lastKnownProvider
            self.lastKnownUID = newUID
            self.lastKnownProvider = newProvider  // NEW

            if newUID != previousUID {
                // Account switch: UID changed — wipe and full sync
                Task { @MainActor [weak self] in
                    await self?.handleAuthUserChanged(from: previousUID, to: newUID)
                }
            } else if previousProvider == .anonymous, newProvider != .anonymous {
                // Provider upgrade: same UID, anonymous → social
                let displayName = newUser?.displayName
                Task { @MainActor [weak self] in
                    await self?.handleProviderUpgraded(to: newProvider, displayName: displayName)
                }
            }
            // else: no-op (display name update, re-auth to same anonymous UID, etc.)
        }
        .store(in: &cancellables)
}
```

**Add `deriveProvider(from:)` static helper** (avoids duplicating `detectProvider` logic; `FirebaseAuthStateManager.detectProvider` is `private static` so we mirror it here):

```swift
private static func deriveProvider(from user: User?) -> AuthProvider {
    guard let user, !user.isAnonymous else { return .anonymous }
    if user.providerData.contains(where: { $0.providerID == "apple.com" }) { return .apple }
    if user.providerData.contains(where: { $0.providerID == "google.com" }) { return .google }
    return .anonymous
}
```

**Add `handleProviderUpgraded(to:displayName:)`** — new private method. Parameters captured at subscriber time for determinism:

```swift
private func handleProviderUpgraded(to provider: AuthProvider, displayName: String?) async {
    logger.info("Auth: provider upgraded to \(provider.rawValue) — updating profile")
    try? await socialService.updateProfile(
        displayName: displayName,
        authProvider: provider.rawValue
    )
    await gameResultSyncService.syncIfNeeded()
    await appState.rebuildStreaksFromResults()
    await achievementSyncService.syncIfEnabled()
    logger.info("Auth: provider upgrade complete")
}
```

### `FirebaseSocialService.swift`

**`ensureProfile()` — fix provider detection and remove dead `friends` field:**

```swift
// Before
let provider = authUser?.isAnonymous == true ? "anonymous" : "apple"
try await doc.setData([
    "displayName": resolvedName,
    "authProvider": provider,
    "friends": [String](),       // ← dead field, architecture replaced by friendships collection
    "createdAt": Timestamp(date: now),
    "updatedAt": Timestamp(date: now)
], merge: true)

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
try await doc.setData([
    "displayName": resolvedName,
    "authProvider": provider,
    "createdAt": Timestamp(date: now),
    "updatedAt": Timestamp(date: now)
], merge: true)
```

### `firestore.rules`

**Friendship read rule — allow existence checks on non-existent documents:**

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

- **Profile update failure**: `try?` — non-fatal. Correct UID is active; stale profile is acceptable degraded state, corrected on next `ensureProfile()` call.
- **Sync failure**: handled by existing `syncIfNeeded()` error handling (same as cold launch path).
- **Sign-out → re-auth cycle**: `FirebaseAuthStateManager.setupAuthListener` re-auths anonymously on sign-out. `deriveProvider(from: newAnonymousUser)` → `.anonymous`. `previousProvider` was `.anonymous` (set when signed out). Provider check `previousProvider == .anonymous && newProvider != .anonymous` is false → no-op. Correct.

---

## Testing

### Existing coverage
`StreakSyncTests` covers auth state manager and sync pipeline independently.

### New tests

**`AppContainerAuthObserverTests`** (or equivalent):
1. Provider upgrade: `$currentUser` emits with Apple-linked user (same UID, `.isAnonymous == false`) → `handleProviderUpgraded` called, `handleAuthUserChanged` not called.
2. Account switch: `$currentUser` emits with different UID → `handleAuthUserChanged` called, `handleProviderUpgraded` not called.
3. Cold launch into existing Apple account: subscriber emits `.apple` as both previous and new provider → no handler called.
4. Sign-out → anonymous re-auth: `.apple → .anonymous` → no handler called (guard `newProvider != .anonymous` fails).

**`FirebaseSocialServiceTests`**:
5. `ensureProfile()` stores `"google"` when `providerData` contains `"google.com"`.
6. `ensureProfile()` does not write `"friends"` field to Firestore.

**Firestore rules tests** (`firestore-rules-tests/`):
7. Authenticated user can `getDocument()` on a non-existent friendship path → `exists: false`, no error.
8. `resource == null` change does not bypass party check on existing docs: authenticated user who is not userId1 or userId2 cannot read an existing friendship document.

---

## Files Changed

| File | Change |
|---|---|
| `StreakSync/Core/Services/Social/FirebaseAuthStateManager.swift` | Remove 5 direct `authProvider = .X` assignments |
| `StreakSync/App/AppContainer.swift` | Add `lastKnownProvider`, `deriveProvider(from:)`, `handleProviderUpgraded(to:displayName:)`; replace observer |
| `StreakSync/Core/Services/Social/FirebaseSocialService.swift` | Fix provider detection in `ensureProfile()`; remove dead `friends` field |
| `firestore.rules` | Add `resource == null` to friendship read rule |
