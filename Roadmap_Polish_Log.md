# StreakSync – Internal Roadmap and Polish Log

Purpose: keep a lightweight, read-friendly log of what we shipped, what’s next, and why. Each item links back to prior plans/notes so we can trace decisions.

Sources and trace
- `StreakSync/ARCHITECTURE.md`: app structure, MVVM, DI, services
- `CLOUDKIT_REFERENCE.md` + `CLOUDKIT_SYNC_DOCUMENTATION.md`: CloudKit schemas, zones, subscriptions, error handling
- `NOTIFICATION_SYSTEM_ANALYSIS.md`: notification categories, flows
- `GAME_PROGRESS_DOCUMENT.md`: gameplay/result flows and analytics
- `Codebase_Analysis_Progress.md`, `st.plan.md`: earlier planning and progress notes

Status legend
- Done: shipped to internal testers
- Next: targeted for the next 1–2 internal builds
- Backlog: queued polish/features
- Parked: keep in mind, not scheduled


## Shipped (Internal)
- CloudKit Achievements (private sync across user’s devices) [trace: CLOUDKIT_REFERENCE.md §PrivateDB; ARCHITECTURE.md §Services/Sync]
- AchievementsZone + idempotent zone/subscription [trace: CLOUDKIT_SYNC_DOCUMENTATION.md §Zones]
- Error handling + simple retry/backoff for Achievements [trace: CLOUDKIT_REFERENCE.md §Errors]
- iCloud on-by-default; Debug-only “Test Connection” [trace: st.plan.md]
- Shared Leaderboards via CKShare (default “Friends” share, no explicit groups) [trace: CLOUDKIT_REFERENCE.md §Sharing]
- Invite Friends (UICloudSharingController) + participant names [trace: CLOUDKIT_REFERENCE.md §Participants]
- Sharing status chip in Friends header; quick Invite button
- Stop Sharing on this device (local clear) [trace: st.plan.md]
- TestFlight “What to Test” (internal) [trace: Codebase_Analysis_Progress.md]
- Export compliance keys, iOS minimum set to 18.0


## Next (pick 2 per build)
1) Leaderboard auto-refresh on push
   - When “leaderboard_…” zone push arrives, refresh the active group automatically (throttle to avoid spam)
   - Trace: `CLOUDKIT_REFERENCE.md` §Subscriptions; `ARCHITECTURE.md` §Notifications

2) Robust retry/backoff for shared scores
   - Mirror Achievements retry policy for publish/fetch (network, rate-limits, zone busy); add small jitter
   - Trace: `CLOUDKIT_SYNC_DOCUMENTATION.md` §Error Handling

3) Participants list & controls
   - Surface participants (owner/reader), “Invite more”, “Leave share” (recipient), owner revoke (UI guidance)
   - Trace: `CLOUDKIT_REFERENCE.md` §Sharing/Participants

4) Offline queue for publish (store-and-forward)
   - Queue DailyScore writes when offline/iCloud unavailable, flush on availability; idempotent by composite id
   - Trace: `GAME_PROGRESS_DOCUMENT.md` §Flows

5) Lightweight telemetry (privacy-friendly)
   - Events: share accepted, publish success/failure, auto-refresh triggered; DEBUG-only log sink initially
   - Trace: `Codebase_Analysis_Progress.md`


## Backlog (polish and UX)
- Better empty states and loading skeletons in Friends
- “What’s new” in-app after updates (internal builds only)
- Accessibility pass (Dynamic Type, VoiceOver strings in Friends/Manage)
- Localization scaffolding (start with en; structure keys)
- Achievements UI polish (progress clarity, summaries)
- Share Extension: parsing resilience + quick “open app” deeplink
- Settings: “Re-check iCloud” diagnostic and log copy


## Open decisions
- Share scope: keep per-day score only (current) vs. optional sanitized result payload (opt‑in)
- Participants management depth: in-app revoke vs. rely on system UI
- Analytics: ship minimal, debug-only first; QA confirms no personal data leaves device without consent


## QA checklists (internal)
- Private sync: A→B (same Apple ID) matches Achievements; “Last synced …” shows
- Sharing: invite accept works; scores appear A→B and B→A; push auto-refresh (once implemented)
- Offline: scores queued and flush after reconnect; no duplicates
- Stop Sharing (local): new scores no longer publish; re-invite restores


## Release notes snippets (internal)
- Build N: “Shared leaderboards via iCloud (Friends), Achievements sync private by default; iCloud on with zero setup.”
- Build N+1: “Auto-refresh on push, stronger retry on publish/fetch, participants list (read-only).”


Changelog (append per build)
- 2025‑11‑13: Default Friends share (no groups), Invite Friends, participant names, sharing chip, Stop Sharing (local), TestFlight notes, iOS 18.0 minimum, export compliance keys.


