# Audit archive

Point-in-time findings. **None of these is status.**

`ROADMAP.md` at the repo root is the only status document — it is the one that was verified
line-by-line against the code rather than carried forward from an earlier pass. Everything
here is kept for the findings and the reasoning behind them.

That distinction has already cost real time: on 2026-08-29 five parallel agents re-derived a
backlog from these ledgers, and roughly 70% of what they reported as open came back already
fixed. If you want to know what is left, read `ROADMAP.md` and stop there.

| File | Compiled | What it was |
|---|---|---|
| `UI_SYSTEM_AUDIT.md` | 2026-08-06 | Typography, spacing, token and rhythm audit of the whole UI |
| `UI_AUDIT_RESEARCH_ASKS.md` | 2026-08-06 | Research brief written alongside the UI system audit |
| `REDDIT_LAUNCH_AUDIT.md` | 2026-08-07 | Pre-launch pass over the objections a Reddit audience would raise |
| `SECURITY_AUDIT.md` | 2026-02-26 | Firebase rules, auth and data-handling review |

## Ledgers that are not in this repo

Several older ledgers are **local-only by design** — `.gitignore` excludes them under
"Internal development docs" and "Internal QA artifacts":

- `CODEBASE_AUDIT.md`, `DESIGN_AUDIT.md`
- `ACHIEVEMENTS_MODULE_ANALYSIS.md`, `ANALYTICS_MODULE_ANALYSIS.md`, `FRIENDS_MODULE_ANALYSIS.md`
- `docs/shakedown-*.md`
- `.superpowers/audit_2026-07-24_findings.md`

If you cloned this repo they do not exist for you, and nothing here depends on them. They are
named in `ROADMAP.md` only so that a reader who *does* have them locally knows they are
superseded too.

One live document is caught by the same rules and is worth knowing about:
`docs/notification-runtime-device-shakedown.md` is an **unexecuted runbook**, not an archive —
the device-side notification checks that have never been run. It is excluded by
`docs/notification-runtime-*.md`, so it exists only on the machine it was written on.
