//
//  StreakSyncWidgetBundle.swift
//  StreakSyncWidget
//
//  Entry point for the StreakSync widget extension
//

import SwiftUI
import WidgetKit

@main
struct StreakSyncWidgetBundle: WidgetBundle {
    var body: some Widget {
        StreakOverviewWidget()
        SingleGameWidget()
    }
}
