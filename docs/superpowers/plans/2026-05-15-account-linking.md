# Account Linking: Anonymous → Social Provider — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When an anonymous user signs in with Apple or Google, their Firestore profile updates to reflect the social provider, an incremental sync runs, and first friend requests stop failing with "Missing or insufficient permissions."

**Architecture:** Remove direct `authProvider = .X` assignments from sign-in handlers so the Firebase auth listener is the single source of truth. Add a `lastKnownProvider` tracker to `AppContainer`'s existing `$currentUser` subscriber; detect anonymous→social transitions there and dispatch `handleProviderUpgraded`. Fix the Firestore friendship read rule to allow `getDocument()` on non-existent documents.

**Tech Stack:** Swift 6 / SwiftUI, Firebase Auth + Firestore, Combine, XCTest, Node.js (Firestore rules tests)

---

## File Map

| File | Change |
|---|---|
| `firestore.rules` | Add `resource == null \|\|` to friendship read rule |
| `firestore-rules-tests/firestore.rules.test.mjs` | 2 new test cases for the rule change |
| `StreakSync/Core/Services/Social/FirebaseAuthStateManager.swift` | Remove 5 direct `authProvider = .X` assignments (lines 139, 148, 152, 223, 232) |
| `StreakSync/App/AppContainer.swift` | Add `lastKnownProvider`, `deriveProvider(fromProviderIDs:)`, `handleProviderUpgraded(to:displayName:)`; update `setupAuthStateObserver` |
| `StreakSync/Core/Services/Social/FirebaseSocialService.swift` | Fix provider detection in `ensureProfile()`; remove dead `"friends"` field |
| `StreakSyncTests/AuthProviderDerivationTests.swift` | New — unit tests for `deriveProvider(fromProviderIDs:)` and `ensureProfile` provider logic |

---

## Task 1: Fix Firestore friendship read rule

**Files:**
- Modify: `firestore.rules:176`

This fixes the immediate bug: `sendFriendRequest` calls `getDocument()` on a non-existent friendship path before creating it. Firestore evaluates `resource.data.userId1` which is `null` for non-existent documents, causing "Missing or insufficient permissions".

- [ ] **Step 1: Open `firestore.rules` and locate the friendship read rule (line 176)**

The current rule looks like:
```javascript
match /friendships/{friendshipId} {
  allow read: if isSignedIn()
    && (resource.data.userId1 == request.auth.uid
        || resource.data.userId2 == request.auth.uid);
```

- [ ] **Step 2: Add `resource == null ||` to allow existence checks**

Replace the friendship read rule with:
```javascript
match /friendships/{friendshipId} {
  // resource == null when the document does not exist; allows getDocument()
  // existence checks in sendFriendRequest without exposing document content.
  // Collection queries are unaffected — returned documents always have resource != null.
  allow read: if isSignedIn()
    && (resource == null
        || resource.data.userId1 == request.auth.uid
        || resource.data.userId2 == request.auth.uid);
```

- [ ] **Step 3: Commit the rules change**

```bash
git add firestore.rules
git commit -m "fix(rules): allow getDocument() on non-existent friendship paths

Firestore evaluates resource.data.userId1 as null for non-existent
documents, denying the existence check in sendFriendRequest. Adding
resource == null allows the check while keeping content gated behind
the userId party check for existing documents."
```

---

## Task 2: Add Firestore rules tests for the friendship rule change

**Files:**
- Modify: `firestore-rules-tests/firestore.rules.test.mjs`

Add two cases at the end of the existing test suite (before the final summary `console.log`).

- [ ] **Step 1: Find the end of the test suite in `firestore-rules-tests/firestore.rules.test.mjs`**

Look for the last `runCase(...)` call and the final `console.log` block (around the bottom of the file). Add both new cases between them.

- [ ] **Step 2: Add the two new test cases**

