//
//  FirstShareCelebrationOverlay.swift
//  StreakSync
//
//  Listens for .appFirstShareCelebrationRequested and renders confetti + a transient banner.
//

import SwiftUI

struct FirstShareCelebrationOverlay: ViewModifier {
    @State private var isCelebrating: Bool = false
    @State private var gameName: String = ""

    private let displayDuration: TimeInterval = 3.0

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                bannerOverlay
            }
            .overlay {
                ConfettiView(isActive: isCelebrating, duration: displayDuration)
                    .ignoresSafeArea()
            }
            .onReceive(NotificationCenter.default.publisher(for: .appFirstShareCelebrationRequested)) { note in
                handleNotification(note)
            }
    }

    @ViewBuilder
    private var bannerOverlay: some View {
        if isCelebrating {
            HStack(spacing: 10) {
                Text("🎉")
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("First streak started!")
                        .font(.subheadline.weight(.semibold))
                    if !gameName.isEmpty {
                        Text(gameName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
            )
            .padding(.top, 12)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("First streak started in \(gameName)")
        }
    }

    private func handleNotification(_ note: Notification) {
        let name = (note.userInfo?["gameName"] as? String) ?? ""
        gameName = name
        HapticManager.shared.trigger(.achievement)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            isCelebrating = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(displayDuration))
            withAnimation(.easeOut(duration: 0.3)) {
                isCelebrating = false
            }
        }
    }
}

extension View {
    /// Mounts the first-share celebration overlay (confetti + banner).
    /// Place once at the app shell level, above tabs/sheets.
    func firstShareCelebration() -> some View {
        modifier(FirstShareCelebrationOverlay())
    }
}
