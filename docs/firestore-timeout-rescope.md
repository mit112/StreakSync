# Re-scope: ROADMAP "No Firestore request timeout"

ROADMAP.md:138 — `| No Firestore request timeout | App/AppDelegate.swift:38 | ... |`

---

## 1. Verdict

**The real problem is Y, not this.**

**Y = awaited Firestore *writes* never return while the client is offline, and five of them sit
behind a `defer { isLoading = false }` spinner on interactive UI.** The read path — the thing the
ROADMAP entry was pointing at — already has a hard ~10-second ceiling built into the Firestore SDK
and needs nothing.

Two facts settle it, both read out of the SDK source on disk:

1. **Reads are already time-boxed by the SDK.** `getDocuments(source:.default)` opens a one-shot
   Watch listener with `wait_for_sync_when_online = true`
   (`Firestore/core/src/api/query_core.cc:126-130`). `OnlineStateTracker` flips the client to
   `Offline` after `kOnlineStateTimeout = chr::seconds(10)`
   (`remote/online_state_tracker.cc:50`, fired at `:64-73`) or after
   `kMaxWatchStreamFailures = 1` failed watch-stream attempt (`:45`, `:94-101`); that transition
   makes `QueryListener::ShouldRaiseInitialEvent` return true and releases the cached snapshot
   (`core/query_listener.cc:146` `maybe_online`, `:150` the wait gate, `:159`
   `|| online_state == OnlineState::Offline`). An app-level read timeout would be a second, worse
   copy of a timer that already exists.

2. **Writes never resolve offline — by documented design.** From the SDK's own header,
   `FIRDocumentReference.h:126-128`: *"A block to execute once the document has been successfully
   written to the server. This block will not be called while the client is offline."* Same for
   `FIRWriteBatch.h:128-131`. Every `try await setData(...)` / `try await batch.commit()` /
   `try await ....delete()` in this repo therefore suspends **forever** offline. Not slowly — never.

`FirestoreSettings` confirmed to expose only `host`, `sslEnabled`, `dispatchQueue`,
`persistenceEnabled` (deprecated), `cacheSizeBytes` (deprecated), `cacheSettings`
(`Firestore/Source/Public/FirebaseFirestore/FIRFirestoreSettings.h`). No timeout knob. The ROADMAP's
own correction is right; what it did not know is that the *write* half — which it dismissed as
"meaningless" — is where the actual user-visible defect is.

Today `AppDelegate.swift:44-46` sets exactly one thing: a 100 MB `PersistentCacheSettings`. That is
the correct and complete configuration. Leave it alone.

---

## 2. Evidence — call-site map

`OC` below = "offline cache serves it". SDK-behaviour claims are sourced in §1.

### 2a. Queries (`getDocuments`) — safe, bounded, cache-served

| Call site | Op | OC | Slow network today |
|---|---|---|---|
| `Sync/FirestoreGameResultSyncService.swift:193` | `query.getDocuments(source:.default)` | yes | ≤10 s, then cached results; merge proceeds normally |
| `Social/FirebaseSocialService+Friends.swift:33,37` (`listFriends`) | getDocuments | yes | cached friends list |
| `…+Friends.swift:94,99` (dup-friendship check) | getDocuments | yes | cached |
| `…+Friends.swift:154,248,312,316` | getDocuments | yes | cached |
| `…+Friends.swift:392,406,409,435,448` (`deleteAllUserData`) | getDocuments | yes | cached |
| `…+Leaderboard.swift:32-37` (`fetchLeaderboard`) | getDocuments | yes | cached leaderboard |
| `…+Scores.swift:224` | getDocuments | yes | cached |

A query **never errors** when offline — `ShouldRaiseInitialEvent` returns
`… || online_state == OnlineState::Offline`, so it raises a (possibly empty) cached snapshot.

### 2b. Single-doc reads (`getDocument`, default source) — bounded, but **error if the doc isn't cached**

`document_reference.cc:147` (`if (!snapshot.exists() && snapshot.metadata().from_cache())`) → `:158`:
when offline and the doc is absent from cache, the SDK returns `kErrorUnavailable` —
*"Failed to get document because the client is offline."* — rather than a non-existent snapshot.
Asymmetric with queries; easy to miss.

| Call site | Consequence offline |
|---|---|
| `FirestoreGameResultSyncService.swift:205` `fetchRemoteDeletedIds` | **The tombstone doc doesn't exist for any user who has never deleted a result.** This `try await` at line 115 throws → `syncIfNeeded`'s catch → `syncState = .failed`. The *entire* sync — including the local merge and `reconcileAfterResultSetChanged()` — is skipped offline, for the common case. Not data loss (local data is already loaded), but it means the "Sync failed" banner is the default offline experience. |
| `FirestoreAchievementSyncService.swift:70` | same shape; first-run user offline → `status = .error("Network unavailable")` (:179). Correct-ish. |
| `FirebaseSocialService.swift:156,193,220`; `+Friends.swift:255,259,287,422` | bounded; throw or return cached |

