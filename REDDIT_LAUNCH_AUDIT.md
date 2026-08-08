# Reddit Launch Audit — StreakSync

**Date:** 2026-08-07
**Purpose:** Pre-publicity hardening. StreakSync is live on the App Store; before promoting on Reddit / HN / AI-dev subs (where scrutiny of indie + AI-built apps is high), find and fix the issues most likely to surface as public complaints.

**Method:** (1) DeepSeek v4 Flash generated a hypothesis set of ~15 likely objections; (2) a GPT deep-research pass validated them against real Reddit/HN/App Store sources (Reddit is blocked to our in-house tools, so this half was run externally); (3) every actionable claim was verified against this codebase directly + two read-only subagent traces (ingestion pipeline; onboarding/export/deletion).

Confidence legend: **[verified-code]** confirmed in source this session · **[external]** from GPT live-research citations · **[owner]** non-code, App Store Connect.

---

> **STATUS 2026-08-08:** Tier 1 + Tier 2 IMPLEMENTED on branch `fix/tier1-data-integrity`
> (not merged, NOT device-verified).
> - Tier 1: T1-1 + T1-2 = `71ce799`; T1-3 = `30f2da2`.
> - Tier 2: T2-3 = `fafdae3`; T2-4 = `78e63c7`; T2-2 = `67e551c`; T2-1(a) + T2-5 = `5afb5a7`.
> - T2-1(b): `b893d65` — **scoped as hardening, not a rebuild.** The full-history cloud
>   backup+restore already existed (FirestoreGameResultSyncService: merge, tombstones,
>   incremental sync, restore on reinstall via Keychain-persisted anon UID). This commit
>   extracts a pure, unit-tested `GameResultSyncMerge` (the old tests pinned an inline copy),
>   bounds the cold/full remote fetch to newest `maxResults`, and applies the cap consistently
>   in `syncIfNeeded` (after push selection — P0 guard against dropping local-only history)
>   so a cold resync converges instead of re-pull-then-drop churn. Design spec (gitignored):
>   `docs/superpowers/specs/2026-08-08-t2-1b-cloud-backup-hardening-design.md`.
>   DeepSeek 2nd-opinion pass surfaced the P0 prune-ordering invariant + a deterministic
>   date-tie break; both baked in.
> - T2-2 App Store URL fallback: `0f4cfe2` — live link
>   `https://apps.apple.com/us/app/streaksync-puzzle-tracker/id6755203446` now in the invite.
> App + Share Extension + test target all build green (only pre-existing Sendable warnings).
> **Still open:** O-1 (App Store "CloudKit" copy — owner action). Everything code-side for
> Tier 1 + Tier 2 is done; next is device-verify + merge to main.

## TIER 1 — Data-integrity bugs (must fix before posting)

These make the app actually lose a user's streak — the worst outcome for a "never lose a streak" product, and the exact failure that tanked competitor Scordle ("save button did nothing").

### T1-1 — Share Extension shows "Saved" even when the App Group write silently fails  [verified-code]
- **Where:** `StreakSyncShareExtension/ShareViewController.swift:138-155`, `213-282`
- **Problem:** `saveResult` returns `Void` and swallows all failures (catch at ~279 only logs). `UserDefaults(suiteName:)` is optional, so every write is `userDefaults?.set(...)`. If the App Group container is unresolvable (entitlement/provisioning drift — CLAUDE.md notes the extension hardcodes the group id), all writes no-op, the Darwin notification fires against nothing, and the user still sees the green "Saved to StreakSync" card.
- **Fix:** make `saveResult` `throws`/return `Bool`; `guard let userDefaults = UserDefaults(suiteName:) else { throw }`; only transition to `.success` after a confirmed write, else show the existing `FailureCard`.
- **Severity:** MAJOR (silent loss + false success).

