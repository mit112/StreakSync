//
//  ErrorHandling+UI.swift
//  StreakSync
//
//  SwiftUI error presentation components and modifiers
//

import SwiftUI

// MARK: - Error Alert Modifier
struct ErrorAlertModifier: ViewModifier {
    @Binding var error: AppError?
    var onDismiss: (() -> Void)? = nil
    var onRetry: (() -> Void)? = nil
    
    func body(content: Content) -> some View {
        content
            .alert(
                "Error",
                isPresented: .constant(error != nil),
                presenting: error
            ) { error in
                // Buttons based on error severity and recovery options
                if error.recoverySuggestion != nil && onRetry != nil {
                    Button("Try Again", action: {
                        onRetry?()
                        self.error = nil
                    })
                    Button("Cancel", role: .cancel) {
                        self.error = nil
                        onDismiss?()
                    }
                } else {
                    Button("OK") {
                        self.error = nil
                        onDismiss?()
                    }
                }
                
                // Add "Contact Support" for critical errors
                if error.severity == .critical {
                    Button("Contact Support") {
                        openSupportEmail(for: error)
                        self.error = nil
                    }
                }
            } message: { error in
                VStack(alignment: .leading, spacing: 8) {
                    if let description = error.errorDescription {
                        Text(description)
                    }
                    
                    if let reason = error.failureReason {
                        Text(reason)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let suggestion = error.recoverySuggestion {
                        Text(suggestion)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
    }
    
    private func openSupportEmail(for error: AppError) {
        let subject = "StreakSync Error: \(error.errorCode)"
        let body = """
        Error Code: \(error.errorCode)
        Category: \(error.errorCategory)
        
        Please describe what you were doing when this error occurred:
        
        """
        
        if let url = URL(string: "mailto:support@streaksync.app?subject=\(subject)&body=\(body)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - View Extension
extension View {
    func errorAlert(_ error: Binding<AppError?>, onRetry: (() -> Void)? = nil) -> some View {
        modifier(ErrorAlertModifier(error: error, onRetry: onRetry))
    }
}

// MARK: - Inline Error View
struct InlineErrorView: View {
    let error: AppError
    var onRetry: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image.safeSystemName(iconName, fallback: "exclamationmark.triangle")
                    .foregroundColor(iconColor)
                
                Text(error.errorDescription ?? "An error occurred")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
            }
            
            if let suggestion = error.recoverySuggestion {
                Text(suggestion)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let onRetry = onRetry {
                Button("Try Again") {
                    onRetry()
                }
                .font(.caption.weight(.medium))
                .foregroundColor(.blue)
                .padding(.top, 4)
            }
        }
        .padding()
        .background(backgroundColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: 1)
        )
    }
    
    private var iconName: String {
        switch error.severity {
        case .low: return "info.circle"
        case .medium: return "exclamationmark.triangle"
        case .high: return "exclamationmark.octagon"
        case .critical: return "xmark.octagon"
        }
    }
    
    private var iconColor: Color {
        switch error.severity {
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        case .critical: return .red
        }
    }
    
    private var backgroundColor: Color {
        switch error.severity {
        case .low: return Color.blue.opacity(0.1)
        case .medium: return Color.orange.opacity(0.1)
        case .high: return Color.red.opacity(0.1)
        case .critical: return Color.red.opacity(0.15)
        }
    }
    
    private var borderColor: Color {
        switch error.severity {
        case .low: return .blue.opacity(0.3)
        case .medium: return .orange.opacity(0.3)
        case .high: return .red.opacity(0.3)
        case .critical: return .red.opacity(0.5)
        }
    }
}