```javascript
// --- Friendship: resource == null fix ---

await runCase(
  "friendship: authenticated user can getDocument() on a non-existent friendship path (existence check)",
  async () => {
    const alice = testEnv.authenticatedContext("alice");
    // "alice_bob" does not exist in Firestore — assertSucceeds means we get exists:false, not a permission error
    await assertSucceeds(
      getDoc(doc(alice.firestore(), "friendships", "alice_bob"))
    );
  }
);

await runCase(
  "friendship: resource==null does not bypass party check on existing doc — third party cannot read",
  async () => {
    // Create an accepted friendship between alice and bob
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "friendships", "alice_bob"), {
        userId1: "alice",
        userId2: "bob",
        status: "accepted",
        createdAt: new Date(),
      });
    });
    // charlie (not a party) must NOT be able to read the doc
    const charlie = testEnv.authenticatedContext("charlie");
    await assertFails(
      getDoc(doc(charlie.firestore(), "friendships", "alice_bob"))
    );
  }
);
```

- [ ] **Step 3: Run the Firestore rules tests to verify both cases pass**

```bash
cd firestore-rules-tests
# Firestore emulator must already be running. If not: firebase emulators:start --only firestore &
node firestore.rules.test.mjs
```

Expected: all previously passing cases still pass, and both new cases show `✅ PASS`.

- [ ] **Step 4: Commit**

```bash
cd ..
git add firestore-rules-tests/firestore.rules.test.mjs
git commit -m "test(rules): add friendship existence-check and third-party read tests"
```

---

## Task 3: Remove direct `authProvider` assignments from sign-in handlers

**Files:**
- Modify: `StreakSync/Core/Services/Social/FirebaseAuthStateManager.swift`

The five direct `authProvider = .apple/.google` assignments in `handleAppleSignIn` and `handleGoogleSignIn` cause `$authProvider` to emit before `$currentUser` on the `credentialAlreadyInUse` path, breaking ordering assumptions. `setupAuthListener` already calls `Self.detectProvider(for: user)` and is the correct single source. Remove only the direct assignments; all other logic stays.

- [ ] **Step 1: Remove `authProvider = .apple` from the happy-path branch of `handleAppleSignIn` (line 139)**

```swift
// Before (lines 129-140):
            let result = try await user.link(with: credential)
            logger.info("Linked anonymous account to Apple: uid=\(result.user.uid, privacy: .private)")
            await updateDisplayNameFromApple(appleCredential.fullName, user: result.user)
        } else {
            let result = try await auth.signIn(with: credential)
            logger.info("Apple Sign-In: uid=\(result.user.uid, privacy: .private)")
            await updateDisplayNameFromApple(appleCredential.fullName, user: result.user)
        }
        authProvider = .apple     // ← DELETE THIS LINE
        currentNonce = nil

// After:
            let result = try await user.link(with: credential)
            logger.info("Linked anonymous account to Apple: uid=\(result.user.uid, privacy: .private)")
            await updateDisplayNameFromApple(appleCredential.fullName, user: result.user)
        } else {
            let result = try await auth.signIn(with: credential)
            logger.info("Apple Sign-In: uid=\(result.user.uid, privacy: .private)")
            await updateDisplayNameFromApple(appleCredential.fullName, user: result.user)
        }
        currentNonce = nil
```

- [ ] **Step 2: Remove `authProvider = .apple` from both lines in the `credentialAlreadyInUse` catch block of `handleAppleSignIn` (lines 148 and 152)**

```swift
// Before (lines 141-156):
        } catch let error as NSError where error.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
            logger.warning("Apple credential already in use — signing in to existing account")
            if let updatedCredential = error.userInfo[AuthErrorUserInfoUpdatedCredentialKey] as? AuthCredential {
                let result = try await auth.signIn(with: updatedCredential)
                logger.info("Signed in to existing Apple account: uid=\(result.user.uid, privacy: .private)")
                authProvider = .apple   // ← DELETE THIS LINE
            } else {
                let result = try await auth.signIn(with: credential)
                authProvider = .apple   // ← DELETE THIS LINE
                logger.info("Fallback Apple sign-in: uid=\(result.user.uid, privacy: .private)")
            }
            currentNonce = nil

// After:
        } catch let error as NSError where error.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
            logger.warning("Apple credential already in use — signing in to existing account")
            if let updatedCredential = error.userInfo[AuthErrorUserInfoUpdatedCredentialKey] as? AuthCredential {
                let result = try await auth.signIn(with: updatedCredential)
                logger.info("Signed in to existing Apple account: uid=\(result.user.uid, privacy: .private)")
            } else {
                let result = try await auth.signIn(with: credential)
                logger.info("Fallback Apple sign-in: uid=\(result.user.uid, privacy: .private)")
            }
            currentNonce = nil
```

