//
//  BetaFeedbackComponents.swift
//  StreakSync
//
//  Simple in-app feedback capture for beta builds.
//

import SwiftUI
import UIKit

struct BetaFeedbackButton: View {
    @State private var showFeedbackForm = false

    var body: some View {
        Button {
            showFeedbackForm = true
        } label: {
            Label("Beta Feedback", systemImage: "bubble.left.and.bubble.right")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .sheet(isPresented: $showFeedbackForm) {
            NavigationStack {
                BetaFeedbackForm()
            }
        }
    }
}

private enum BetaFeedbackType: String, CaseIterable, Identifiable {
    case bug, feature, confusion, other

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .bug: return "Bug"
        case .feature: return "Feature"
        case .confusion: return "Confusion"
        case .other: return "Other"
        }
    }
}

struct BetaFeedbackForm: View {
    @Environment(\.dismiss) private var dismiss
    @State private var feedbackType: BetaFeedbackType = .bug
    @State private var message: String = ""
    @State private var includeDebugInfo: Bool = true
    @State private var isSubmitting = false
    @State private var showConfirmation = false

    var body: some View {
        Form {
            Section("Feedback Type") {
                Picker("Type", selection: $feedbackType) {
                    ForEach(BetaFeedbackType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Message") {
                TextEditor(text: $message)
                    .frame(minHeight: 120)
            }

            Section {
                Toggle("Include Debug Info", isOn: $includeDebugInfo)
                Button {
                    submitFeedback()
                } label: {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Text("Send Feedback")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
            }
        }
        .navigationTitle("Beta Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Thanks!", isPresented: $showConfirmation) {
            Button("Done") {
                dismiss()
            }
        } message: {
            Text("We received your feedback.")
        }
    }

    private func submitFeedback() {
        guard !isSubmitting else { return }
        isSubmitting = true
        let payload = buildPayload()
        // Placeholder for real submission endpoint. For beta we log to console.
        print("📝 Beta Feedback:", payload)
        BetaMetrics.track(.feedbackSubmitted, properties: ["type": feedbackType.rawValue])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            isSubmitting = false
            showConfirmation = true
        }
    }

    private func buildPayload() -> [String: String] {
        var info: [String: String] = [
            "type": feedbackType.rawValue,
            "message": message.trimmingCharacters(in: .whitespacesAndNewlines),
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        ]
        if includeDebugInfo {
            info["device"] = UIDevice.current.model
            info["systemVersion"] = UIDevice.current.systemVersion
        }
        return info
    }
}

