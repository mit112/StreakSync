# StreakSync UI System Audit — 2026-08-06

Full-throttle audit of spacing, symmetry, and type across all 173 Swift files, plus live
runtime measurement on iPhone 17 Pro (iOS 27) at default and AX5 text sizes.

**Verdict in one line:** the *taste* is fine — color discipline is genuinely good, the
component inventory is sensible. What's broken is that **there is no enforced system
underneath it.** Three of the four design dimensions have a token file that almost nobody
calls, and the fourth (typography) has no token file at all.

---

## 1. The headline numbers

These are counted mechanically across `StreakSync/`, not estimated.

| Dimension | Tokenized? | Adoption | Verdict |
|---|---|---|---|
| **Spacing** | `UIConstants.Spacing` (6 values) | **44 token uses vs 452 raw literals → 8.9%** | Exists on paper only |
| **Corner radius** | `UIConstants.CornerRadius` (3 values) | **28 vs 86 raw → 24.6%** | Weak |
| **Card chrome** | `.cardStyle()` in `CardModifiers.swift` | **19 uses vs 102 hand-rolled `RoundedRectangle`** across 39 files → **15.7%** | Effectively unused |
| **Screen padding** | `Layout.contentPadding` | **1 use vs 71 bare `.padding()`** | Not a system |
| **Typography** | — | **No type scale file exists anywhere in the repo** | Missing entirely |
| **Dynamic Type** | `@ScaledMetric` | **7 uses** app-wide, against ~90 fixed frames sized next to text | Missing |
| **Tabular numerals** | `.monospacedDigit()` | **7 uses** in a streak-tracking app | Missing |
| **Touch targets** | `.minTapTarget()` | **4 uses**; ~20 sub-44pt controls found | Missing |

### What's actually *good* (don't break these)
- **Color discipline is strong.** `.secondary` 153 · `.primary` 32 · `.tertiary` 29, with hue
  used sparingly (blue 16, orange 14, green 8, red 5, yellow 3). This is not a rainbow UI.
- **`foregroundColor` is fully eliminated** — 0 occurrences. API modernization held.
- `NavigationStack`, `@Observable`, async/await, OSLog all clean.

### The drift, in one table

| | Declared | Actually in use |
|---|---|---|
| Spacing values | 6 (4/8/12/16/20/24) | **17** (0,2,3,4,5,6,8,10,12,14,16,20,24,28,32,40,60) |
| Corner radii | 3 (12/16/20) | **11** (1,2,3,4,6,8,10,12,16,18,32) — note **20 never appears**, but 10 and 18 do |
| Type levels | — | **12 text styles + 13 hardcoded sizes = ~25** |

**~91 spacing occurrences sit off the 4pt ramp entirely** (values 2, 3, 5, 6, 10, 14, 28).
That is `anti-inconsistent-spacing` almost by definition: no single gap is wrong, but the
accumulation is what reads as machine-assembled rather than designed.

---

## 2. The type ramp is inverted

Distribution of text styles across the app:

```
.caption    140  ┃████████████████████████████
.subheadline 77  ┃███████████████
.caption2    59  ┃████████████
.headline    44  ┃█████████
.system(size:)31 ┃██████        ← hardcoded, defeats Dynamic Type
.title3      28  ┃██████
.title2      23  ┃█████
.body        17  ┃███           ← the semantic baseline, barely used
.title        6  ┃█
.largeTitle   4  ┃
.callout      2  ┃
.footnote     1  ┃
```

`.caption` + `.caption2` = **199 uses**. `.body` = **17**. The app is built almost entirely
out of small text, so there is no baseline for hierarchy to depart *from* — everything is
already demoted, and emphasis has to be manufactured with weight and hue instead.

Weight is doing real work (116 explicit weight modifiers), which is correct per
`vis-typo-weight-hierarchy`. The problem is the *floor*, not the ceiling.

### 13 hardcoded font sizes (`ios-hig-dynamic-type` violation)
9, 16, 18, 20, 26, 28, 34, 36, 40, 44, 48, 50, 60 — across 22 files.

Most are decorative SF Symbol glyphs (defensible-ish, but they freeze while adjacent text
scales). **Four are real content text and are straight P0s:**