### T1-2 — Queue keys cleared BEFORE the result is durably persisted  [verified-code]
- **Where:** `StreakSync/Core/Services/Sync/AppGroupResultMonitor.swift:74-91` (clears at line 78), `AppGroupBridge.swift:127-153` (also clears `latestGameResult` fallback at 149), `AppState+ResultAddition.swift:88-100` (save is a detached `Task`).
- **Problem:** the queue keys + fallback are deleted *before* the async `saveGameResults()` disk write completes. If the app is killed (jetsam/crash/swipe) in that window, the result is in neither the queue nor `game_results.json` → permanent silent loss. Violates CLAUDE.md's own stated guarantee that a result can't be removed before durable persistence.
- **Fix:** clear queue keys only after persistence confirms a durable write (return results without clearing; ack back after save completes), or await the save before clearing.
- **Severity:** MAJOR.

### T1-3 — Streaks derived from device receipt time, not the puzzle's date  [verified-code] [external]
- **Where:** parsers set `date: Date()` (`GameResultParser.swift:64`, `GameResultParser+LinkedIn.swift` many) though they *capture* `puzzleNumber`; streak math uses `GameDateHelper.daysBetween` → `Calendar.current` + `startOfDay` (`GameDateHelper.swift:82-90`), i.e. device-local calendar days from the log timestamp.
- **Problem:** the streak reflects *when you logged it on this device*, not which puzzle it was. Crossing time zones / the date line miscounts days → lost streaks. GPT research rated this the single strongest, best-evidenced Reddit objection (direct r/wordle + r/NYTConnections travel-loss threads; a Dec-2025 App Store review of a habit tracker calling tz handling "a huge problem").
- **Fix:** derive the canonical puzzle date from `puzzleNumber` (anchor date + N) for games with sequential daily numbers; use that for streak continuity, with a receipt-date fallback for games lacking a usable number. Makes streaks timezone-immune — a genuine edge over NYT, which has this bug itself.
- **Severity:** MAJOR (correctness + top public objection).

---

## TIER 2 — Gaps & correctness polish

