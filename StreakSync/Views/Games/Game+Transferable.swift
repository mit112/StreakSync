//
//  Game+Transferable.swift
//  StreakSync
//
//  Extension to make Game draggable for reordering
//

import SwiftUI
import UniformTypeIdentifiers

extension Game: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .game)
    }
}

extension UTType {
    static let game = UTType(exportedAs: "com.streaksync.game")
}
