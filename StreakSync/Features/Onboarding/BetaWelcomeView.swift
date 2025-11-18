//
//  BetaWelcomeView.swift
//  StreakSync
//
//  Lightweight onboarding for the simplified beta experience.
//

import SwiftUI

struct BetaWelcomeView: View {
    @AppStorage("beta_welcome_shown") private var hasSeenBetaWelcome = false
    @State private var currentPage = 0
    let onFinished: (() -> Void)?

    init(onFinished: (() -> Void)? = nil) {
        self.onFinished = onFinished
    }

    var body: some View {
        TabView(selection: $currentPage) {
            BetaWelcomePage(
                title: "Welcome to Friends",
                subtitle: "See how your daily puzzles stack up against friends.",
                systemImage: "person.3.fill"
            )
            .tag(0)

            BetaWelcomePage(
                title: "Share a Link",
                subtitle: "Invite anyone by sending a single share link. No codes, no circles.",
                systemImage: "link"
            )
            .tag(1)

            BetaWelcomePage(
                title: "Today Matters",
                subtitle: "Check in daily to compare today's results. Swipe to switch games.",
                systemImage: "calendar"
            )
            .tag(2)

            VStack(spacing: 20) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue)
                Text("Help Us Improve")
                    .font(.title2).bold()
                Text("Send feedback anytime with the Beta Feedback button.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Get Started") {
                    hasSeenBetaWelcome = true
                    onFinished?()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .tag(3)
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .presentationDetents([.fraction(0.8)])
    }
}

private struct BetaWelcomePage: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: systemImage)
                .font(.system(size: 70))
                .foregroundStyle(.blue)
            Text(title)
                .font(.title2).bold()
            Text(subtitle)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
    }
}

