//
//  GameDefinitions+Categories.swift
//  StreakSync
//
//  Extended game catalog: math/logic, music/audio, geography,
//  and trivia/visual game definitions.
//

import Foundation
import UIKit

// MARK: - Math, Music, Geography & Trivia Games
extension Game {

    // MARK: - More Math/Logic Games (31-35)

    static let primel = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-44665544001E"),
        name: "primel",
        displayName: "Primel",
        url: URL(string: "https://converged.yt/primel")!,
        category: .math,
        resultPattern: #"Primel \d+ [1-6X]/6"#,
        iconSystemName: "number.circle",
        backgroundColor: CodableColor(.systemPurple),
        isPopular: false,
        isCustom: false
    )

    static let ooodle = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-44665544001F"),
        name: "ooodle",
        displayName: "Ooodle",
        url: URL(string: "https://ooodle.live")!,
        category: .math,
        resultPattern: #"Ooodle.*?in \d+ attempts"#,
        iconSystemName: "plus.forwardslash.minus",
        backgroundColor: CodableColor(.systemOrange),
        isPopular: false,
        isCustom: false
    )

    static let summle = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-446655440020"),
        name: "summle",
        displayName: "Summle",
        url: URL(string: "https://summle.com")!,
        category: .math,
        resultPattern: #"Summle.*?in \d+ tries"#,
        iconSystemName: "sum",
        backgroundColor: CodableColor(.systemYellow),
        isPopular: false,
        isCustom: false
    )

    static let timeguessr = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-446655440021"),
        name: "timeguessr",
        displayName: "TimeGuessr",
        url: URL(string: "https://timeguessr.com")!,
        category: .math,
        resultPattern: #"TimeGuessr.*?Score: \d+"#,
        iconSystemName: "clock.badge.questionmark",
        backgroundColor: CodableColor(.systemTeal),
        isPopular: false,
        isCustom: false
    )

    static let rankdle = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-446655440022"),
        name: "rankdle",
        displayName: "Rankdle",
        url: URL(string: "https://rankdle.com")!,
        category: .math,
        resultPattern: #"Rankdle.*?in \d+ attempts"#,
        iconSystemName: "list.number",
        backgroundColor: CodableColor(.systemCyan),
        isPopular: false,
        isCustom: false
    )

    // MARK: - More Music/Audio Games (36-40)

    static let songlio = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-446655440023"),
        name: "songlio",
        displayName: "Songlio",
        url: URL(string: "https://songlio.com")!,
        category: .music,
        resultPattern: #"Songlio.*?in \d+ tries"#,
        iconSystemName: "music.mic",
        backgroundColor: CodableColor(.systemPink),
        isPopular: false,
        isCustom: false
    )

    static let binb = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-446655440024"),
        name: "binb",
        displayName: "BINB",
        url: URL(string: "https://binb.co")!,
        category: .music,
        resultPattern: #"BINB.*?in \d+ guesses"#,
        iconSystemName: "waveform",
        backgroundColor: CodableColor(.systemRed),
        isPopular: false,
        isCustom: false
    )

    static let songle = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-446655440025"),
        name: "songle",
        displayName: "Songle",
        url: URL(string: "https://songle.io")!,
        category: .music,
        resultPattern: #"Songle.*?in \d+ attempts"#,
        iconSystemName: "music.quarternote.3",
        backgroundColor: CodableColor(.systemIndigo),
        isPopular: false,
        isCustom: false
    )

    static let bandle = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-446655440026"),
        name: "bandle",
        displayName: "Bandle",
        url: URL(string: "https://bandle.app")!,
        category: .music,
        resultPattern: #"Bandle.*?\d+/6"#,
        iconSystemName: "guitars",
        backgroundColor: CodableColor(.systemGreen),
        isPopular: false,
        isCustom: false
    )

    static let musicle = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-446655440027"),
        name: "musicle",
        displayName: "Musicle",
        url: URL(string: "https://musicle.app")!,
        category: .music,
        resultPattern: #"Musicle.*?in \d+ seconds"#,
        iconSystemName: "music.note.tv",
        backgroundColor: CodableColor(.systemBlue),
        isPopular: false,
        isCustom: false
    )

    // MARK: - More Geography Games (41-45)

    static let countryle = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-446655440028"),
        name: "countryle",
        displayName: "Countryle",
        url: URL(string: "https://countryle.com")!,
        category: .geography,
        resultPattern: #"Countryle.*?in \d+ guesses"#,
        iconSystemName: "map",
        backgroundColor: CodableColor(.systemOrange),
        isPopular: false,
        isCustom: false
    )

    static let flagle = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-446655440029"),
        name: "flagle",
        displayName: "Flagle",
        url: URL(string: "https://flagle.io")!,
        category: .geography,
        resultPattern: #"Flagle.*?in \d+/6"#,
        iconSystemName: "flag",
        backgroundColor: CodableColor(.systemRed),
        isPopular: false,
        isCustom: false
    )

    static let statele = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-44665544002A"),
        name: "statele",
        displayName: "Statele",
        url: URL(string: "https://statele.com")!,
        category: .geography,
        resultPattern: #"Statele.*?in \d+ guesses"#,
        iconSystemName: "map.circle",
        backgroundColor: CodableColor(.systemPurple),
        isPopular: false,
        isCustom: false
    )

    static let citydle = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-44665544002B"),
        name: "citydle",
        displayName: "Citydle",
        url: URL(string: "https://citydle.com")!,
        category: .geography,
        resultPattern: #"Citydle.*?in \d+ attempts"#,
        iconSystemName: "building.2",
        backgroundColor: CodableColor(.systemGray),
        isPopular: false,
        isCustom: false
    )

    static let wheretaken = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-44665544002C"),
        name: "wheretaken",
        displayName: "WhereTaken",
        url: URL(string: "https://wheretaken.com")!,
        category: .geography,
        resultPattern: #"WhereTaken.*?in \d+ guesses"#,
        iconSystemName: "camera.on.rectangle",
        backgroundColor: CodableColor(.systemMint),
        isPopular: false,
        isCustom: false
    )

    // MARK: - More Trivia/Visual Games (46-50)

    static let moviedle = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-44665544002D"),
        name: "moviedle",
        displayName: "Moviedle",
        url: URL(string: "https://moviedle.app")!,
        category: .trivia,
        resultPattern: #"Moviedle.*?in \d+ seconds"#,
        iconSystemName: "film",
        backgroundColor: CodableColor(.systemYellow),
        isPopular: false,
        isCustom: false
    )

    static let posterdle = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-44665544002E"),
        name: "posterdle",
        displayName: "Posterdle",
        url: URL(string: "https://posterdle.com")!,
        category: .trivia,
        resultPattern: #"Posterdle.*?in \d+ guesses"#,
        iconSystemName: "photo.artframe",
        backgroundColor: CodableColor(.systemTeal),
        isPopular: false,
        isCustom: false
    )

    static let actorle = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-44665544002F"),
        name: "actorle",
        displayName: "Actorle",
        url: URL(string: "https://actorle.com")!,
        category: .trivia,
        resultPattern: #"Actorle.*?in \d+ guesses"#,
        iconSystemName: "person.crop.rectangle",
        backgroundColor: CodableColor(.systemBrown),
        isPopular: false,
        isCustom: false
    )

    static let foodguessr = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-446655440030"),
        name: "foodguessr",
        displayName: "FoodGuessr",
        url: URL(string: "https://foodguessr.com")!,
        category: .trivia,
        resultPattern: #"FoodGuessr.*?Score: \d+"#,
        iconSystemName: "fork.knife",
        backgroundColor: CodableColor(.systemOrange),
        isPopular: false,
        isCustom: false
    )

    static let artdle = Game(
        id: Game.safeUUID("550e8400-e29b-41d4-a716-446655440031"),
        name: "artdle",
        displayName: "Artdle",
        url: URL(string: "https://artdle.com")!,
        category: .trivia,
        resultPattern: #"Artdle.*?in \d+ guesses"#,
        iconSystemName: "paintpalette",
        backgroundColor: CodableColor(.systemPink),
        isPopular: false,
        isCustom: false
    )
}