- [ ] **Step 3: Remove `authProvider = .google` from the happy-path branch of `handleGoogleSignIn` (line 223)**

```swift
// Before:
            authProvider = .google    // ← DELETE THIS LINE
        } catch let error as GIDSignInError where error.code == .canceled {

// After:
        } catch let error as GIDSignInError where error.code == .canceled {
```

- [ ] **Step 4: Remove `authProvider = .google` from the `credentialAlreadyInUse` catch block of `handleGoogleSignIn` (line 232)**

```swift
// Before:
            if let updatedCredential = error.userInfo[AuthErrorUserInfoUpdatedCredentialKey] as? AuthCredential {
                let authResult = try await auth.signIn(with: updatedCredential)
                authProvider = .google   // ← DELETE THIS LINE
                logger.info("Signed in to existing Google account: uid=\(authResult.user.uid, privacy: .private)")

// After:
            if let updatedCredential = error.userInfo[AuthErrorUserInfoUpdatedCredentialKey] as? AuthCredential {
                let authResult = try await auth.signIn(with: updatedCredential)
                logger.info("Signed in to existing Google account: uid=\(authResult.user.uid, privacy: .private)")
```

- [ ] **Step 5: Build to verify no compilation errors**

```bash
xcodebuild build \
  -project StreakSync.xcodeproj -scheme StreakSync \
  -destination 'platform=iOS Simulator,id=F21EC641-574B-40EB-93FA-F5F464F006A5' \
  -skipPackagePluginValidation CODE_SIGNING_ALLOWED=NO -quiet \
  2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED` with no errors.

- [ ] **Step 6: Commit**

```bash
git add StreakSync/Core/Services/Social/FirebaseAuthStateManager.swift
git commit -m "fix(auth): remove direct authProvider assignments from sign-in handlers

Let setupAuthListener's detectProvider(for:) be the single source of
truth for authProvider. Direct assignments caused $authProvider to fire
before $currentUser on the credentialAlreadyInUse path, breaking the
ordering the AppContainer observer depends on."
```

---

## Task 4: Write unit tests for provider derivation logic

**Files:**
- Create: `StreakSyncTests/AuthProviderDerivationTests.swift`

These tests cover the `deriveProvider(fromProviderIDs:)` helper that will be added to `AppContainer` in Task 5. Writing tests first means we can verify the function signature is correct before adding it.

- [ ] **Step 1: Create `StreakSyncTests/AuthProviderDerivationTests.swift`**

```swift
//
//  AuthProviderDerivationTests.swift
//  StreakSyncTests
//
//  Tests for AppContainer.deriveProvider(fromProviderIDs:) and
//  the ensureProfile() provider detection in FirebaseSocialService.
//

@testable import StreakSync
import XCTest

final class AuthProviderDerivationTests: XCTestCase {
    // MARK: - AppContainer.deriveProvider(fromProviderIDs:)

    func testDeriveProvider_emptyIDs_returnsAnonymous() {
        XCTAssertEqual(AppContainer.deriveProvider(fromProviderIDs: []), .anonymous)
    }

    func testDeriveProvider_appleID_returnsApple() {
        XCTAssertEqual(AppContainer.deriveProvider(fromProviderIDs: ["apple.com"]), .apple)
    }

    func testDeriveProvider_googleID_returnsGoogle() {
        XCTAssertEqual(AppContainer.deriveProvider(fromProviderIDs: ["google.com"]), .google)
    }

    func testDeriveProvider_appleBeatsGoogle_whenBoth() {
        // apple.com takes priority (matches first in the if-chain)
        XCTAssertEqual(AppContainer.deriveProvider(fromProviderIDs: ["apple.com", "google.com"]), .apple)
    }

    func testDeriveProvider_unknownID_returnsAnonymous() {
        XCTAssertEqual(AppContainer.deriveProvider(fromProviderIDs: ["password"]), .anonymous)
    }
}
```

- [ ] **Step 2: Run the tests — they must FAIL because `deriveProvider(fromProviderIDs:)` doesn't exist yet**