| File:line | Size | What it is |
|---|---|---|
| `Features/Games/Views/GameResultSeal.swift:69` | 34 | **The score** — the single most important number on the result screen |
| `Features/Shared/Components/GradientAvatar.swift:22` | `size*0.45` | Friend initials — every avatar in Friends/leaderboard |
| `Features/Onboarding/Views/ShareSheetMockup.swift:94,108` | **9** | Real labels at 9pt, frozen |

---

## 3. The home screen — measured, not estimated

You asked for this one specifically. I ran the app and measured the live view hierarchy.
Screen is 402pt wide (iPhone 17 Pro, iOS 27).

### The formula (sourced)

**Precedence: Apple HIG is the bible.** Apple states rules more often than it states numbers.
Where Apple specifies a value, it wins outright. Where it doesn't, the answer below is derived
from Apple's own APIs and shipping apps — not imported from another platform's design system.

**Apple's own, non-negotiable:**

| Rule | Apple's value |
|---|---|
| Screen-edge margins | `systemMinimumLayoutMargins` = **16pt compact width**, 20pt regular |
| Minimum hit target | **44×44pt** — the one hard number HIG states outright |
| Spacing rhythm | 8pt increments (8/16/24/32); SwiftUI's default `.padding()` = 16 assumes this |
| Dynamic Type | Semantic text styles; **never** hardcode point sizes |
| SF Symbols | Match symbol **weight** to adjacent text weight; scale is relative to **cap height** |
| Readable width | Constrain text-heavy content to the readable-content-width guide |
| Concentric corners | iOS 26 ships `ConcentricRectangle` / `.containerShape(.rect(cornerRadius:))` — Apple now treats nested-radius correctness as a first-class API |

**Where Apple publishes no number.** Apple states rules more often than values. For the
handful of gaps below, the answer is derived from Apple's own APIs and shipping apps — not
imported from another platform's design system:

| Gap | Derived from Apple | Requirement |
|---|---|---|
| **Gutter vs. margin** | Apple sets the margin (16pt) but not the gutter. Every Apple grid (App Store, Photos, Shortcuts) runs a gutter **≤** the margin. | Keep gutter ≤ 16. A gutter wider than the margin makes the row read as falling off-screen. |
| **Concentric radius math** | `ConcentricRectangle` / `.containerShape(.rect(cornerRadius:))`, iOS 26 | `inner = outer − padding`, clamped to 0. Apple now ships this as API — use the API, don't hand-compute. |
| **Nested spacing decay** | Implicit in `insetGrouped` list metrics: section inset > row inset > intra-row gap | Padding shrinks as you nest. Sibling *section* gaps go the other way (largest). |
| **Optical padding** | Apple's text line boxes carry ~0.25×point-size of phantom leading (`ascender − capHeight`, `descender` on `UIFont`) | Symmetric numeric padding reads bottom-heavy. Trim the vertical axis, or align to baseline. |
| **Icon:label ratio (stacked)** | Apple gives the *rule* — scale is relative to cap height — but no multiplier for icon-above-label. iOS tab bar ships ~25pt icon over 10pt label. | Let the icon read one clear step larger than the label; verify by squinting, not by formula. |
| **`.adaptive` over `.flexible`** | SwiftUI `LazyVGrid` semantics | `.flexible()×2` can never collapse at AX sizes. `.adaptive(minimum:)` + `@ScaledMetric` collapses to 1 column automatically. |

> **Open question flagged by Apple's own guidance.** HIG (Collections) says: *"Consider using a
> table instead of a collection for text. It's generally simpler and more efficient to view and
> digest textual information when it's displayed in a scrollable list,"* and reserves collections
> for *"image-based content."* A StreakSync game row carries an icon plus **three text fields,
> one of which is a number users compare across items** — which is the case Apple points at a
> list for. This doesn't mean the grid must go; it means **the list should be the default and
> the grid the option**, which is the inverse of nothing today (card mode is already the
> default — good) but argues against investing further in grid mode's bespoke chrome.
> See §5.3 for the Apple-first verdict.

### What StreakSync actually does

**Grid mode — measured live:**

```
screen width   402
left margin     32   ← should be 16
card width     163   ← should be 175
gutter          12
right margin    32
card height    186
margin:gutter  32:12 = 2.67:1   ← should be 16:12 = 1.33:1
```

