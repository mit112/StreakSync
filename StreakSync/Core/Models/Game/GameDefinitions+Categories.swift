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
        id: UUID(staticString: "550e8400-e29b-41d4-a716-44665544001E"),
        name: "primel",
        displayName: "Primel",
        url: URL(staticString: "https://converged.yt/primel"),
        category: .math,
        iconSystemName: "number.circle",
        backgroundColor: CodableColor(.systemPurple),
        isPopular: false
    )

    static let ooodle = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-44665544001F"),
        name: "ooodle",
        displayName: "Ooodle",
        url: URL(staticString: "https://ooodle.live"),
        category: .math,
        iconSystemName: "plus.forwardslash.minus",
        backgroundColor: CodableColor(.systemOrange),
        isPopular: false
    )

    static let summle = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-446655440020"),
        name: "summle",
        displayName: "Summle",
        url: URL(staticString: "https://summle.com"),
        category: .math,
        iconSystemName: "sum",
        backgroundColor: CodableColor(.systemYellow),
        isPopular: false
    )

    static let timeguessr = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-446655440021"),
        name: "timeguessr",
        displayName: "TimeGuessr",
        url: URL(staticString: "https://timeguessr.com"),
        category: .math,
        iconSystemName: "clock.badge.questionmark",
        backgroundColor: CodableColor(.systemTeal),
        isPopular: false
    )

    static let rankdle = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-446655440022"),
        name: "rankdle",
        displayName: "Rankdle",
        url: URL(staticString: "https://rankdle.com"),
        category: .math,
        iconSystemName: "list.number",
        backgroundColor: CodableColor(.systemCyan),
        isPopular: false
    )

    // MARK: - More Music/Audio Games (36-40)

    static let songlio = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-446655440023"),
        name: "songlio",
        displayName: "Songlio",
        url: URL(staticString: "https://songlio.com"),
        category: .music,
        iconSystemName: "music.mic",
        backgroundColor: CodableColor(.systemPink),
        isPopular: false
    )

    static let binb = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-446655440024"),
        name: "binb",
        displayName: "BINB",
        url: URL(staticString: "https://binb.co"),
        category: .music,
        iconSystemName: "waveform",
        backgroundColor: CodableColor(.systemRed),
        isPopular: false
    )

    static let songle = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-446655440025"),
        name: "songle",
        displayName: "Songle",
        url: URL(staticString: "https://songle.io"),
        category: .music,
        iconSystemName: "music.quarternote.3",
        backgroundColor: CodableColor(.systemIndigo),
        isPopular: false
    )

    static let bandle = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-446655440026"),
        name: "bandle",
        displayName: "Bandle",
        url: URL(staticString: "https://bandle.app"),
        category: .music,
        iconSystemName: "guitars",
        backgroundColor: CodableColor(.systemGreen),
        isPopular: false
    )

    static let musicle = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-446655440027"),
        name: "musicle",
        displayName: "Musicle",
        url: URL(staticString: "https://musicle.app"),
        category: .music,
        iconSystemName: "music.note.tv",
        backgroundColor: CodableColor(.systemBlue),
        isPopular: false
    )

    // MARK: - More Geography Games (41-45)

    static let countryle = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-446655440028"),
        name: "countryle",
        displayName: "Countryle",
        url: URL(staticString: "https://countryle.com"),
        category: .geography,
        iconSystemName: "map",
        backgroundColor: CodableColor(.systemOrange),
        isPopular: false
    )

    static let flagle = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-446655440029"),
        name: "flagle",
        displayName: "Flagle",
        url: URL(staticString: "https://flagle.io"),
        category: .geography,
        iconSystemName: "flag",
        backgroundColor: CodableColor(.systemRed),
        isPopular: false
    )

    static let statele = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-44665544002A"),
        name: "statele",
        displayName: "Statele",
        url: URL(staticString: "https://statele.com"),
        category: .geography,
        iconSystemName: "map.circle",
        backgroundColor: CodableColor(.systemPurple),
        isPopular: false
    )

    static let citydle = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-44665544002B"),
        name: "citydle",
        displayName: "Citydle",
        url: URL(staticString: "https://citydle.com"),
        category: .geography,
        iconSystemName: "building.2",
        backgroundColor: CodableColor(.systemGray),
        isPopular: false
    )

    static let wheretaken = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-44665544002C"),
        name: "wheretaken",
        displayName: "WhereTaken",
        url: URL(staticString: "https://wheretaken.com"),
        category: .geography,
        iconSystemName: "camera.on.rectangle",
        backgroundColor: CodableColor(.systemMint),
        isPopular: false
    )

    // MARK: - More Trivia/Visual Games (46-50)

    static let moviedle = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-44665544002D"),
        name: "moviedle",
        displayName: "Moviedle",
        url: URL(staticString: "https://moviedle.app"),
        category: .trivia,
        iconSystemName: "film",
        backgroundColor: CodableColor(.systemYellow),
        isPopular: false
    )

    static let posterdle = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-44665544002E"),
        name: "posterdle",
        displayName: "Posterdle",
        url: URL(staticString: "https://posterdle.com"),
        category: .trivia,
        iconSystemName: "photo.artframe",
        backgroundColor: CodableColor(.systemTeal),
        isPopular: false
    )

    static let actorle = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-44665544002F"),
        name: "actorle",
        displayName: "Actorle",
        url: URL(staticString: "https://actorle.com"),
        category: .trivia,
        iconSystemName: "person.crop.rectangle",
        backgroundColor: CodableColor(.systemBrown),
        isPopular: false
    )

    static let foodguessr = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-446655440030"),
        name: "foodguessr",
        displayName: "FoodGuessr",
        url: URL(staticString: "https://foodguessr.com"),
        category: .trivia,
        iconSystemName: "fork.knife",
        backgroundColor: CodableColor(.systemOrange),
        isPopular: false
    )

    static let artdle = Game(
        id: UUID(staticString: "550e8400-e29b-41d4-a716-446655440031"),
        name: "artdle",
        displayName: "Artdle",
        url: URL(staticString: "https://artdle.com"),
        category: .trivia,
        iconSystemName: "paintpalette",
        backgroundColor: CodableColor(.systemPink),
        isPopular: false
    )
}
