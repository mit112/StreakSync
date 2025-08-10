import Foundation
import OSLog

final class SharedDataManager {
    static let shared = SharedDataManager()
    private let logger = Logger(subsystem: "com.streaksync.app", category: "SharedDataManager")
    
    private var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.mitsheth.StreakSync")
    }
    
    private var latestResultFileURL: URL? {
        sharedContainerURL?.appendingPathComponent("latest_result.json")
    }
    
    func saveLatestResult(_ result: GameResult) throws {
        guard let fileURL = latestResultFileURL else {
            throw SharedDataError.noContainerAccess
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(result)
        
        // Use atomic write for data integrity
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        
        logger.info("Saved result to file: \(fileURL.lastPathComponent)")
    }
    
    func loadLatestResult() throws -> GameResult? {
        guard let fileURL = latestResultFileURL else {
            throw SharedDataError.noContainerAccess
        }
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(GameResult.self, from: data)
    }
    
    func deleteLatestResult() throws {
        guard let fileURL = latestResultFileURL else { return }
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }
}

enum SharedDataError: LocalizedError {
    case noContainerAccess
    
    var errorDescription: String? {
        switch self {
        case .noContainerAccess:
            return "Cannot access shared container"
        }
    }
}
