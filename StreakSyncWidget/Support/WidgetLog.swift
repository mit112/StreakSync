//
//  WidgetLog.swift
//  StreakSyncWidget
//
//  OSLog loggers for the widget extension
//

import OSLog

enum WidgetLog {
    static let timeline = Logger(subsystem: "com.streaksync.widget", category: "Timeline")
    static let intents = Logger(subsystem: "com.streaksync.widget", category: "Intents")
}
