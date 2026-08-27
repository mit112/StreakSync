//
//  GameShareFormatFixtures.swift
//  StreakSyncTests
//
//  Real-world share text samples collected from public sources (2025–2026).
//  Sources: wordlebot.gg/docs, c.r74n.com/wordle, LinkedIn game posts/comments,
//  NYT help docs, and in-app share patterns documented by players.
//

@testable import StreakSync
import Foundation

struct GameShareFormatFixture: Sendable {
    let game: Game
    let label: String
    let shareText: String
    let source: String
    /// Whether the current parser is expected to accept this format today.
    let shouldParse: Bool
}

enum GameShareFormatFixtures {
    static let all: [GameShareFormatFixture] = [
        // MARK: - Wordle (wordlebot.gg, c.r74n.com)
        GameShareFormatFixture(
            game: .wordle,
            label: "standard_with_grid",
            shareText: """
            Wordle 1,406 4/6*

            ⬛⬛⬛⬛🟩
            ⬛⬛⬛🟨🟩
            ⬛🟨⬛⬛🟩
            🟩🟩🟩🟩🟩
            """,
            source: "wordlebot.gg/docs",
            shouldParse: true
        ),
        GameShareFormatFixture(
            game: .wordle,
            label: "hard_mode_asterisk",
            shareText: "Wordle 1,063 4/6*",
            source: "c.r74n.com/wordle",
            shouldParse: true
        ),
        GameShareFormatFixture(
            game: .wordle,
            label: "failure_x",
            shareText: "Wordle 1,492 X/6",
            source: "in-app",
            shouldParse: true
        ),

        // MARK: - Quordle (wordlebot.gg — note leading mood emoji, no space)
        GameShareFormatFixture(
            game: .quordle,
            label: "daily_with_leading_emoji",
            shareText: """
            🙂 Daily Quordle 1576
            2️⃣8️⃣
            7️⃣9️⃣
            m-w.com/games/quordle/
            """,
            source: "user report + wordlebot.gg",
            shouldParse: true
        ),
        GameShareFormatFixture(
            game: .quordle,
            label: "daily_with_failure_row",
            shareText: """
            🙂Daily Quordle 1190
            🟥8️⃣
            4️⃣5️⃣
            m-w.com/games/quordle/
            """,
            source: "wordlebot.gg/docs",
            shouldParse: true
        ),
        GameShareFormatFixture(
            game: .quordle,
            label: "weekly_challenge",
            shareText: """
            Weekly Quordle Challenge 143
            7️⃣4️⃣
            5️⃣6️⃣
            m-w.com/games/quordle/
            """,
            source: "wordlebot.gg/docs",
            shouldParse: true
        ),

        // MARK: - Connections (wordlebot.gg — full paste including mistake rows)
        GameShareFormatFixture(
            game: .connections,
            label: "full_grid_with_mistakes",
            shareText: """
            Connections
            Puzzle #687
            🟩🟦🟩🟩
            🟪🟪🟪🟪
            🟦🟦🟦🟦
            🟨🟨🟨🟨
            🟩🟩🟩🟩
            """,
            source: "wordlebot.gg/docs",
            shouldParse: true
        ),
        GameShareFormatFixture(
            game: .connections,
            label: "perfect_four_rows",
            shareText: """
            Connections
            Puzzle #603
            🟩🟩🟩🟩
            🟨🟨🟨🟨
            🟪🟪🟪🟪
            🟦🟦🟦🟦
            """,
            source: "c.r74n.com/wordle",
            shouldParse: true
        ),

        // MARK: - Spelling Bee
        GameShareFormatFixture(
            game: .spellingBee,
            label: "score_words_rank",
            shareText: """
            Spelling Bee
            Score: 150
            Words: 25
            Rank: Genius
            """,
            source: "in-app (documented)",
            shouldParse: true
        ),
        GameShareFormatFixture(
            game: .spellingBee,
            label: "nyt_share_sentence",
            shareText: "Spelling Bee - I found 42 words, including the pangram!",
            source: "NYT Games app share (GameDetectionTests)",
            shouldParse: true
        ),
        GameShareFormatFixture(
            game: .spellingBee,
            label: "nyt_structured_share",
            shareText: """
            NYT Spelling Bee May 19, 2026
            Rank: Genius
            Score: 150
            Words found: 25
            Pangrams: 1
            """,
            source: "canonical spec",
            shouldParse: true
        ),

        // MARK: - Mini Crossword
        GameShareFormatFixture(
            game: .miniCrossword,
            label: "completed_in_legacy",
            shareText: "Mini Crossword\nCompleted in 2:30",
            source: "in-app (legacy)",
            shouldParse: true
        ),
        GameShareFormatFixture(
            game: .miniCrossword,
            label: "nyt_app_solved_sentence",
            shareText: """
            I solved the 4/28/2025 New York Times
            Mini Crossword in 0:22!
            """,
            source: "wordlebot.gg/docs (NYT mobile app)",
            shouldParse: true
        ),

        // MARK: - Strands
        GameShareFormatFixture(
            game: .strands,
            label: "with_theme_and_spangram",
            // Real NYT shares wrap the theme in curly quotes (U+201C/U+201D), not
            // straight ASCII quotes — using ASCII here would hide a parser mismatch.
            shareText: "Strands #350\n\u{201C}Knot your average puzzle\u{201D}\n🔵🔵🔵🟡\n🔵🔵🔵",
            source: "GameDetectionTests + NYT help",
            shouldParse: true
        ),
        GameShareFormatFixture(
            game: .strands,
            label: "with_hints",
            shareText: """
            Strands #580
            "Bring it home"
            💡🔵🔵💡
            🔵🟡🔵🔵
            🔵
            """,
            source: "in-app",
            shouldParse: true
        ),

        // MARK: - Nerdle
        GameShareFormatFixture(
            game: .nerdle,
            label: "header_only",
            shareText: "nerdlegame 728 3/6",
            source: "nerdlegame.com",
            shouldParse: true
        ),
        GameShareFormatFixture(
            game: .nerdle,
            label: "nerdle_branded_header",
            shareText: "Nerdle 728 3/6",
            source: "canonical spec",
            shouldParse: true
        ),
        GameShareFormatFixture(
            game: .nerdle,
            label: "with_color_grid",
            shareText: """
            nerdlegame 728 3/6

            🟪⬛🟪🟪⬛🟪⬛⬛
            🟪🟩🟩🟩⬛🟩⬛🟪
            🟩🟩🟩🟩🟩🟩🟩🟩
            """,
            source: "ManualEntryView example",
            shouldParse: true
        ),

        // MARK: - Pips
        GameShareFormatFixture(
            game: .pips,
            label: "easy_standard",
            shareText: "Pips #46 Easy\n1:03",
            source: "in-app (GameResultParserTests)",
            shouldParse: true
        ),
        GameShareFormatFixture(
            game: .pips,
            label: "easy_with_difficulty_emoji",
            shareText: """
            Pips #46 Easy 🟢
            1:03
            """,
            source: "GroupedGameResultRow preview — emoji on header line",
            shouldParse: true
        ),
        GameShareFormatFixture(
            game: .pips,
            label: "easy_on_separate_line",
            shareText: "Pips #120\nEasy 🟢 0:22",
            source: "GameDetectionTests (NYT app layout)",
            shouldParse: true
        ),
        GameShareFormatFixture(
            game: .pips,
            label: "hard",
            shareText: """
            Pips #46 Hard
            2:59
            """,
            source: "in-app",
            shouldParse: true
        ),

        // MARK: - Octordle (c.r74n.com)
        GameShareFormatFixture(
            game: .octordle,
            label: "full_with_clock_emojis",
            shareText: """
            Daily Octordle #845
            8️⃣4️⃣
            5️⃣🔟
            9️⃣6️⃣
            🕛7️⃣
            Score: 61
            """,
            source: "c.r74n.com/wordle",
            shouldParse: true
        ),

        // MARK: - LinkedIn Queens
        GameShareFormatFixture(
            game: .linkedinQueens,
            label: "in_app_multiline",
            shareText: """
            Queens #522
            1:11 👑
            lnkd.in/queens.
            """,
            source: "in-app share",
            shouldParse: true
        ),
        GameShareFormatFixture(
            game: .linkedinQueens,
            label: "comment_with_first_crowns",
            shareText: """
            Queens #386 | 0:11 First 👑s: 🟨 🟩 ⬜
            lnkd.in/queens.
            """,
            source: "LinkedIn Queens #386 comments",
            shouldParse: true
        ),
        GameShareFormatFixture(
            game: .linkedinQueens,
            label: "no_hash_with_time_label",
            shareText: """
            Queens 522
            Time: 1:11
            👑👑👑👑👑
            """,
            source: "canonical spec",
            shouldParse: true
        ),

        // MARK: - LinkedIn Tango
        GameShareFormatFixture(
            game: .linkedinTango,
            label: "in_app_multiline",
            shareText: """
            Tango #362
            1:10 🌗
            lnkd.in/tango.
            """,
            source: "in-app share",
            shouldParse: true
        ),
        GameShareFormatFixture(
            game: .linkedinTango,
            label: "comment_flawless",
            shareText: "Tango #293 | 0:47 and flawless\nlnkd.in/tango.",
            source: "LinkedIn Tango #293 comments",
            shouldParse: true
        ),

        // MARK: - LinkedIn Crossclimb
        GameShareFormatFixture(
            game: .linkedinCrossclimb,
            label: "in_app_multiline",
            shareText: """
            Crossclimb #522
            2:08 🪜
            🏅 I'm on a 94-day win streak!
            lnkd.in/crossclimb.
            """,
            source: "in-app share",
            shouldParse: true
        ),
        GameShareFormatFixture(
            game: .linkedinCrossclimb,
            label: "comment_with_fill_order",
            shareText: """
            Crossclimb #398 | 0:40 and flawless
            Fill order: 1️⃣ 2️⃣ 3️⃣ 4️⃣ 5️⃣ ⬆️ ⬇️ 🪜
            lnkd.in/crossclimb.
            """,
            source: "LinkedIn Crossclimb #398 comments",
            shouldParse: true
        ),

        // MARK: - LinkedIn Pinpoint
        GameShareFormatFixture(
            game: .linkedinPinpoint,
            label: "emoji_grid",
            shareText: """
            Pinpoint #542
            🤔 📌 ⬜ ⬜ ⬜ (2/5)
            🏅 I'm in the Top 25% of my connections today!
            lnkd.in/pinpoint.
            """,
            source: "in-app share",
            shouldParse: true
        ),
        GameShareFormatFixture(
            game: .linkedinPinpoint,
            label: "original_percent_match_multiline",
            shareText: """
            Pinpoint #522 | 5 guesses
            1️⃣  | 1% match
            2️⃣  | 5% match
            3️⃣  | 82% match
            4️⃣  | 28% match
            5️⃣  | 100% match 📌
            lnkd.in/pinpoint.
            """,
            source: "in-app share (original)",
            shouldParse: true
        ),
        GameShareFormatFixture(
            game: .linkedinPinpoint,
            label: "comment_inline_matches",
            shareText: """
            Pinpoint #460 | 5 guesses
            1️⃣ | 5% match 2️⃣ | 76% match 3️⃣ | 83% match 4️⃣ | 53% match 5️⃣ | 100% match 📌🏅I'm on a 145-day win streak!
            lnkd.in/pinpoint.
            """,
            source: "LinkedIn Pinpoint #460 comments",
            shouldParse: true
        ),

        // MARK: - LinkedIn Zip
        GameShareFormatFixture(
            game: .linkedinZip,
            label: "in_app_multiline",
            shareText: """
            Zip #201
            0:23 🏁
            With 1 backtrack 🛑
            lnkd.in/zip.
            """,
            source: "in-app share",
            shouldParse: true
        ),
        GameShareFormatFixture(
            game: .linkedinZip,
            label: "comment_single_line",
            shareText: "Zip #335 | 0:19 🏁 With 4 backtracks 🛑 lnkd.in/zip.",
            source: "LinkedIn Zip #335 comments",
            shouldParse: true
        ),
        GameShareFormatFixture(
            game: .linkedinZip,
            label: "comment_flawless_no_backtracks",
            shareText: "Zip #335 | 0:09 and flawless 🏁 With no backtracks 🟢 lnkd.in/zip.",
            source: "LinkedIn Zip #335 comments",
            shouldParse: true
        ),

        // MARK: - LinkedIn Mini Sudoku
        GameShareFormatFixture(
            game: .linkedinMiniSudoku,
            label: "legacy_puzzle_completed",
            shareText: "Mini Sudoku puzzle #45 completed",
            source: "in-app (legacy)",
            shouldParse: true
        ),
        GameShareFormatFixture(
            game: .linkedinMiniSudoku,
            label: "current_share_with_time",
            shareText: """
            Mini Sudoku #142 | 0:39 and flawless ✏️
            🏅 I'm smarter than 95% of CEOs today!
            lnkd.in/minisudoku.
            """,
            source: "LinkedIn Mini Sudoku #142 comments",
            shouldParse: true
        ),
        GameShareFormatFixture(
            game: .linkedinMiniSudoku,
            label: "dated_share_block",
            shareText: """
            Mini Sudoku - May 19, 2026
            Score: 95
            Time: 1:23
            Perfect Game
            """,
            source: "canonical spec",
            shouldParse: true
        )
    ]
}
