//
//  WidgetSymbol.swift
//  StreakSyncWidget
//
//  Guards against symbol names this OS build does not ship
//

import UIKit

/// The snapshot carries whatever `iconSystemName` the app wrote. If that build
/// used a symbol this OS does not have, `Image(systemName:)` renders an empty
/// box — this collapses that case to a legible fallback instead.
enum WidgetSymbol {
    static let fallback = "gamecontroller.fill"

    static func resolve(_ name: String) -> String {
        guard !name.isEmpty, UIImage(systemName: name) != nil else {
            return fallback
        }
        return name
    }
}
