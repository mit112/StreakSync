//
//  ShareInviteView.swift
//  StreakSync
//
//  SwiftUI wrapper for UICloudSharingController to share a CKShare.
//

import SwiftUI
#if canImport(CloudKit)
import CloudKit
#endif
import UIKit

#if canImport(CloudKit)
struct ShareInviteView: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer
    
    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.availablePermissions = [.allowReadWrite]
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {
        // no-op
    }
}
#endif


