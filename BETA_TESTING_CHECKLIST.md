# StreakSync Beta Testing Checklist

Use this checklist to verify the simplified Friends experience before each beta drop.

## Core Flow
- [ ] Fresh install → launch app without crashes
- [ ] Friends tab loads initial leaderboard
- [ ] Invite friends CTA is visible
- [ ] Share link generates successfully
- [ ] Share link shares through Messages/Copy

## Friend Acceptance
- [ ] Friend taps share link and accepts CloudKit share
- [ ] Invitee appears in sender's leaderboard
- [ ] Sender appears in invitee's leaderboard
- [ ] Date selector + game switcher continue to work after acceptance

## Score Publishing
- [ ] Complete a game → score shows in personal leaderboard
- [ ] Shared friend sees updated score
- [ ] Sorting favors higher scores; ties break alphabetically
- [ ] Pull-to-refresh updates leaderboard without crashes

## Offline / Local Mode
- [ ] Enable Airplane Mode → app shows cached data
- [ ] Invite button shows friendly error when offline
- [ ] Scores queue locally and sync after reconnection
- [ ] No crashes when visiting Friends tab offline

## Error & Edge Cases
- [ ] No iCloud account → Friends tab communicates local-only mode
- [ ] Share link creation failure → user sees retry option
- [ ] Accepting same link twice does not crash
- [ ] Invalid/expired link → friendly error toast
- [ ] Switching devices retains single \"Friends\" group

## Feedback + Onboarding
- [ ] Beta welcome modal appears once for new installs
- [ ] Beta feedback button opens form and logs payload
- [ ] Feedback form includes optional debug info toggle

Document each run in TestFlight notes to track pass/fail for the above scenarios.