```bash
xcodebuild test \
  -project StreakSync.xcodeproj -scheme StreakSync \
  -destination 'platform=iOS Simulator,id=F21EC641-574B-40EB-93FA-F5F464F006A5' \
  -skipPackagePluginValidation CODE_SIGNING_ALLOWED=NO \
  -only-testing:StreakSyncTests/AuthProviderDerivationTests \
  2>&1 | grep -E "error:|FAILED|PASSED|BUILD"
```

Expected: compile error — `AppContainer.deriveProvider(fromProviderIDs:)` not found.

---

## Task 5: Update `AppContainer` — provider tracking and upgrade handler

**Files:**
- Modify: `StreakSync/App/AppContainer.swift`

Add `lastKnownProvider`, a testable `deriveProvider(fromProviderIDs:)` helper, a `handleProviderUpgraded(to:displayName:)` method, and update `setupAuthStateObserver` to detect anonymous→social transitions.

- [ ] **Step 1: Add `lastKnownProvider` property alongside `lastKnownUID` (around line 51)**

```swift
    // MARK: - Auth State Observation
    private var lastKnownUID: String?
    private var lastKnownProvider: AuthProvider = .anonymous   // ← ADD THIS LINE
    private var cancellables = Set<AnyCancellable>()
```

- [ ] **Step 2: Add `deriveProvider` static helpers after the existing `cleanupForSignOut` method**

Add these two methods. The `fromProviderIDs:` overload is `internal` so it can be tested from `StreakSyncTests`.

```swift
    // MARK: - Provider Derivation

    /// Derives the auth provider from a Firebase User's providerData.
    /// Called in the $currentUser subscriber so we don't depend on when
    /// authProvider is set on FirebaseAuthStateManager (it's the next line).
    private static func deriveProvider(from user: User?) -> AuthProvider {
        guard let user, !user.isAnonymous else { return .anonymous }
        return deriveProvider(fromProviderIDs: user.providerData.map { $0.providerID })
    }

    /// Pure derivation from provider ID strings — internal for testability.
    internal static func deriveProvider(fromProviderIDs ids: [String]) -> AuthProvider {
        if ids.contains("apple.com") { return .apple }
        if ids.contains("google.com") { return .google }
        return .anonymous
    }
```

- [ ] **Step 3: Add `handleProviderUpgraded(to:displayName:)` after `handleAuthUserChanged`**

```swift
    /// Called when the same Firebase UID transitions from anonymous to a social provider.
    /// Parameters are captured at subscriber time so values are deterministic even if
    /// auth state changes again before the Task executes.
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

- [ ] **Step 4: Update `setupAuthStateObserver` to initialise `lastKnownProvider` and detect provider upgrades**

Replace the entire `setupAuthStateObserver` method:

```swift
    private func setupAuthStateObserver() {
        lastKnownUID = firebaseAuthManager.uid
        lastKnownProvider = firebaseAuthManager.authProvider

        firebaseAuthManager.$currentUser
            .dropFirst()
            .sink { [weak self] newUser in
                guard let self else { return }

                let newUID = newUser?.uid
                let newProvider = AppContainer.deriveProvider(from: newUser)
                let previousUID = self.lastKnownUID
                let previousProvider = self.lastKnownProvider
                self.lastKnownUID = newUID
                self.lastKnownProvider = newProvider

                if newUID != previousUID {
                    // Account switch: UID changed — wipe stale data and full sync.
                    logger.info("Auth: UID changed (\(previousUID ?? "nil") → \(newUID ?? "nil")) — clearing stale data and re-syncing")
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        await self.handleAuthUserChanged(from: previousUID, to: newUID)
                    }
                } else if previousProvider == .anonymous, newProvider != .anonymous {
                    // Provider upgrade: same UID, anonymous → social.
                    // Capture values now; auth state may change before the Task runs.
                    let provider = newProvider
                    let name = newUser?.displayName
                    logger.info("Auth: provider upgraded for UID \(newUID ?? "nil")")
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        await self.handleProviderUpgraded(to: provider, displayName: name)
                    }
                }
                // else: no-op (display name update, re-auth to same anonymous UID, etc.)
            }
            .store(in: &cancellables)
    }
