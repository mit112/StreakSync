//
//  SyncStatusBanner.swift
//  StreakSync
//
//  Compact banner that shows sync issues or pending score uploads.
//  Hidden when everything is healthy.
//

import SwiftUI

struct SyncStatusBanner: View {
    let syncState: SyncState
    let pendingScoreCount: Int
    
    var body: some View {
        if let info = bannerInfo {
            HStack(spacing: 8) {
                Image(systemName: info.icon)
                    .font(.subheadline)
                Text(info.message)
                    .font(.subheadline)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(info.color.opacity(0.15))
            .foregroundStyle(info.color)
        }
    }
    
    private var bannerInfo: (icon: String, message: String, color: Color)? {
        switch syncState {
        case .failed:
            return ("exclamationmark.icloud", "Sync failed — your data is saved locally", .orange)
        case .offline:
            return ("icloud.slash", "Offline — changes will sync when connected", .secondary)
        default:
            break
        }
        
        if pendingScoreCount > 0 {
            let label = pendingScoreCount == 1 ? "1 score" : "\(pendingScoreCount) scores"
            return ("arrow.triangle.2.circlepath", "\(label) pending upload", .secondary)
        }
        
        return nil // Hidden when healthy
    }
}
