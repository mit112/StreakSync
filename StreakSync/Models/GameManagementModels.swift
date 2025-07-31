////
////  GameManagementModels.swift
////  StreakSync
////
////  Models and extensions for game management features
////
//
//import Foundation
//import SwiftUI
//
//// MARK: - Game Group Model
//struct GameGroup: Identifiable, Codable, Hashable {
//    let id: UUID
//    var name: String
//    var iconSystemName: String
//    var color: CodableColor
//    var gameIds: [UUID]
//    var displayOrder: Int
//    var isExpanded: Bool
//    
//    init(
//        id: UUID = UUID(),
//        name: String,
//        iconSystemName: String = "folder",
//        color: CodableColor = .blue,
//        gameIds: [UUID] = [],
//        displayOrder: Int = 0,
//        isExpanded: Bool = true
//    ) {
//        self.id = id
//        self.name = name
//        self.iconSystemName = iconSystemName
//        self.color = color
//        self.gameIds = gameIds
//        self.displayOrder = displayOrder
//        self.isExpanded = isExpanded
//    }
//    
//    // Default groups
//    static let favorites = GameGroup(
//        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
//        name: "Favorites",
//        iconSystemName: "star.fill",
//        color: .yellow,
//        displayOrder: -1
//    )
//    
//    static let dailyGames = GameGroup(
//        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
//        name: "Daily Games",
//        iconSystemName: "calendar",
//        color: .blue,
//        displayOrder: 0
//    )
//}
//
//// MARK: - Game Display Settings
//struct GameDisplaySettings: Codable {
//    var isArchived: Bool = false
//    var displayOrder: Int = 0
//    var groupId: UUID? = nil
//    // For games that should always be visible
//    var isPinned: Bool = false
//}
//
//