```

Note: The `logger.info("Auth: UID changed…")` line that previously lived inside `handleAuthUserChanged` is now logged in the subscriber (before the Task), so it appears immediately. Remove the duplicate log from inside `handleAuthUserChanged` if it exists.

- [ ] **Step 5: Build to verify no compilation errors**

```bash
xcodebuild build \
  -project StreakSync.xcodeproj -scheme StreakSync \
  -destination 'platform=iOS Simulator,id=F21EC641-574B-40EB-93FA-F5F464F006A5' \
  -skipPackagePluginValidation CODE_SIGNING_ALLOWED=NO -quiet \
  2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 6: Run the unit tests from Task 4 — they must now PASS**

```bash
xcodebuild test \
  -project StreakSync.xcodeproj -scheme StreakSync \
  -destination 'platform=iOS Simulator,id=F21EC641-574B-40EB-93FA-F5F464F006A5' \
  -skipPackagePluginValidation CODE_SIGNING_ALLOWED=NO \
  -only-testing:StreakSyncTests/AuthProviderDerivationTests \
  2>&1 | grep -E "Test.*passed|Test.*failed|BUILD"
```

Expected: all 5 tests pass.

- [ ] **Step 7: Commit**

```bash
git add StreakSync/App/AppContainer.swift StreakSyncTests/AuthProviderDerivationTests.swift
git commit -m "feat(auth): detect anonymous→social provider upgrade in AppContainer

Add lastKnownProvider tracking to the \$currentUser subscriber.
When the UID stays the same but provider changes from .anonymous to
.apple/.google, dispatch handleProviderUpgraded which updates the
Firestore profile and runs an incremental sync. Single subscriber,
single Task per auth event — no interleaving with handleAuthUserChanged."
```

---

## Task 6: Fix `ensureProfile()` in `FirebaseSocialService`

**Files:**
- Modify: `StreakSync/Core/Services/Social/FirebaseSocialService.swift:168-175`

Two fixes in one place: correct provider detection (was hardcoded `"apple"` for all non-anonymous users) and remove the dead `"friends": [String]()` field (architecture moved to a separate `friendships` collection).

- [ ] **Step 1: Replace the provider detection and `setData` call in `ensureProfile()` (lines 168-175)**

```swift
// Before:
            let provider = authUser?.isAnonymous == true ? "anonymous" : "apple"
            try await doc.setData([
                "displayName": resolvedName,
                "authProvider": provider,
                "friends": [String](),
                "createdAt": Timestamp(date: now),
                "updatedAt": Timestamp(date: now)
            ], merge: true)
            return UserProfile(id: currentUID, displayName: resolvedName, authProvider: provider, createdAt: now, updatedAt: now)

// After:
            let providerIDs = authUser?.providerData.map { $0.providerID } ?? []
            let provider = AppContainer.deriveProvider(fromProviderIDs: providerIDs).rawValue
            try await doc.setData([
                "displayName": resolvedName,
                "authProvider": provider,
                "createdAt": Timestamp(date: now),
                "updatedAt": Timestamp(date: now)
            ], merge: true)
            return UserProfile(id: currentUID, displayName: resolvedName, authProvider: provider, createdAt: now, updatedAt: now)
```

Note: `AppContainer.deriveProvider(fromProviderIDs:)` is `internal`, accessible from `FirebaseSocialService` since both are in the `StreakSync` module. This eliminates the duplicated provider-detection logic.

- [ ] **Step 2: Build to verify**

