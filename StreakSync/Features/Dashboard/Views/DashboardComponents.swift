////
////  Missing Dashboard Components - COMPILER ERROR FIXES
////  StreakSync
////
////  FIXED: All missing view declarations and component issues (SINGLE SOURCE)
////
//
import SwiftUI

// MARK: - SectionHeaderView (Single Declaration)
struct SectionHeaderView: View {
    let title: String
    let icon: String
    let action: (() -> Void)?
    
    init(title: String, icon: String, action: (() -> Void)? = nil) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.headline)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
            
            Spacer()
            
            if let action = action {
                Button("See All", action: action)
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .accessibilityAddTraits(.isButton)
            }
        }
    }
}
