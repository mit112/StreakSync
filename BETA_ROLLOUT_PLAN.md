# StreakSync Beta Rollout Plan

## Wave 1 – Internal (10 users)
- Distribute TestFlight build `2.0.0 (2000)`
- Focus on team + power users
- Collect feedback via in-app Beta Feedback form
- Monitor metrics daily:
  - `beta_users_total`
  - `friends_added`
  - `inviteLinkCreated` vs `inviteLinkFailed`
  - Crash-free sessions

### Exit Criteria
- Crash rate < 1%
- 80% of testers send or accept at least one invite
- No data loss incidents

## Wave 2 – Extended (Up to 50 users)
- Invite trusted community testers
- Share quick-start doc + checklist
- Enable TestFlight feedback e-mail triage
- Continue monitoring metrics and add:
  - Daily active users
  - Feedback sentiment (positive/neutral/negative)

### Exit Criteria
- Crash rate < 0.5%
- Friend addition success > 70%
- Positive feedback ratio > 70%

## Wave 3 – Pre-Launch (Public Beta)
- Expand to 150–200 users once previous criteria met
- Enable additional feature flags for A/B testing (reactions/activity feed)
- Run regression pass using `BETA_TESTING_CHECKLIST.md`
- Prep App Store metadata + release notes

## Production Launch Readiness
- ✅ Technical:
  - All beta blocking bugs resolved
  - Invite links stable for 7 consecutive days
  - Metrics pipeline (BetaMetrics logs) monitored daily
- ✅ Operational:
  - Support channel staffed
  - Known issues document shared
  - Rollback plan finalized (`remote_social_enabled` kill switch)

## Monitoring
- Use `BetaMetrics` logs in Console / unified logging to spot regressions
- Cross-check with Crashlytics dashboards
- Track share link success/fail ratio daily
- Review feedback exports twice per week