**The 32pt margin is a bug, not a choice.** `ImprovedDashboardView.swift:223` applies
`.padding(.horizontal)` (16) to the games section, then `DashboardGamesContent.swift:100`
applies `.padding(.horizontal, 16)` *again* to the grid. Card mode
(`DashboardGamesContent.swift:42-66`) has no such inner padding — that asymmetry is the tell
that line 100 is a leftover.

**Cost:** 12pt of card width per card (163 → 175, +7.4% text width), on cards where the game
name already truncates.

**Spacing decay — both modes violate it:**

| Grid mode | Value | Decays? |
|---|---|---|
| screen margin | 32 | — |
| root section gap | 16 | ✅ |
| games-section gap | 12 | ✅ |
| grid gutter | 12 | ❌ equal, not smaller |
| **card padding** | **16** | ❌ **inverted — padding > gutter** |
| icon → name | 10 | ✅ |
| footer gap | 4 | ✅ |

When card padding exceeds the gutter, two adjacent cards' contents sit closer to each other
than to their own card edges — so the grid reads as loose floating text rather than
containers. Card mode has the same inversion (padding 12 > row gutter 8).

**Concentric radius:** card radius 16, padding 12 → inner should be **4**. Actual inner
element is a 56pt circle (r=28). Strictly this is N/A for a circle-in-squircle, but it means
the icon container is doing nothing to echo the card's corner. On iOS 26 the correct fix is
`.containerShape(.rect(cornerRadius: 16))` + `ConcentricRectangle()`.

**Card padding is not symmetric:** `GameCompactCardView` uses top **16** / bottom **14**, and
three different horizontal values in three vertical blocks (16 chip row / 12 icon block /
**0** footer — the "Never" label can run flush to the rounded card edge).

### The two card types share almost nothing

`ModernGameCard` (card mode) vs `GameCompactCardView` (grid mode): **40 of ~52 compared
properties diverge.** They share only the corner-radius token, `.continuous`, the border-width
formula, the 0.65 dim, and `.hierarchical` rendering. Different surfaces, borders, shadows,
padding, icon sizes, and **all five fonts** are independently authored.

Concrete consequences:
- Favorite button has `.minTapTarget()` **and** an accessibility label in card mode; **neither** in grid mode (`GameCompactCardView.swift:86-95`) — a WCAG 2.5.8 failure that exists in one mode only.
- Streak number is `.caption.bold.monospacedDigit()` `.primary` in card mode; `.caption2.semibold` **`.orange`, no monospacedDigit** in grid mode.
- "Never played" vs "Never" — two strings for one state.
- Card mode reflows H→V at AX sizes via `AnyLayout`; grid mode has **no AX branch at all**.
- `GameCompactCardView` finds its `Game` by linear search over `appState.games` on every render (`:19-21`); `ModernGameCard` takes it as a parameter.

### Measured misalignment in card mode

Card is 370pt wide at x=16 (margins symmetric ✅), 88pt tall, 8pt row gutter ✅.

- Favorite star: y-center **−219**. Chevron: y-center **−209**. Card center: **−209**.
  → the chevron is centered, the **star sits 10pt above it**. Two right-edge affordances on
  two different baselines. Per `vis-layout-alignment`, a near-miss like this is invisible
  alone and obvious once both are on screen.

### AX5 — the home screen breaks

Verified by screenshot at `accessibility-extra-extra-extra-large`:

1. **The onboarding card consumes the entire viewport.** "Your Games" and the whole game list
   are pushed below the fold, and "Your Games" renders *clipped behind the floating tab bar*.
   A dismissible tip occupies 100% of the primary screen.
2. **Game names truncate**: "Conn…", "Spelli…" — `ModernGameCard.swift:55-58` has
   `.lineLimit(1)` with **no `minimumScaleFactor`**. It's the primary label and the only text
   in the card with no escape hatch.
3. **Icons stay frozen** at 40/48/56pt while text triples — the icon:text ratio inverts and
   the icon becomes a tiny mark floating in whitespace.