### 2c. `source: .server` reads — fail fast and *loudly*, on purpose

| Call site | Note |
|---|---|
| `+Friends.swift:168` (`acceptFriendRequest`), `:227` (`removeFriend(userId:)`), `:335` (`fetchProfiles`) | Deliberately bypass the cache to dodge the Watch/`areFriends()` false-denial bug (comments in place). Offline → `unavailable` within the ≤10 s ceiling → surfaced as `errorMessage`. **These are the only Firestore calls in the app that already behave well offline.** |

### 2d. Writes — **awaited, and they never return offline**

| Call site | Awaited from | What the user sees offline |
|---|---|---|
| `+Friends.swift:278` `batch.commit()` (`generateFriendCode`) | `FriendManagementView.swift:251` inside `load()`'s `isLoading = true; defer { isLoading = false }` | **Manage Friends sheet spins forever.** First-ever open offline is the guaranteed repro. |
| `+Friends.swift:262` `try? await codeDoc.setData(...)` | same `load()` | same spinner, second repro path (code exists locally, `friendCodes` mirror doc not cached) |
| `+Friends.swift:131` `setData` (`sendFriendRequest`) | `FriendManagementView.swift:293` `addFriendByCode()`, `isLoading` gated | **"Add friend" spins forever** |
| `+Friends.swift:192` `updateData` (`acceptFriendRequest`) | `FriendManagementView.swift:313` | Accept never completes, no error |
| `+Friends.swift:210,232` `.delete()` (`removeFriend`) | `FriendManagementView.swift:323` | Remove never completes |
| `+Friends.swift:394,412,424,437,450,460` `.delete()` (`deleteAllUserData`) | `AccountView.swift:442` inside `isDeletingAccount = true` | **Delete Account spins forever, no error, no way out but force-quit.** This is the App Store §5.1.1(v) account-deletion path. Highest severity. |
| `FirestoreGameResultSyncService.swift:279` `batch.commit()` (`uploadResults`) | `syncIfNeeded:132` | `syncState` stuck on `.syncing` → indefinite `ProgressView()` at `DataManagementView.swift:229-231`; pull-to-refresh at `FriendsView.swift:188` never ends. Reachable offline only when the tombstone doc *is* cached (§2b), so it's the rarer of the two sync outcomes. |
| `FirestoreGameResultSyncService.swift:139,141` (tombstone propagation, `try?`) | `syncIfNeeded` | same stuck `.syncing` |
| `FirestoreAchievementSyncService.swift:107` `setData` | `DataManagementView.swift:166,203` "Sync Now" | status stuck on `"Status: Syncing..."` forever |
| `FirestoreAchievementSyncService.swift:132` `.delete()` | Clear All Data | hangs |
| `+Scores.swift:77,132,194,233` `batch.commit()` | `AppContainer.swift:441`, `StreakSyncApp.swift:120` | `handleAppBecameActive()` never returns → `evaluateFirstLaunchNotificationPromptIfNeeded()` (`ContentView.swift:76`) never runs. No spinner; a silently truncated activation pipeline. |
| `FirestoreGameResultSyncService.swift:255` (`uploadResult`, detached `Task` at :227) | nobody | **Correct as-is.** Fire-and-forget, no UI attached. |

### 2e. Snapshot listeners — not affected

`+Leaderboard.swift:139,184,198`. Callback-based, fire on the cached snapshot immediately, error via
the `error` branch. Nothing to time-box.

### 2f. Existing time-boxing in the repo

`grep` for `withTimeout` / `withThrowingTaskGroup` / `Task.checkCancellation` across
`StreakSync`, `StreakSyncShareExtension`, `StreakSyncWidget`: **zero timeout races anywhere.** The
only precedents are fire-and-forget delays — `AppContainer.swift:412` (1 s flag reset) and
`AppContainer.swift:446` (5 s Share-Extension monitoring window) — plus a debounce at
`FriendsViewModel.swift:95-99`. There is no utility to extend; a timeout would be net-new
infrastructure.

---

## 3. Where a timeout would actually help

Only one place, and only because it can't be made optimistic:

- **`AccountView.swift:442` → `deleteAllUserData()`.** The user is entitled to know whether their
  cloud data actually died before the Auth account is deleted, so "fire and confirm later" is not
  available. Symptom fixed: a permanent, unescapable `isDeletingAccount` spinner on the
  account-deletion path.

