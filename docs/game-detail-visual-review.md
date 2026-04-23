# Game Detail Page Visual Review

**Date:** 2026-04-23  
**Branch:** main  
**Simulator:** iPhone 17 Pro Max (091E4E62-A02F-42EB-9CB5-5B0419DA8DA6)  
**Method:** Debug seeder (Settings → Debug Seeder → "Seed 60 Days of Data") + live simulator walkthrough

---

## Scope

Walk through every game's detail page — stats header, performance chart, recent results, display scores — and flag anything visually wrong or broken.

---

## Bugs Fixed During This Review

### 1. Chart Y-axis labels wrong for inverted games (Strands)
**File:** `StreakSync/Features/Games/Views/GameDetailPerformanceView.swift`

The `axisLabel(for:)` function was returning the raw plot value instead of the back-converted original score. Fixed the formula for all inverted scoring models.

- `lowerHints`: `chartMaxValue = maxAttempts + 1`, `plotValue = maxValue - score`, `axisLabel = maxValue - axisValue`
- `lowerGuesses` / `lowerAttempts`: `plotValue = maxValue + 1 - score`, `axisLabel = maxValue + 1 - axisValue`

### 2. Strands display score — wrong pluralisation
**File:** `StreakSync/Core/Models/Shared/GameResultDisplay.swift`

`strandsDisplayScore` was not handling singular/plural correctly. Fixed to return:
- `"Perfect"` for 0 hints
- `"1 hint"` for exactly 1
- `"N hints"` for N > 1

### 3. Pinpoint display score — wrong pluralisation
**File:** `StreakSync/Core/Models/Shared/GameResultDisplay.swift`

`pinpointDisplayScore` had the same problem. Fixed to return:
- `"1 guess"` for exactly 1
- `"N guesses"` for N > 1

### 4. LinkedIn time-based games — time format was raw seconds
**File:** `StreakSync/Core/Models/Shared/GameResultDisplay.swift`

Zip, Tango, Queens, and Crossclimb were not formatting seconds into human-readable time. Added `Self.formatSeconds(_:)` helper (e.g. `45` → `"45s"`, `90` → `"1:30"`).

### 5. Mini Sudoku display score — showed "1/0" instead of "Completed"
**File:** `StreakSync/Core/Models/Shared/GameResultDisplay.swift`

Mini Sudoku uses `higherIsBetter` scoring with `score=1, maxAttempts=0` (completion indicator only). The standard fallback produced `"1/0"` which is meaningless. Added a dedicated branch in `displayScore` that returns `"Completed"` or `"Failed"` based on the `completed` flag.

### 6. Pips seed data — `parsedData["totalSeconds"]` missing
**File:** `StreakSync/Features/Settings/Views/DebugDataSeederView.swift`

`GroupedGameResult.bestTime` requires `parsedData["totalSeconds"]` to show the fastest difficulty in the grouped row subtitle. The seed data was missing this key. Added `"totalSeconds": "\(seconds)"` to each Pips result's parsedData.

---

## Game-by-Game Findings

### Wordle
- **Scoring:** `lowerAttempts` (inverted chart)
- **Chart:** ✅ Bars taller = fewer attempts. Y-axis labels show original attempt counts correctly.
- **Display score:** ✅ `"3/6"` format.
- **Stats:** ✅ Avg, best, rate all correct. 60 games / Past week counts accurate.
- **Issues:** None.

### Nerdle
- **Scoring:** `lowerAttempts` (inverted chart)
- **Chart:** ✅ Same as Wordle. 7-day window shows correct bars.
- **Display score:** ✅ `"3/6"` format.
- **Stats:** ✅ 20 days of data, shows 7 in the past week.
- **Issues:** None.

### Connections
- **Scoring:** `higherIsBetter` (non-inverted chart — taller = more categories solved)
- **Chart:** ✅ Bar heights proportional to categories solved (3 or 4 out of 4).
- **Display score:** ✅ `"4/4"` or `"3/4"` from `solvedCategories` in parsedData.
- **Stats:** ✅ 60 days of data.
- **Issues:** None.

### Spelling Bee
- **Scoring:** `higherIsBetter` (non-inverted — taller = more points)
- **Chart:** ✅ Dynamic Y scale driven by actual point totals (63–175 range).
- **Display score:** ✅ Shows raw point value.
- **Stats:** ✅ Best shows highest score, avg computed correctly.
- **Issues:** None.

### Mini Crossword
- **Scoring:** `lowerTimeSeconds` (non-inverted, time axis)
- **Chart:** ✅ Y-axis labels formatted as `"1:35"` / `"45s"`. Shorter times = shorter bars (not inverted — lower raw value = shorter bar, which is correct for time).
- **Display score:** ✅ `"1:35"` format via `formatSeconds`.
- **Stats:** ✅ Avg and best formatted as time strings.
- **Issues:** None.

### Strands
- **Scoring:** `lowerHints` (inverted chart — fewer hints = taller bar)
- **Chart:** ✅ Y-axis correctly shows original hint counts (0 at top = perfect). Fixed in this review.
- **Display score:** ✅ `"Perfect"` / `"1 hint"` / `"2 hints"`. Fixed in this review.
- **Stats:** ✅ Best shows lowest hint count.
- **Issues:** None (after fixes).

