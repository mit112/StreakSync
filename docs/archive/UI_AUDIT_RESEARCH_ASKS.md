# Research asks for GPT — UI audit follow-up

> **Findings archive — not status.** This is the research brief written alongside the UI system audit as it stood on 2026-08-06.
> Its open-items sections are superseded by [`ROADMAP.md`](../../ROADMAP.md), which is the
> only document verified line-by-line against the code. A large majority of what this file
> lists as open has since shipped — five parallel agents re-derived a backlog from these
> ledgers on 2026-08-29 and roughly 70% of it came back already fixed. Kept for the findings
> and the reasoning behind them, not for the state.

Blockers I could not clear in-session: Apple's HIG pages are JavaScript-rendered (plain fetch
returns only the page title, no public JSON API), the Chrome extension wasn't connected, and the
web-search budget was exhausted. GPT with browsing can close these.

**Ground rule for all four: Apple sources only** — developer.apple.com, WWDC transcripts,
apple.com, Apple support docs. Do not cite Material Design, Refactoring UI, Bootstrap, or any
non-Apple design system. If Apple is silent on something, say "Apple is silent" rather than
substituting another platform's guidance.

**Output format for all four: the verbatim quote + the exact URL.** Paraphrase is not useful —
the whole point is having Apple's own words. Say "no Apple quote found" when there isn't one.

---

## Ask 1 — Depth: materials vs. drop shadows (highest value)

This determines whether the audit's §5.1 recommendation stands. Currently marked
HIG-*derived*, not verbatim.

From **HIG → Materials**, and any WWDC design session that covers it:

1. What does Apple say about using system materials (blur + vibrancy) to separate content
   layers? Quote the relevant passages.
2. Does Apple anywhere endorse, discourage, or discuss **drop shadows on resting content
   containers** on iOS? I need to know whether an always-elevated shadowed card is an
   Apple-endorsed iOS pattern or a foreign import.
3. What does HIG say about elevation communicating *temporary* focus vs. permanent decoration?
4. Anything in iOS 26 / Liquid Glass guidance about what should and should not carry a shadow
   now that glass is the elevated material.

*Context: the app has 18 `.shadow()` call sites plus a shared `.cardStyle()` that puts a
`y:4, radius:10` shadow on every card, versus 17 uses of system materials.*

## Ask 2 — iOS 26 floating tab bar content clearance

A confirmed visual bug: at accessibility text sizes the last list row and a section header
render clipped behind the floating tab bar.

1. What does Apple say developers must do so scrollable content isn't clipped behind the
   iOS 26 floating tab bar? Look for safe-area insets, `.tabBarMinimizeBehavior`, scroll edge
   effects, `.safeAreaInset`, or `contentMargins` guidance.
2. Is the clearance automatic for `List`/`ScrollView` inside a `TabView`, or must it be added?
   If automatic, what commonly defeats it?
3. Any guidance on the tab bar's minimize-on-scroll behavior and how it interacts with content
   insets.

Relevant: HIG → Tab bars; WWDC25 sessions on the new design system (356) and Liquid Glass (219);
SwiftUI `TabView` docs.

## Ask 3 — Typography: how many levels, and the small-text floor

1. Does Apple give guidance on how many text styles to use on one screen?
2. Is there Apple wording establishing `.body` as the baseline other styles are relative to?
3. Any Apple guidance on a **minimum legible text size**, or on over-reliance on
   `.caption`/`.caption2`?
4. What does Apple say about when a custom (non-semantic) font size is acceptable?

*Context: the app uses `.caption` + `.caption2` 199 times against `.body` 17 times, plus 13
distinct hardcoded point sizes. I want Apple's own words on why that inversion is a problem.*

## Ask 4 — WITHDRAWN, already answered

The AI-tells research was recovered from the killed agents' on-disk transcripts and is written
up in §7 of `UI_SYSTEM_AUDIT.md`, sourced and graded A–D. The accent-strip question is settled:
**Grade A tell**, named independently by Krebs's ai-design-checker (check #5 "Accent stripe"),
nexu-io/open-design (P0), Impeccable ("Side-tab accent border"), and Developers Digest (#11) —
with the honest caveat that the famous "as reliable as em-dashes" quote is anonymous n=1.

One genuinely open sub-question, low priority: **is there a tells corpus for native iOS/mobile
specifically?** Everything recovered is measured on web landing pages. If a native-mobile
equivalent exists, it would be worth having; if it doesn't, say so and we stop looking.

---

## Already settled — do not re-research

- **Per-item colour encoding.** Answered verbatim from WWDC25 session 356 ("Instead of relying
  on decoration, hierarchy should be expressed through layout and grouping") and session 219
  ("If you want to imbue color into your app, do it in the content layer instead"). Apple uses
  one authored hue per app for interactivity; item identity comes from artwork or nothing;
  tinted glyphs are for fixed category sets, never unbounded item sets.
- **Concentric corner radius.** `inner = outer − padding`, clamped to 0; iOS 26 ships
  `ConcentricRectangle` and `.containerShape(.rect(cornerRadius:))` so it resolves automatically.
- **Collections vs. lists.** HIG Collections: *"Consider using a table instead of a collection
  for text… collections are ideal for showing off image-based content."*
- **Layout numbers.** `systemMinimumLayoutMargins` = 16pt compact / 20pt regular; 44×44pt
  minimum hit target; 8pt spacing rhythm.