Everywhere else in §2d, a timeout is the *wrong shape* — see §5.

---

## 4. Where a timeout would be actively harmful

- **Never cancel the write.** `PersistentCacheSettings` (`AppDelegate.swift:45`) selects the
  LevelDB-backed persistence stack, so the mutation queue is `LevelDbMutationQueue`
  (`Firestore/core/src/local/leveldb_mutation_queue.h:53`), which rehydrates itself from disk on
  `Start()` (`:60`) and can re-enumerate everything pending via `AllMutationBatches()` (`:74`) —
  i.e. queued writes are durable across app termination, not just in-memory. That is the correct
  behaviour and the reason offline works at all. A timeout must abandon the *await*, not the write.

- **The `withThrowingTaskGroup` trap.** The obvious implementation is wrong, and this is verified,
  not assumed: **there is not a single `withTaskCancellationHandler`, `Task.isCancelled`, or
  `CancellationError` anywhere in `Firestore/Swift/Source/`.** The hand-written async wrappers use
  bare `withCheckedThrowingContinuation`
  (`Firestore/Swift/Source/AsyncAwait/Firestore+AsyncAwait.swift:32,50,108`), and `commit()` /
  `setData()` come from the compiler-generated bridge over
  `commitWithCompletion:` / `setData:completion:`, which is likewise non-cancellable. So a Firestore
  write **structurally ignores Swift task cancellation**. When a child of a throwing task group
  throws, the group cancels its siblings and then *awaits* them — the commit child ignores the
  cancel, keeps the group suspended, and the "timeout" never returns. Same for `async let`. The only
  shape that works is an unstructured `Task` racing a `Task.sleep`, with a single-resume guard, and
  the losing branch deliberately orphaned.

- **`FirestoreGameResultSyncService.syncIfNeeded` — a timeout must map to `.failed`, never
  `.synced`.** The comment at `:266-269` is explicit that `saveLastSyncTimestamp` must stay after
  `uploadResults`. Advancing the watermark on a timed-out commit would make the next sync skip
  `toPush` while the write is still pending. It would eventually replay, so not loss — but the
  incremental window would be wrong in the interim.

- **`flushPendingScoresIfNeeded` doubles its own queue on every failure — fix this *before*
  anything makes failures more frequent.** `+Scores.swift:118` snapshots
  `let toFlush = pendingScores` **without removing them**, and `:139` does
  `pendingScores.append(contentsOf: toFlush)` in the catch. One failure → 2N entries; the next →
  4N. It is currently masked offline precisely *because* the commit hangs instead of throwing.
  A timeout would un-mask it and turn it into exponential Keychain growth on every activation.
  (Contrast `publishDailyScores:78-86`, which clears on success and appends a fresh local array —
  that one is correct.) The scores themselves are idempotent (deterministic `docId` +
  `setData(merge:true)`), so this is queue bloat, not corruption.

- **Timing out `publishDailyScores` is pointless.** `StreakSyncApp.swift:120`
  `reconcileRecentScores` already republishes the last 30 days at every launch. Nothing is lost by
  a hang there; nothing is gained by a timer.

---

## 5. Recommended scope

**Do not add a timeout mechanism.** Four surgical changes, none of which introduces a timer.
Roughly in dependency order.

**(1) Fix the pending-score duplication first.** `+Scores.swift:118` → remove the snapshot from
`pendingScores` when taking it, so the catch's re-append restores rather than doubles. One line.
Prerequisite for everything below, because everything below makes that catch reachable.

**(2) Stop awaiting the server ack on the four interactive social writes.**
`+Friends.swift:131` (send), `:192` (accept), `:210`/`:232` (remove), `:278`/`:262` (friend code).
Firestore applies the mutation to the local cache synchronously and the friendship listeners at
`+Leaderboard.swift:184,198` already drive `friendshipChangeTick` → `loadFriendshipState()`, so the
UI confirms itself. Shape:

```swift
// was: try await db.collection("friendships").document(docId).setData([...])
db.collection("friendships").document(docId).setData([...])   // no completion, no await
```

This deletes three indefinite spinners with zero timing logic and zero race. The reads that precede
each write stay awaited — they are already bounded (§2a/2b).

**(3) Gate account deletion on a bounded connectivity probe instead of timing it out.** Reuse the
pattern already in this file (`+Friends.swift:168,227,335`): a `source: .server` read fails within
the SDK's ≤10 s ceiling and never hangs.

```swift
// AccountView.runDeleteSequence, before step 1
do { _ = try await db.collection("users").document(uid).getDocument(source: .server) }
catch { errorMessage = "You need an internet connection to delete your account."; isDeletingAccount = false; return }
```