### T2-1 — No cloud backup of full history (local-only durability)  [verified-code]
- **Where:** `AppState+Persistence.swift` (UserDefaults is authoritative; `recentResults` = "source of truth", line ~407). Firestore holds only *recent* scores + profile + friendships, not full history.
- **Problem:** on app delete/reinstall, UserDefaults is wiped → entire history gone, signed-in or not. Anonymous→Apple/Google linking preserves the cloud UID/identity (`FirebaseAuthStateManager.swift:129,214`) but NOT local history. No in-app warning. (iOS device backups include UserDefaults, so restore-from-backup recovers it — invisible to users, doesn't cover new-device-without-backup or never-sign-in users.) Manual JSON export exists as partial mitigation.
- **Fix (cheap→thorough):** (a) surface a "your data is on this device — sign in to back it up" message; (b) sync full history to Firestore under the UID and restore on sign-in/reinstall.
- **Severity:** MAJOR data-durability gap.

### T2-2 — Add-friend has no share link / QR  [verified-code]
- **Where:** `Features/Friends/Views/FriendManagementView.swift:85-95` (copy-code only). Inbound `streaksync://join?code=` handler ALREADY exists (`NavigationCoordinator.swift:283`, `AppGroupURLSchemeHandler.swift:42`) but nothing generates the link.
- **Fix:** replace the Copy button with a `ShareLink` emitting `streaksync://join?code=<CODE>` + an App Store fallback URL. Small, high-leverage cold-start fix.
- **Severity:** MEDIUM (cold-start friction).

### T2-3 — Duplicate re-share fires a bogus "result imported" notification  [verified-code]
- **Where:** `NotificationCoordinator.swift:163-192` uses a `contains(by id)` proxy for `added`; a re-shared duplicate reads as `added == true`.
- **Fix:** have `addResult` return the real `Bool` from `addGameResult` and use it directly.
- **Severity:** MINOR.

### T2-4 — Manual entry bypasses immediate Firestore sync  [verified-code]
- **Where:** `ManualEntryView.swift:134-152` calls `addGameResult` directly, not `gameResultSyncService.addResult`; cloud copy waits for next `syncIfNeeded`.
- **Fix:** route manual entry through `gameResultSyncService.addResult` for parity. Not lost locally; cloud merely delayed.
- **Severity:** MINOR.

### T2-5 — `syncIfNeeded` failure is silent  [verified-code]
- **Where:** `FirestoreGameResultSyncService.swift:161-164` — `catch` sets `.failed` with only a log; no user signal, no retry beyond next launch. Local data not lost; cloud divergence invisible.
- **Severity:** MINOR.

---

## Owner action — non-code

### O-1 — App Store description says "CloudKit-powered sync" but the app uses Firebase  [verified-code] [owner]
- The codebase contains **zero CloudKit**; backend is Firebase/Firestore, which also contradicts the app's own privacy policy. For a privacy-scrutinizing audience this reads as "your public copy can't agree on where my data lives."
- **Fix:** edit the App Store Connect description to Firebase/Firestore (or neutral "secure cloud sync"). Not in the repo (no fastlane/metadata dir) → manual App Store Connect edit. Also resolves the privacy-contradiction objection.

---

## Done this session
- Removed the inaccurate "iOS 26+" requirement claim from 11 docs (CLAUDE.md, CODEBASE_AUDIT.md, 9 `.claude/commands/review-*.md`). Real deployment floor is iOS 18.6; iOS 26 features are correctly `#available`-gated.

---

## Verified GOOD — no fix (some are launch assets)
- **Privacy story is strong & the App Store label is accurate:** email is never written to Firestore (auth-only, optional sign-in); "Identifiers" = pseudonymous Firebase UID; no location/ads-ID/analytics. Usable rebuttal to "free = I'm the product."  [verified-code]
- Solo cold-start experience is complete without friends/sign-in; Friends tab resolves to proper sign-in card / per-game empty states (design-audit empties intact).  [verified-code]
- Full JSON export + import in Settings → Data & Privacy.  [verified-code]
- Account deletion is thorough, reauth-first, wipes Firestore + local (App Store 5.1.1 satisfied).  [verified-code]
- Local save path is hardened: failed saves surface an error + queue in `PendingSaveStore`, flushed on next launch; atomic file writes.  [verified-code]
- The historical `syncIfNeeded` data-loss bug (stale pre-await snapshot) is already fixed (re-reads `recentResults` after awaits).  [verified-code]
- Queue TOCTOU index merge, corrupted-queue recovery, and the lifecycle backstop (drains on `didBecomeActive`/`willEnterForeground`, not just Darwin) are robust.  [verified-code]

---

## Debunked — do not chase
- **iOS-26-only requirement** — false; app is 18.6.  [verified-code]
- **Parsers get hard-mode wrong** — NO real evidence; keep only as a parser test case.  [external]
- **AI-dev subs punish "I shipped an app"** — refuted; r/ClaudeAI/ClaudeCode/Codex *permit/encourage* disclosed showcases; they punish drive-by download posts and disguised promotion.  [external]

---

## Positioning (launch copy, not code)
- **Don't** lead with "AI-built" on consumer subs; **do** lead with it + engineering substance (the 90-case Firestore rules suite is a flex) on AI-dev subs. AI-built is a positioning problem, not a dealbreaker.  [external]
- **Wedge vs NYT:** NYT now has multi-game stats AND friend leaderboards. Pitch cross-publisher aggregation + independent history ("one history across NYT + LinkedIn + Quordle/etc., independent of any publisher"), not "track your Wordle streak."  [external]
- **Leaderboard = social/honor-system, never competitive** — self-reported scores are trivially gameable; make no anti-cheat/ranking claims, no global board.  [external]
- Honest one-liner that survives scrutiny: *"a free dashboard for people who play multiple daily puzzle games — not a replacement for NYT Games, not for people who only play Wordle."*

---

## Suggested implementation order (next session)
1. **T1-1 + T1-2 together** (silent-loss pair — the highest-stakes, reproduces the competitor's fatal flaw).
2. **T1-3** (puzzle-date streak logic — top public objection; needs a per-game puzzle-number → date map + fallback).
3. **T2-1** (data-durability warning at minimum; full-history cloud backup if scoped).
4. **T2-2** (ShareLink invite — cheap cold-start win).
5. **T2-3/4/5** polish.
6. **O-1** App Store copy (do anytime, independent of code).

Artifacts: DeepSeek hypotheses + GPT validation report retained outside the repo (scratchpad / `~/Downloads/deep-research-report (2).md`).
