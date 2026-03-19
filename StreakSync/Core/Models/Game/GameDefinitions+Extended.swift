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
        id: Game.safeUUID("550e8400-e29b-41d4-a716-446655440300"),
        name: "letterboxed",
        displayName: "Letter Boxed",
        url: URL(string: "https://www.nytimes.com/puzzles/letter-boxed")!,
        category: .word,
        resultPattern: #"Letter Boxed.*?in \d+ words"#,
        iconSystemName: "square.on.square",
        backgroundColor: CodableColor(UIColor(red: 1.0, green: 0.588, blue: 0.0, alpha: 1.0)), // #FF9600
        isPopular: false,
        isCustom: false
    )

    static let waffle = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-446655440301"),
        name: "waffle",
        displayName: "Waffle",
        url: URL(string: "https://wafflegame.net")!,
        category: .word,
        resultPattern: #"#waffle\d+ \d+/5"#,
        iconSystemName: "square.grid.2x2",
        backgroundColor: CodableColor(.systemBrown),
        isPopular: false,
        isCustom: false
    )

    // Math Games
    static let mathle = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-446655440008"),
        name: "mathle",
        displayName: "Mathle",
        url: URL(string: "https://www.mathle.com")!,
        category: .math,
        resultPattern: #"Mathle \d+ [1-6X]/6"#,
        iconSystemName: "function",
        backgroundColor: CodableColor(.systemIndigo),
        isPopular: false,
        isCustom: false
    )

    static let numberle = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-446655440009"),
        name: "numberle",
        displayName: "Numberle",
        url: URL(string: "https://numberle.com")!,
        category: .math,
        resultPattern: #"Numberle \d+ [1-6X]/6"#,
        iconSystemName: "number.square",
        backgroundColor: CodableColor(.systemCyan),
        isPopular: false,
        isCustom: false
    )

    // Geography Games
    static let worldle = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-44665544000A"),
        name: "worldle",
        displayName: "Worldle",
        url: URL(string: "https://worldle.teuteuf.fr")!,
        category: .geography,
        resultPattern: #"#Worldle #\d+ [1-6X]/6"#,
        iconSystemName: "globe",
        backgroundColor: CodableColor(.systemGreen),
        isPopular: true,
        isCustom: false
    )

    static let globle = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-44665544000B"),
        name: "globle",
        displayName: "Globle",
        url: URL(string: "https://globle-game.com")!,
        category: .geography,
        resultPattern: #"Globle.*?in \d+ guesses"#,
        iconSystemName: "globe.americas",
        backgroundColor: CodableColor(.systemTeal),
        isPopular: false,
        isCustom: false
    )

    // Trivia Games
    static let contexto = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-44665544000C"),
        name: "contexto",
        displayName: "Contexto",
        url: URL(string: "https://contexto.me")!,
        category: .trivia,
        resultPattern: #"Contexto \d+.*?in \d+ guesses"#,
        iconSystemName: "lightbulb",
        backgroundColor: CodableColor(.systemRed),
        isPopular: true,
        isCustom: false
    )

    static let framed = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-44665544000D"),
        name: "framed",
        displayName: "Framed",
        url: URL(string: "https://framed.wtf")!,
        category: .trivia,
        resultPattern: #"Framed #\d+ [1-6X]/6"#,
        iconSystemName: "film",
        backgroundColor: CodableColor(.systemPink),
        isPopular: false,
        isCustom: false
    )

    // Puzzle Games
    static let crosswordle = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-44665544000E"),
        name: "crosswordle",
        displayName: "Crosswordle",
        url: URL(string: "https://crosswordle.serializer.ca")!,
        category: .puzzle,
        resultPattern: #"Crosswordle \d+.*?in \d+"#,
        iconSystemName: "square.grid.3x3.fill",
        backgroundColor: CodableColor(.systemGray),
        isPopular: false,
        isCustom: false
    )

    static let mini_crossword = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-44665544000F"),
        name: "mini_crossword",
        displayName: "Mini Crossword",
        url: URL(string: "https://www.nytimes.com/crosswords/game/mini")!,
        category: .puzzle,
        resultPattern: #"Mini Crossword.*?(\d+:\d+|\d+s)"#,
        iconSystemName: "square.grid.2x2",
        backgroundColor: CodableColor(.systemBlue),
        isPopular: true,
        isCustom: false
    )

    static let sudoku = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-446655440010"),
        name: "sudoku",
        displayName: "Sudoku",
        url: URL(string: "https://www.nytimes.com/puzzles/sudoku")!,
        category: .puzzle,
        resultPattern: #"Sudoku.*?in (\d+:\d+|\d+m)"#,
        iconSystemName: "square.grid.3x3.topleft.filled",
        backgroundColor: CodableColor(.systemPurple),
        isPopular: true,
        isCustom: false
    )

    // Music Games
    static let lyricle = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-446655440011"),
        name: "lyricle",
        displayName: "Lyricle",
        url: URL(string: "https://www.lyricle.app")!,
        category: .music,
        resultPattern: #"Lyricle \d+ [1-6X]/6"#,
        iconSystemName: "music.note.list",
        backgroundColor: CodableColor(.systemPink),
        isPopular: false,
        isCustom: false
    )

    // More Word Games
    static let absurdle = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-446655440012"),
        name: "absurdle",
        displayName: "Absurdle",
        url: URL(string: "https://absurdle.online")!,
        category: .word,
        resultPattern: #"Absurdle.*?in \d+ guesses"#,
        iconSystemName: "questionmark.square",
        backgroundColor: CodableColor(.systemRed),
        isPopular: false,
        isCustom: false
    )

    static let semantle = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-446655440013"),
        name: "semantle",
        displayName: "Semantle",
        url: URL(string: "https://semantle.com")!,
        category: .word,
        resultPattern: #"Semantle #\d+.*?in \d+ guesses"#,
        iconSystemName: "brain",
        backgroundColor: CodableColor(.systemIndigo),
        isPopular: false,
        isCustom: false
    )

    // MARK: - More Word Games (21-30)

    static let dordle = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-446655440015"),
        name: "dordle",
        displayName: "Dordle",
        url: URL(string: "https://zaratustra.itch.io/dordle")!,
        category: .word,
        resultPattern: #"Daily Dordle #\d+"#,
        iconSystemName: "square.on.square",
        backgroundColor: CodableColor(.systemOrange),
        isPopular: false,
        isCustom: false
    )

    static let sedecordle = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-446655440016"),
        name: "sedecordle",
        displayName: "Sedecordle",
        url: URL(string: "https://sedecordle.com")!,
        category: .word,
        resultPattern: #"Daily Sedecordle #\d+"#,
        iconSystemName: "square.grid.3x3.square",
        backgroundColor: CodableColor(.systemRed),
        isPopular: false,
        isCustom: false
    )

    static let kilordle = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-446655440017"),
        name: "kilordle",
        displayName: "Kilordle",
        url: URL(string: "https://kilordle.com")!,
        category: .word,
        resultPattern: #"Kilordle.*?in \d+ guesses"#,
        iconSystemName: "infinity",
        backgroundColor: CodableColor(.systemIndigo),
        isPopular: false,
        isCustom: false
    )

    static let antiwordle = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-446655440018"),
        name: "antiwordle",
        displayName: "Antiwordle",
        url: URL(string: "https://antiwordle.com")!,
        category: .word,
        resultPattern: #"Antiwordle.*?in \d+ attempts"#,
        iconSystemName: "arrow.uturn.backward.square",
        backgroundColor: CodableColor(.systemPink),
        isPopular: false,
        isCustom: false
    )

    static let wordscapes = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-446655440019"),
        name: "wordscapes",
        displayName: "Wordscapes",
        url: URL(string: "https://wordscapes.com")!,
        category: .word,
        resultPattern: #"Wordscapes.*?Level \d+"#,
        iconSystemName: "leaf",
        backgroundColor: CodableColor(.systemGreen),
        isPopular: false,
        isCustom: false
    )

    static let wordhurdle = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-44665544001A"),
        name: "wordhurdle",
        displayName: "Word Hurdle",
        url: URL(string: "https://wordhurdle.com")!,
        category: .word,
        resultPattern: #"Word Hurdle.*?in \d+/6"#,
        iconSystemName: "figure.run.square.stack",
        backgroundColor: CodableColor(.systemBlue),
        isPopular: false,
        isCustom: false
    )

    static let xordle = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-44665544001B"),
        name: "xordle",
        displayName: "Xordle",
        url: URL(string: "https://xordle.xyz")!,
        category: .word,
        resultPattern: #"Xordle #\d+ [1-9X]/9"#,
        iconSystemName: "xmark.square",
        backgroundColor: CodableColor(.systemGray),
        isPopular: false,
        isCustom: false
    )

    static let squareword = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-44665544001C"),
        name: "squareword",
        displayName: "Squareword",
        url: URL(string: "https://squareword.org")!,
        category: .word,
        resultPattern: #"Squareword.*?in \d+ guesses"#,
        iconSystemName: "square.text.square",
        backgroundColor: CodableColor(.systemMint),
        isPopular: false,
        isCustom: false
    )

    static let phrazle = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-44665544001D"),
        name: "phrazle",
        displayName: "Phrazle",
        url: URL(string: "https://phrazle.com")!,
        category: .word,
        resultPattern: #"Phrazle.*?in \d+/6"#,
        iconSystemName: "text.quote",
        backgroundColor: CodableColor(.systemBrown),
        isPopular: false,
        isCustom: false
    )

}