Nothing has been destroyed at that point, so the failure is clean. If a hard time-box is still
wanted here later, 20 s is the right number (2× the SDK's own online-state ceiling) and it must map
to an error, not to "deleted".

**(4) Make offline legible — wire the dead `.offline` state.**
`SyncState.offline` is set at exactly one place, `FirestoreGameResultSyncService.swift:100`, for
"no authenticated user". A real network outage never produces it. Meanwhile
`FriendsPresentationState.swift:64` has a fully built, top-precedence
`.offline(showingCachedScores:)` branch, a `FriendsStateView`, and a test file — all unreachable in
production. Map the error instead of reporting it as a failure:

```swift
} catch {
    if (error as NSError).domain == FirestoreErrorDomain,
       FirestoreErrorCode(_bridgedNSError: error as NSError)?.code == .unavailable {
        syncState = .offline          // "Offline — showing cached scores"
    } else {
        syncState = .failed(error)    // "Sync failed"
    }
}
```

~6 lines. Turns the current default offline experience — a red "Sync failed — scores are saved
locally" (`FriendsView.swift:135`) — into the honest, already-designed one.

**In-flight operations:** unchanged in every case. Nothing is cancelled; Firestore's on-disk
mutation queue keeps replaying. The only thing that changes is how long the UI stares at it.

---

## 6. What could go wrong, and how a test catches it

| Risk | Test |
|---|---|
| (2) fires a write the rules reject (e.g. `permissionDenied` on a friendship) and the user now gets no error at all | `firestore-rules-tests/` already has the pen-test suite; the accept/remove rules are covered. The residual risk is a *silent* rules failure — mitigate by keeping the `Logger.error` on the completion handler rather than dropping the handler entirely. |
| (4) mis-maps a non-network error to `.offline` and hides a real permission bug | `StreakSyncTests/CloudSyncPresentationTests.swift` + `FriendsPresentationStateTests.swift` already exist. Add two cases: `unavailable` → `.offline`, `permissionDenied` → `.failed`. **Vacuity check required:** these must be run against the current mapping (which returns `.failed` for both) and observed to fail before the fix lands — otherwise they pass for the wrong reason. |
| (1) the de-dup fix silently drops scores instead of duplicating them | No runnable suite covers `flushPendingScoresIfNeeded` — it reaches straight into `Firestore.firestore()` with no seam. Honest statement: **this change is untestable as the code stands.** Making it testable means injecting the `WriteBatch` commit behind a protocol, which is a larger change than the fix. Recommend landing the one-liner with a hand-verified offline device pass, or scoping the seam separately. |
| (3) probe passes but the subsequent deletes still hang (network dies in the 2 s between) | Genuinely possible and accepted. The probe reduces a certain hang to a narrow race; it does not eliminate it. If that residual matters, that is when §3's 20 s time-box earns its complexity — not before. |

---

## 7. Cheaper alternatives that may dominate all of the above

Yes — and one of them probably should ship first.

- **Surface the persisted "last synced".** `saveLastSyncTimestamp` (`FirestoreGameResultSyncService.swift:67`)
  already writes `gameResultSync_lastTimestamp_<uid>` to `UserDefaults`, and
  `lastSyncTimestamp` (:61) already reads it back — but **nothing renders it**.
  `DataManagementView.swift:222` shows only the in-memory `.synced(date)`, which is `.notStarted`
  on every cold launch. Exposing the persisted value as `"Last synced 2h ago"` is ~5 lines, has no
  failure mode, and converts "is this thing even working?" into an answer. Strictly dominates a
  timeout for the *informational* half of the problem.

- **Manual retry already exists in two of three places** — `DataManagementView.swift:243-252`
  (Retry on `.failed`) and `FriendsView.swift:186-189` (`retryLoad`). The gap is that neither can
  currently be reached from a *hung* `.syncing`, because `.syncing` renders a bare `ProgressView`
  with no affordance (`DataManagementView.swift:229-231`). Giving `.syncing` a tappable
  "Retry" after a while is cosmetic relief; item (4) above removes the need by making the state
  resolve correctly.

- **What no cheap alternative covers:** the three interactive spinners in `FriendManagementView`
  and the one in `AccountView`. Those are structural — the code awaits an ack that will not come.
  §5 items (2) and (3) are the minimum honest fix, and neither is a timeout.

**Suggested ROADMAP rewrite:** replace *"No Firestore request timeout — `App/AppDelegate.swift:38`"*
with *"Awaited Firestore writes hang indefinitely offline — `FirebaseSocialService+Friends.swift:131,192,210,232,278`,
`AccountView.swift:442`"*, and close the `AppDelegate` entry as invalid.
