//
//  GameDefinitions+Extended.swift
//  StreakSync
//
//  Extended game catalog: wordle variants and additional word games
//  beyond the core built-in set.
//

import Foundation
import UIKit

// MARK: - Wordle Variants & Additional Word Games
extension Game {
    static let letterboxed = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-446655440300"),
        name: "letterboxed",
        displayName: "Letter Boxed",
        url: URL(staticString: "https://www.nytimes.com/puzzles/letter-boxed"),
        category: .word,
        iconSystemName: "square.on.square",
        backgroundColor: CodableColor(UIColor(red: 1.0, green: 0.588, blue: 0.0, alpha: 1.0)), // #FF9600
        isPopular: false
    )

    static let waffle = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-446655440301"),
        name: "waffle",
        displayName: "Waffle",
        url: URL(staticString: "https://wafflegame.net"),
        category: .word,
        iconSystemName: "square.grid.2x2",
        backgroundColor: CodableColor(.systemBrown),
        isPopular: false
    )

    // Math Games
    static let mathle = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-446655440008"),
        name: "mathle",
        displayName: "Mathle",
        url: URL(staticString: "https://www.mathle.com"),
        category: .math,
        iconSystemName: "function",
        backgroundColor: CodableColor(.systemIndigo),
        isPopular: false
    )

    static let numberle = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-446655440009"),
        name: "numberle",
        displayName: "Numberle",
        url: URL(staticString: "https://numberle.com"),
        category: .math,
        iconSystemName: "number.square",
        backgroundColor: CodableColor(.systemCyan),
        isPopular: false
    )

    // Geography Games
    static let worldle = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-44665544000A"),
        name: "worldle",
        displayName: "Worldle",
        url: URL(staticString: "https://worldle.teuteuf.fr"),
        category: .geography,
        iconSystemName: "globe",
        backgroundColor: CodableColor(.systemGreen),
        isPopular: true
    )

    static let globle = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-44665544000B"),
        name: "globle",
        displayName: "Globle",
        url: URL(staticString: "https://globle-game.com"),
        category: .geography,
        iconSystemName: "globe.americas",
        backgroundColor: CodableColor(.systemTeal),
        isPopular: false
    )

    // Trivia Games
    static let contexto = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-44665544000C"),
        name: "contexto",
        displayName: "Contexto",
        url: URL(staticString: "https://contexto.me"),
        category: .trivia,
        iconSystemName: "lightbulb",
        backgroundColor: CodableColor(.systemRed),
        isPopular: true
    )

    static let framed = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-44665544000D"),
        name: "framed",
        displayName: "Framed",
        url: URL(staticString: "https://framed.wtf"),
        category: .trivia,
        iconSystemName: "film",
        backgroundColor: CodableColor(.systemPink),
        isPopular: false
    )

    // Puzzle Games
    static let crosswordle = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-44665544000E"),
        name: "crosswordle",
        displayName: "Crosswordle",
        url: URL(staticString: "https://crosswordle.serializer.ca"),
        category: .puzzle,
        iconSystemName: "square.grid.3x3.fill",
        backgroundColor: CodableColor(.systemGray),
        isPopular: false
    )

    static let extendedMiniCrossword = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-44665544000F"),
        name: "mini_crossword",
        displayName: "Mini Crossword",
        url: URL(staticString: "https://www.nytimes.com/crosswords/game/mini"),
        category: .puzzle,
        iconSystemName: "square.grid.2x2",
        backgroundColor: CodableColor(.systemBlue),
        isPopular: true
    )

    static let sudoku = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-446655440010"),
        name: "sudoku",
        displayName: "Sudoku",
        url: URL(staticString: "https://www.nytimes.com/puzzles/sudoku"),
        category: .puzzle,
        iconSystemName: "square.grid.3x3.topleft.filled",
        backgroundColor: CodableColor(.systemPurple),
        isPopular: true
    )

    // Music Games
    static let lyricle = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-446655440011"),
        name: "lyricle",
        displayName: "Lyricle",
        url: URL(staticString: "https://www.lyricle.app"),
        category: .music,
        iconSystemName: "music.note.list",
        backgroundColor: CodableColor(.systemPink),
        isPopular: false
    )

    // More Word Games
    static let absurdle = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-446655440012"),
        name: "absurdle",
        displayName: "Absurdle",
        url: URL(staticString: "https://absurdle.online"),
        category: .word,
        iconSystemName: "questionmark.square",
        backgroundColor: CodableColor(.systemRed),
        isPopular: false
    )

    static let semantle = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-446655440013"),
        name: "semantle",
        displayName: "Semantle",
        url: URL(staticString: "https://semantle.com"),
        category: .word,
        iconSystemName: "brain",
        backgroundColor: CodableColor(.systemIndigo),
        isPopular: false
    )

    // MARK: - More Word Games (21-30)

    static let dordle = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-446655440015"),
        name: "dordle",
        displayName: "Dordle",
        url: URL(staticString: "https://zaratustra.itch.io/dordle"),
        category: .word,
        iconSystemName: "square.on.square",
        backgroundColor: CodableColor(.systemOrange),
        isPopular: false
    )

    static let sedecordle = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-446655440016"),
        name: "sedecordle",
        displayName: "Sedecordle",
        url: URL(staticString: "https://sedecordle.com"),
        category: .word,
        iconSystemName: "square.grid.3x3.square",
        backgroundColor: CodableColor(.systemRed),
        isPopular: false
    )

    static let kilordle = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-446655440017"),
        name: "kilordle",
        displayName: "Kilordle",
        url: URL(staticString: "https://kilordle.com"),
        category: .word,
        iconSystemName: "infinity",
        backgroundColor: CodableColor(.systemIndigo),
        isPopular: false
    )

    static let antiwordle = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-446655440018"),
        name: "antiwordle",
        displayName: "Antiwordle",
        url: URL(staticString: "https://antiwordle.com"),
        category: .word,
        iconSystemName: "arrow.uturn.backward.square",
        backgroundColor: CodableColor(.systemPink),
        isPopular: false
    )

    static let wordscapes = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-446655440019"),
        name: "wordscapes",
        displayName: "Wordscapes",
        url: URL(staticString: "https://wordscapes.com"),
        category: .word,
        iconSystemName: "leaf",
        backgroundColor: CodableColor(.systemGreen),
        isPopular: false
    )

    static let wordhurdle = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-44665544001A"),
        name: "wordhurdle",
        displayName: "Word Hurdle",
        url: URL(staticString: "https://wordhurdle.com"),
        category: .word,
        iconSystemName: "figure.run.square.stack",
        backgroundColor: CodableColor(.systemBlue),
        isPopular: false
    )

    static let xordle = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-44665544001B"),
        name: "xordle",
        displayName: "Xordle",
        url: URL(staticString: "https://xordle.xyz"),
        category: .word,
        iconSystemName: "xmark.square",
        backgroundColor: CodableColor(.systemGray),
        isPopular: false
    )

    static let squareword = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-44665544001C"),
        name: "squareword",
        displayName: "Squareword",
        url: URL(staticString: "https://squareword.org"),
        category: .word,
        iconSystemName: "square.text.square",
        backgroundColor: CodableColor(.systemMint),
        isPopular: false
    )

    static let phrazle = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-44665544001D"),
        name: "phrazle",
        displayName: "Phrazle",
        url: URL(staticString: "https://phrazle.com"),
        category: .word,
        iconSystemName: "text.quote",
        backgroundColor: CodableColor(.systemBrown),
        isPopular: false
    )
}