4. Grid mode stays 2-up at AX5 (`.flexible()×2` can't collapse), giving ~135pt of text width
   for a `.subheadline` at ~28pt.

---

## 4. Cross-module findings

Seven modules audited in parallel. Full per-module tables are in the agent reports; this is
the ranked cross-cutting set.

### P0 — breaks at accessibility sizes, or unreachable controls

| # | Where | Problem |
|---|---|---|
| 1 | `Dashboard` + `Games` | Home screen unusable at AX5 (onboarding card fills viewport; names truncate; content clipped behind tab bar) |
| 2 | `GameCompactCardView.swift:94` | Favorite button: no 44pt target, no accessibility label (card mode has both) |
| 3 | `GameResultSeal.swift:69` | The score — the screen's primary number — at hardcoded 34pt |
| 4 | `GradientAvatar.swift:22` | Every friend avatar's initials frozen off a non-scaled CGFloat |
| 5 | `ShareSheetMockup.swift:94,108` | Real labels at hardcoded **9pt** |
| 6 | `SectionHeaderView.swift:32` | Shared "See All" primitive is sub-44pt → **every** "See All" in the app fails |
| 7 | `TieredAchievementDetailView.swift:104` | Tier selection via a **12pt-tall** tap target (27% of minimum) |
| 8 | `CircularProgressView.swift:17,21` | Fixed 3pt stroke in a fixed frame; ring goes hairline and `%` overflows at AX |
| 9 | `AtRiskTodaySection.swift:43` | "Play {game}" nav button ~26pt tall in a scrolling row |
| 10 | `StreakHistoryView.swift:67,90` | Both month-nav chevrons are bare ~24pt glyphs |
| 11 | `GameDetailRecentResults.swift:58,74` | Double horizontal padding → rows at 32pt inset vs header at 16pt, and the misalignment **appears/disappears based on data state** |
| 12 | `DashboardSupportingViews.swift:78` | `.lineLimit(1)` in a fixed 80pt frame — layout breaks at AX |

### P1 — reads as sloppy to a designer

**Symmetry / alignment**
- `DashboardGamesContent.swift:100` — the double-margin bug (§3).
- `RecentActivitySection` — padding applied at three levels; "Recent Activity" ends up ~32pt from its card edge while sibling cards use 16.
- `GameLeaderboardPage.swift:114` — played rows inset 20, "hasn't played" rows inset 16; the two row types don't share a leading edge.
- `StreakHistoryView.swift:160 vs 188` — two adjacent cards on one screen, `.padding(20)` vs bare `.padding()` (16).
- `SimplifiedGamesHeader.swift:111-113` — `FilterChip` leading 8 / trailing 6, asymmetric with no optical cause.
- `StreakSummaryHero.swift:122-133` — odd-count metric rows pad with `Color.clear`, so the 3-metric state shows one metric and a dead cell.
- `TieredAchievementsGridView.swift:217` — chip row inset 4pt further than the grid above and below it.

**Rhythm**
- Analytics: 10 of 12 sections use `spacing: 16`; `AtRiskTodaySection` and `AnalyticsRecommendationsSection` use 12 — a visible break mid-stack.
- Analytics: the same 2-column stat-card pattern uses radius **16** in `OverviewStatsSection` but **12** in `PersonalBestsSection` and `StreakTrendsInsightsSection`; only one of the three enforces `minHeight: 110`.
- `ImprovedDashboardView.swift:198` — an extra `.padding(.top, 8)` makes hero→guidance 24 while guidance→games is 16.
- A `10/6` chip-padding family runs through Analytics in parallel to the declared 4pt ramp.
- `ShareDiscoverySheet.swift` mixes 12 / 24 / 28 / 32 in one scroll view.

**Component divergence**
- Settings has **three** independent row implementations with icon columns of 28 / 28 / **30**, so labels don't line up across sub-screens.
- `NotificationSettingsView.swift:108` is the only settings `List` without `.listStyle(.insetGrouped)`.
- Three status-strip components in the Friends tab: two get a rounded rect + hairline stroke, `SyncStatusBanner` gets **square corners and no stroke**.
- Streaks: 1 use of `.cardStyle()` against 8 hand-rolled card surfaces in the same two files, several using the wrong radius.

**Type / numerics**
- `.monospacedDigit()` missing on essentially every number that updates or aligns in a column: dashboard streak counts (which use `.contentTransition(.numericText())` — the animation it's designed for), all five Analytics stat components, leaderboard rank/score/streak, achievement progress, Data Summary counts.
- Centered long body copy in `AccountView.swift:99,270` and `NotificationSettingsView.swift:155` (`anti-centered-body-text`).
- `StreakSummaryMetricView.swift:21` — primary vs secondary metric separated by size alone.

**Accessibility structure**
- Game cards expose their child `Text`/`Image` nodes to VoiceOver *in addition to* the button's own composed label — confirmed in the live hierarchy dump. Only 13 `.accessibilityElement(children:)` calls exist app-wide.

### P2 — hygiene
Roughly 400 raw spacing literals, 86 raw corner radii, and 71 bare `.padding()` calls to
route through tokens. Mechanical, low-risk, high-consistency-payoff.

---

## 5. The Apple-first read

Measured against HIG specifically, three things stand out beyond the spacing/type findings.

### 5.1 Depth is done with shadows, which is not the iOS idiom

> **Sourcing note.** This section is HIG-*derived*, not HIG-*verbatim*. Apple's HIG pages are
> JavaScript-rendered and could not be fetched this session (no public JSON API; web-search
> budget exhausted). The guidance below comes from the design KB's `ios-native-materials` card,
> which cites HIG Materials, plus the WWDC25 quotes in §7. **Confirm the verbatim wording before
> treating 5.1 as settled** — the measured counts underneath it are solid either way.

HIG (Materials) guides depth on iOS toward **system materials** — blur plus vibrancy that pulls
background colour forward and adapts across light, dark, and tinted appearances. The named
anti-pattern is faking depth with a flat translucent fill or shadow behind a card, because that
*blocks* the background instead of blurring it and doesn't adapt.

Apple's WWDC25 framing points the same way and *is* verbatim (§7): *"Instead of relying on
decoration, hierarchy should be expressed through layout and grouping."* A shadow on resting
content is decoration standing in for grouping.

StreakSync's census:

```
.shadow(...) on resting content   18 call sites + every one of the 19 .cardStyle() uses
system materials                  17 uses (.ultraThinMaterial 12, .regularMaterial 5)
```

So the app knows about materials, but **shadow is the default depth mechanism for cards**, and
`.cardStyle()` puts a `y: 4, radius: 10` drop shadow on resting content that never changes
elevation. Per `vis-elev-hierarchy`, elevation should mark *what's temporarily in front* —
if every card is elevated, elevation communicates nothing.

This matters for your "users never have to think about it" goal more than any single spacing
value: **a uniformly drop-shadowed card list is the single strongest signal that a screen was
built to a generic web/card idiom rather than to iOS.** Apple's own list screens (Settings,
Reminders, Health, Fitness) use inset-grouped lists with hairline separators and a grouped
background — no per-row shadow anywhere.

### 5.2 iOS 26's relevant APIs are entirely unused

The app targets iOS 26+ but:

```
glassEffect / GlassEffectContainer    0
ConcentricRectangle / containerShape  0
```

Restraint on Liquid Glass is *correct* — `ios-glass-purpose` warns against glass-on-everything,
and it's a known AI tell. But **`ConcentricRectangle` is pure upside and is being left on the
table.** It solves §3's nested-radius problem for free and permanently: set
`.containerShape(.rect(cornerRadius: 16))` on the card and the inner element's radius resolves
to `16 − padding` automatically, re-resolving whenever padding changes. Hand-computed radii
drift; this doesn't.

### 5.3 Apple's guidance points the home screen at a list

HIG, Collections:

> *"Consider using a table instead of a collection for text. It's generally simpler and more
> efficient to view and digest textual information when it's displayed in a scrollable list."*
>
> *"Generally speaking, collections are ideal for showing off image-based content."*

A game row carries an icon plus **three text fields, one of which (streak count) users compare
across items**. That's the case Apple points at a list. The good news: **card/list mode is
already the default** (`ImprovedDashboardView.swift:18`) — that's the right call and it's
already made.

The implication is about where to spend effort: grid mode is the *option*, not the default, yet
it carries an entirely bespoke chrome (`enhancedCardBackground`, 4 layers, its own borders and
shadows) and is where the accessibility defects live (no 44pt favorite target, no accessibility
label, no AX reflow, `.flexible()` columns that can't collapse). **Don't invest in making grid
mode's bespoke chrome nicer — collapse it onto the shared card treatment and fix its
accessibility.**

Related: the app uses `ScrollView` 22× vs native `List` 7×. Settings correctly uses
`List` + `.insetGrouped` (4 uses) — that's the part that feels most native today, and it's
worth asking on each hand-built `ScrollView` screen whether a `List` would do the job with
Apple's metrics for free.

---

## 6. What I'd actually do, in order

The individual findings are numerous but the *causes* are few. Fixing the causes kills most
of the list.

**Stage 1 — make the system real (unblocks everything else)**
1. **Create a typography token file.** This is the biggest structural gap: spacing is
   tokenized and ignored, type isn't tokenized at all. Define ~6 roles
   (display / title / heading / body / label / caption) each pinning a text style **+ weight
   + color**, so hierarchy is a role, not three independent decisions per call site.
2. **Extend `Spacing`** with `xxxl = 32` and `huge = 40` — 32 and 40 are already in use with
   no token, which guarantees raw literals.
3. **Add `@ScaledMetric` icon-size tokens** (20/24/32/48/56) so glyphs scale with their labels.

**Stage 2 — fix the home screen (your priority)**
4. Delete `.padding(.horizontal, 16)` at `DashboardGamesContent.swift:100`. → margins 16,
   cards 175pt, margin:gutter = 16:12.
5. Switch grid columns to `.adaptive(minimum:)` with a `@ScaledMetric` minimum (~160) so the
   grid collapses to 1 column at AX sizes instead of truncating.
6. Add `.minimumScaleFactor(0.85)` to the game name in `ModernGameCard`; give
   `GameCompactCardView`'s favorite button `.minTapTarget()` + an accessibility label.
7. Make card padding **smaller than** the gutter (12 padding / 12 gutter → drop padding to 12
   and raise gutter, or squish vertical padding to 12/8) to restore the decay ladder.
8. Align the favorite star and chevron to the same vertical center.
9. Gate the onboarding card's height, and add bottom scroll padding clearing the floating tab bar.

**Stage 3 — collapse the duplicates**
10. Make the two game cards share one chrome (`.cardStyle()`), one icon size, one font set,
    one string vocabulary. 40 divergent properties is a maintenance bomb regardless of looks.
11. One `SettingsRow` component for all five settings sub-screens.
12. One card radius for the Analytics stat-card pattern.

**Stage 4 — mechanical sweep**
13. `.monospacedDigit()` on every column/updating number.
14. Route raw literals through tokens; add a SwiftLint rule so `.padding(<number>)` and
    `.font(.system(size:))` fail review rather than accumulating.

Stage 4's lint rule is what stops this from re-accumulating — without it, the next audit
finds the same thing.

---

## 7. AI-generated-UI tells

> **Status: partially complete.** The deep research pass on this was cut short to conserve
> budget. What's below is what I can state with confidence from the design KB's anti-pattern
> cards (which are sourced to HIG and to designers writing critically about AI output) plus
> direct observation of the running app. The items marked ⚠ need a verdict I couldn't finish.

### What StreakSync gets right (genuinely not AI-generic)
- **No indigo/violet palette**, no Inter-everywhere, no hero + 3 cards, no bento grid, no
  glassmorphism (0 `glassEffect` uses). The four loudest tells are all absent.
- **Colour is restrained and role-based** — `.secondary` 153 / `.primary` 32 / `.tertiary` 29,
  hue used sparingly. `anti-rainbow-palette` does not apply at the app level.
- **No emoji as section icons** — SF Symbols throughout.

### Confirmed tells present in the app

**1. The leading coloured strip on each game card — verdict: remove it.**
`ModernGameCard.swift:152-166` draws a 4pt vertical accent bar down the leading edge of every
card, hue per game, light mode only.

I could not finish confirming "left accent bar" as a *formally catalogued* AI tell — that
specific claim stays unverified. **But the stronger objection is Apple's own, in Apple's own
words**, and it doesn't depend on the AI-tell framing at all:

> *"Instead of relying on decoration, hierarchy should be expressed through layout and
> grouping."*
> — WWDC25 session 356, *Get to know the new design system*

> *"Use tinting to bring emphasis to primary elements and actions in the UI… when every
> element is tinted, nothing stands out, and it can be confusing. **If you want to imbue color
> into your app, do it in the content layer instead.**"*
> — WWDC25 session 219, *Meet Liquid Glass*

**The rule Apple's own apps follow, without exception:** exactly **one authored hue per app**,
spent only on interactivity (App Store blue, Music red/pink, Podcasts purple). Item identity
comes from the item's **own artwork**, or from nothing at all — type scale, whitespace, and
grouping. A tinted glyph is used for **categories** (a fixed, small, navigational set), never
for **items** (an unbounded, data-driven set). Where colour appears to vary per item
(Music/Podcasts Now Playing, App Store Today), it is *extracted from* the content, never
assigned from a palette.

StreakSync assigns a hue per game — a data-driven item set — which is precisely the case
Apple's guidance rules out. Supporting observations:
- **Apple ships nothing shaped like it.** App Store, Music, and Podcasts rows carry a
  rounded-square artwork thumbnail and no per-row chroma; Music and Podcasts library
  *categories* use single-hue tinted glyphs (all red, all purple), not one hue per row.
- It is **light-mode only**, so this identity encoding silently disappears in dark mode.
- It is **light-mode only**, so per-game identity silently disappears in dark mode — identity
  encoding that only works in one appearance isn't identity encoding.
- At AX5 (screenshotted) it becomes a full-height saturated bar and turns into the most
  visually dominant element on every card, ahead of the game name.
- Grid mode doesn't have it at all — so the app already contradicts itself about whether games
  need an edge stripe.
- **Recommendation: drop the stripe; move game identity into the icon container's tint**, which
  is where iOS users already read it, works in both appearances, and is what grid mode does.

**2. Uniform drop shadows on resting content.** See §5.1 — this is the strongest non-native
signal in the app, and it's a card-idiom import rather than an iOS one.

**3. Icon-in-a-tinted-circle on every single row.** Visible in the screenshots: 15 identical
grey circles down the list. This *is* an Apple pattern (Settings uses rounded squares), so it's
not wrong — but at 0.65 opacity with grey fills for unplayed games, all 15 read as one
undifferentiated texture. The tell isn't the container, it's that it carries no information.

**4. Gradient tint on grid card backgrounds** (`GameCompactCardView.swift:202-212`,
`gameColor.opacity(0.04)` → clear). Per `anti-ai-slop-gradients`: if removing the gradient
changes nothing about legibility or meaning, remove it. At 4% opacity it changes nothing —
it's decoration. Confirmed visually: grid cards read as faintly, inexplicably tinted.

**5. The "stat triad" — not a tell, but it has no focal point.** `StreakSummaryHero` and
`OverviewStatsSection` use rows of equal-weight metric tiles (icon + big number + small label).
A stats summary is entirely correct for a streak tracker — Apple's own Fitness and Health lead
with exactly this kind of content. The problem isn't the pattern, it's that the tiles are
*equal*: `StreakSummaryMetricView.swift:21` separates the primary from the secondary metric by
size alone (`.title.bold()` vs `.title2.bold()`, both `.primary`). Per `vis-layout-balance`,
everything weighted equally means nothing leads. Give the hero metric colour or scale so one
number wins the screen — Apple's Fitness ring works because there is unambiguously one
protagonist.

### The honest summary
StreakSync is **not** a generic-AI-looking app. It avoids every one of the loud tells. What it
has instead is a subtler version of the same underlying problem: **decoration that isn't
carrying information** — an edge stripe that only works in light mode, a 4% gradient, a shadow
on everything, and 15 identical grey circles. Each is individually defensible; together they're
what `fnd-design-with-intent` calls the absence of a decision.

---

## 8. Method

- Static: 7 parallel module audits against a shared rubric derived from the design KB
  (`vis-space-scale`, `vis-space-proximity`, `vis-layout-alignment`, `vis-typo-scale`,
  `vis-typo-weight-hierarchy`, `ios-hig-layout`, `ios-hig-dynamic-type`, `ios-hig-target-44`,
  `anti-inconsistent-spacing`, `anti-too-many-fonts`, `anti-rainbow-palette`).
- Mechanical: grep census of every spacing, radius, font, and frame literal (numbers in §1
  are counts, not samples).
- Runtime: built and ran on iPhone 17 Pro (iOS 27); measured the live accessibility hierarchy
  via AXe at default size, and screenshotted at AX5.
- Research: Apple HIG as the sole authority; where Apple publishes no value, the answer is
  derived from Apple's own APIs (`ConcentricRectangle`, `systemMinimumLayoutMargins`,
  `insetGrouped` metrics) and shipping Apple apps rather than another platform's system (§3).