```bash
xcodebuild build \
  -project StreakSync.xcodeproj -scheme StreakSync \
  -destination 'platform=iOS Simulator,id=F21EC641-574B-40EB-93FA-F5F464F006A5' \
  -skipPackagePluginValidation CODE_SIGNING_ALLOWED=NO -quiet \
  2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Add a test to `AuthProviderDerivationTests.swift` verifying the provider string values**

Append to `AuthProviderDerivationTests`:

```swift
    // MARK: - AuthProvider raw values used in Firestore

    func testAuthProviderRawValues() {
        // These string values are stored in Firestore — must not change.
        XCTAssertEqual(AuthProvider.anonymous.rawValue, "anonymous")
        XCTAssertEqual(AuthProvider.apple.rawValue, "apple")
        XCTAssertEqual(AuthProvider.google.rawValue, "google")
    }

    func testDeriveProvider_rawValue_forApple() {
        let provider = AppContainer.deriveProvider(fromProviderIDs: ["apple.com"])
        XCTAssertEqual(provider.rawValue, "apple")
    }

    func testDeriveProvider_rawValue_forGoogle() {
        let provider = AppContainer.deriveProvider(fromProviderIDs: ["google.com"])
        XCTAssertEqual(provider.rawValue, "google")
    }

    func testDeriveProvider_rawValue_forAnonymous() {
        let provider = AppContainer.deriveProvider(fromProviderIDs: [])
        XCTAssertEqual(provider.rawValue, "anonymous")
    }
```

- [ ] **Step 4: Run the full unit test suite**

```bash
xcodebuild test \
  -project StreakSync.xcodeproj -scheme StreakSync \
  -destination 'platform=iOS Simulator,id=F21EC641-574B-40EB-93FA-F5F464F006A5' \
  -skipPackagePluginValidation CODE_SIGNING_ALLOWED=NO \
  -only-testing:StreakSyncTests/AuthProviderDerivationTests \
  2>&1 | grep -E "Test.*passed|Test.*failed|BUILD"
```

Expected: all 9 tests pass.

- [ ] **Step 5: Run the full test suite to check for regressions**

```bash
xcodebuild test \
  -project StreakSync.xcodeproj -scheme StreakSync \
  -destination 'platform=iOS Simulator,id=F21EC641-574B-40EB-93FA-F5F464F006A5' \
  -skipPackagePluginValidation CODE_SIGNING_ALLOWED=NO \
  2>&1 | grep -E "Test.*passed|Test.*failed|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `BUILD SUCCEEDED`, all existing tests pass.

- [ ] **Step 6: Commit**

```bash
git add StreakSync/Core/Services/Social/FirebaseSocialService.swift \
        StreakSyncTests/AuthProviderDerivationTests.swift
git commit -m "fix(social): correct provider detection in ensureProfile()

Use AppContainer.deriveProvider(fromProviderIDs:) instead of the
hardcoded 'apple' string so Google users are stored correctly.
Also remove the dead 'friends: []' field — friendship state lives
in the friendships collection, not the user profile."
```

---

## Self-Review

**Spec coverage:**
- ✅ Firestore rules `resource == null` fix → Task 1
- ✅ Rules negative test (third party cannot read existing doc) → Task 2
- ✅ Rules positive test (existence check on non-existent doc) → Task 2
- ✅ Remove direct `authProvider = .X` assignments (5 lines) → Task 3
- ✅ `lastKnownProvider` property → Task 5
- ✅ `deriveProvider(from: User?)` private helper → Task 5
- ✅ `deriveProvider(fromProviderIDs:)` internal testable helper → Task 5
- ✅ `handleProviderUpgraded(to:displayName:)` → Task 5
- ✅ Updated `setupAuthStateObserver` → Task 5
- ✅ `ensureProfile()` provider detection fix → Task 6
- ✅ `"friends"` field removal → Task 6
- ✅ Unit tests for `deriveProvider` → Tasks 4 & 6
- ✅ `AuthProvider` raw value stability tests → Task 6
- ✅ Sign-out → re-auth no-op: covered by the `previousProvider == .anonymous && newProvider != .anonymous` guard — re-auth to anonymous has `newProvider == .anonymous` so guard fails

**Placeholder scan:** No TBDs. All code blocks complete with actual implementation.

**Type consistency:**
- `AuthProvider` enum: used as `.anonymous`, `.apple`, `.google` consistently across all tasks.
- `deriveProvider(fromProviderIDs:)` signature `([String]) -> AuthProvider` matches usage in `ensureProfile()` (Task 6) and tests (Task 4).
- `handleProviderUpgraded(to:displayName:)` signature `(AuthProvider, String?)` matches the call site in `setupAuthStateObserver` (Task 5).
- `AppContainer.deriveProvider` accessed as `AppContainer.deriveProvider(fromProviderIDs:)` in both `FirebaseSocialService` (Task 6) and tests (Task 4) — consistent.