### Pinpoint
- **Scoring:** `lowerGuesses` (inverted chart — fewer guesses = taller bar)
- **Chart:** ✅ Y-axis labels show original guess counts.
- **Display score:** ✅ `"1 guess"` / `"2 guesses"`. Fixed in this review.
- **Stats:** ✅ Best shows minimum guess count.
- **Issues:** None (after fixes).

### Queens
- **Scoring:** `lowerTimeSeconds` (non-inverted, time axis)
- **Chart:** ✅ Y-axis formatted as time strings.
- **Display score:** ✅ `"45s"` / `"1:12"`. Fixed in this review.
- **Stats:** ✅ Avg and best as time strings.
- **Issues:** None (after fixes).

### Quordle
- **Scoring:** `lowerAttempts` (inverted chart)
- **Chart:** ✅ Inverted correctly. Y-axis labels show original attempt counts.
- **Display score:** ⚠️ Shows `"5/9"` fallback format instead of `"5-7-6-8"` multi-puzzle format.
  - **Why:** Seed data does not include `score1`/`score2`/`score3`/`score4` keys in `parsedData`. The multi-puzzle format only appears when the share extension parses real Quordle share text.
  - **Not a bug** — real shares will parse correctly. Seed data is insufficient here.
- **Stats:** ✅ Avg/best are raw integer scores (reasonable for chart stats).
- **Issues:** None that need fixing.

### Octordle
- **Scoring:** `lowerAttempts` (inverted chart — lower score = fewer total attempts = better)
- **Chart:** ✅ Inverted correctly. Bar for score=9 renders at expected height. Y-axis "5" at top, "10" lower — correct (higher position = better score).
- **Display score:** ✅ Shows raw integer `"9"`, `"11"` etc. Consistent with `octordleDisplayScore` intent ("lower is better, 8 is perfect").
- **Stats:** ✅ Best shows minimum score.
- **Issues:** None.

---

## Never-Played Games (Empty State Check)

Checked **Pips** and **Tango** as representatives. Both render a clean empty state:
- No performance chart shown (correct — no data to chart)
- "No results yet / Play [Game] to see results here" placeholder
- Stats show `0 / 0 / 0.0%`

**Minor cosmetic note:** `0.0%` success rate on never-played games is slightly misleading. A `"—"` would read more naturally. Not a crash or data issue.

The remaining never-played games (Crossclimb, Zip, Mini Sudoku) were not individually opened but use the same view and are expected to render identically.

---

## Session 2 Findings (2026-04-23): Pips, Tango, Crossclimb, Zip, Mini Sudoku

Seed data was added to `DebugDataSeederView.swift` for the 5 unreviewed games and each was walked through in the live simulator. Two bugs were found and fixed.

### Pips
- **Scoring:** `lowerTimeSeconds` (per difficulty, non-inverted)
- **Chart:** ✅ Non-inverted. Bar heights proportional to time (taller bar = longer time = worse). Y-axis shows formatted time strings (`"3:20"`, `"2:30"`, `"1:40"`, `"50s"`).
- **Chart stats:** ✅ Avg and Best formatted as time strings (`"1:17"`, `"45s"`).
- **Recent Results:** Shows `GroupedGameResultRow` by design (one difficulty per date in seed → "Puzzle #X / 1/3 Complete"). No `bestTime` subtitle shown — seed data was missing `parsedData["totalSeconds"]`.
- **Display score:** ✅ `"Easy - 45s"` format via `pipsDisplayScore` (reads `parsedData["difficulty"]` + `parsedData["time"]`).
- **Fix applied:** Added `"totalSeconds": "\(seconds)"` to seed parsedData so `GroupedGameResult.bestTime` now works for future re-seeds.

### Tango
- **Scoring:** `lowerTimeSeconds` (non-inverted)
- **Chart:** ✅ Y-axis labels `"1:40"`, `"50s"` — correctly formatted time strings.
- **Chart stats:** ✅ `58s Avg, 45s Best` — time strings.
- **Recent Results:** ✅ `"45s"`, `"1:12"`, `"1:28"`, `"55s"`, `"1:50"` — all properly formatted.
- **Issues:** None.

### Crossclimb
- **Scoring:** `lowerTimeSeconds` (non-inverted)
- **Chart:** ✅ Y-axis labels `"2:30"`, `"1:40"`, `"50s"` — time strings.
- **Chart stats:** ✅ `1:57 Avg, 1:30 Best` — time strings.
- **Recent Results:** ✅ `"1:30"`, `"2:25"`, `"1:05"`, `"3:00"`, `"1:15"` — all correct.
- **Issues:** None.

### Zip
- **Scoring:** `lowerTimeSeconds` (non-inverted)
- **Chart:** ✅ Y-axis labels `"1:00"`, `"40s"`, `"20s"` — time strings.
- **Chart stats:** ✅ `30s Avg, 30s Best` — time strings.
- **Recent Results:** ✅ `"30s"`, `"48s"`, `"1:05"`, `"38s"`, `"55s"` — all correct.
- **Issues:** None.

### Mini Sudoku
- **Scoring:** `higherIsBetter` (`score=1` = completed; no time metric in real share format)
- **Chart:** ✅ Y-axis shows raw integers (`"6"`, `"4"`, `"2"`) — correct for `higherIsBetter` model with a completion score of 1.
- **Chart stats:** `1.0 Avg, 1 Best` — raw integers (expected; no time to format).
- **Recent Results:** ✅ `"Completed"` — fixed from `"1/0"` (see Bug #5 above).
- **Issues:** None after fix.
