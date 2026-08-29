//
//  WidgetDeepLink.swift
//  StreakSyncWidget
//
//  The streaksync:// URLs the widget hands back to the host app
//

import Foundation

/// Deep links the widget taps through to. The `streaksync` scheme is already
/// registered in the app's Info.plist and routed by `AppGroupURLSchemeHandler`,
/// so nothing in the main app changes to support these.
enum WidgetDeepLink {
    private static let scheme = "streaksync"

    /// Opens the app without targeting a game. Used by every "open StreakSync"
    /// affordance. `URL(staticString:)` comes from `GameDefinitions.swift`, which
    /// is in this target's membership; the literal is a valid URL by inspection.
    static let openApp = URL(staticString: "streaksync://newresult")

    /// Routes to one game's detail screen. `AppGroupURLSchemeHandler` reads the
    /// literal query key `id` and parses the value as a UUID — the `name` key it
    /// also accepts matches the lowercase slug, so the id is the exact route.
    static func game(id: UUID) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "game"
        components.queryItems = [URLQueryItem(name: "id", value: id.uuidString)]
        // A scheme + host + one query item always composes; falling back to the
        // plain app link keeps the tap useful rather than dead if it ever cannot.
        return components.url ?? openApp
    }
}
