# StreakSync Firebase Security Audit

**Date:** February 26, 2026
**Auditor:** Claude (automated)
**Project:** streaksync-55ca0
**Scope:** Firestore rules, auth service, client-side data handling

---

## Executive Summary

Audited 5 Firestore collections, 2 subcollections, auth service, and 3 sync services. Found **1 CRITICAL**, **5 HIGH**, **5 MEDIUM**, and **3 LOW** issues. Fixed all Critical and 4 of 5 High issues. Only H5 (App Check) remains — requires Xcode GUI setup. Full penetration test suite: 55 test cases.

---

## Findings

### 🔴 CRITICAL

| # | Issue | Status |
|---|-------|--------|
| C1 | **Friend code hijacking** — `friendCodes` used `allow write` permitting any user to overwrite/delete any code. Attacker could impersonate victims by hijacking their friend code. | **FIXED** — split into create/update/delete with ownership checks |

### 🟡 HIGH

| # | Issue | Status |
|---|-------|--------|
| H1 | **No account deletion** — No `deleteAccount()` existed. Apple requires this for App Store. Auth deletion orphans all Firestore data. | **FIXED** — `deleteAllUserData()` on FirebaseSocialService deletes all 6 Firestore collections, `deleteAccount()` on auth manager deletes Firebase Auth account, AccountView has full UI flow |
| H2 | **Account switching data leakage** — Sign-out didn't clear local AppState. If user B signs in after user A, A's game results could sync to B's anonymous→linked account. | **FIXED** — `handleSignOut()` now calls `clearAllData()` + `clearLastSyncTimestamp()` before creating new anonymous session |
| H3 | **No string size limits in rules** — displayName, gameName, senderDisplayName had no `size()` constraints. 500KB strings possible. | **FIXED** — added `isShortString()` (1-200 chars) on all string fields |
| H4 | **User profile update had zero validation** — No field restrictions, no type checks. Arbitrary fields injectable. | **FIXED** — added `hasRequiredAndOnly()` + type checks on create/update |
| H5 | **App Check disabled** — Any extracted `GoogleService-Info.plist` enables direct SDK attacks. | **TODO** — needs Xcode setup |

### 🟠 MEDIUM

| # | Issue | Status |
|---|-------|--------|
| M1 | **Friendship spam** — No rate limiting in rules. Attacker can flood any user with pending requests. | **ACCEPTED** — mitigated by App Check (H5) when enabled |
| M2 | **No `allowedReaders` array size limit** — Score docs could hold thousands of entries. | **FIXED** — capped at 500 |
| M3 | **No emulator configuration** — `firebase.json` had no emulators section. | **FIXED** — added emulator config |
| M4 | **Score deletion permanently denied** — Users can never remove published scores. GDPR concern. | **FIXED** — owner can now delete own scores |
| M5 | **Friendship senderDisplayName no size limit** — Could be oversized. | **FIXED** — `isShortString()` validation added |

### 🟢 LOW / ACCEPTED

| # | Issue | Status |
|---|-------|--------|
| L1 | Friend code enumeration — any authed user can read all codes. Reveals userId + displayName only. | ACCEPTED |
| L2 | Score update can change allowedReaders — owner controls visibility. | ACCEPTED (intentional) |
| L3 | Nonce UUID fallback — SecRandomCopyBytes failure astronomically unlikely. | ACCEPTED |

---

## Rules Changes Summary

1. **`friendCodes`**: `allow write` → separate `allow create` / `allow update` / `allow delete`, each checking `resource.data.userId == request.auth.uid` for existing docs
2. **`users`**: Added `hasRequiredAndOnly()` on create and update with field whitelist, `isShortString(displayName)`, `friends.size() <= 500`. Changed `allow delete: if false` → owner can delete.
3. **`scores`**: Added `isShortString()` on userId/gameId/gameName, `allowedReaders.size() <= 500`. Changed `allow delete: if false` → owner can delete own scores.
4. **`friendships`**: Added `isShortString()` validation on optional `senderDisplayName`
5. **Global**: Added `isShortString()` helper function

---

## Test Suite Coverage (55 tests)

| Category | Tests | What's Covered |
|----------|-------|----------------|
| Unauthenticated access | 6 | All collections + subcollections deny unauthed |
| User profiles | 12 | Owner CRUD, friend read, non-friend deny, field validation, oversized fields, disallowed fields |
| Game results | 4 | Owner read/write/delete, cross-user deny |
| Sync data | 2 | Owner access, cross-user deny |
| Friend codes | 8 | Create, update, delete, hijack prevention (C1), ownership spoofing, oversized fields, extra fields |
| Scores | 12 | allowedReaders gating, ownership spoofing, field types, missing fields, extra fields, size limits, owner delete |
| Friendships | 13 | Create/accept/delete by correct party, immutability, status transitions, self-friendship, oversized fields |
| Subcollection boundaries | 3 | Nonexistent subcollections and root collections denied |
| Enumeration | 2 | friendCodes enumerable (accepted), scores not enumerable |
| Cross-user isolation | 4 | gameResults, sync, profile write isolation |

---

## How to Run Tests

```bash
# Terminal 1: Start emulator
cd /path/to/StreakSync
firebase emulators:start --only firestore

# Terminal 2: Run tests
cd firestore-rules-tests
node firestore.rules.test.mjs
```

---

## Remaining TODO

### H5: App Check

1. Add `FirebaseAppCheck` SPM dependency in Xcode
2. Register App Attest provider in `AppDelegate`
3. Set `AppCheck.isTokenAutoRefreshEnabled = true`
4. Enable enforcement in Firebase Console when ready

---

## Firebase Console Checklist

- [ ] **Authentication → Settings:** Email enumeration protection enabled
- [ ] **Authentication → Sign-in method:** Only Apple, Google, Anonymous enabled
- [ ] **Authentication → Sign-in method:** Verify no Email/Password provider
- [ ] **Firestore → Rules:** Deploy fixed rules (`firebase deploy --only firestore:rules`)
- [ ] **Firestore → Data → users:** Confirm no email/phone PII in user docs
- [ ] **App Check:** Plan to enable (H5)
- [ ] **Realtime Database:** Verify not enabled (Firestore only)
- [ ] **Storage:** Verify rules if Storage is used
- [ ] **Project Settings → General:** Disable unused APIs
