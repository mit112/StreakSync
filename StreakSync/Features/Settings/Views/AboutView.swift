//
//  AboutView.swift
//  StreakSync
//
//  About screen — app info, version, features, and external links
//

import SwiftUI

// MARK: - About View
struct AboutView: View {
    var body: some View {
        List {
            // App Info Section
            Section {
                VStack(alignment: .center, spacing: Spacing.lg) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.blue)

                    VStack(spacing: Spacing.xs) {
                        Text("StreakSync")
                            .font(.title2.weight(.bold))

                        Text("Track your daily puzzle streaks")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
            }

            // Version Section
            Section("Version") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Build")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                        .foregroundStyle(.secondary)
                }
            }

            // About Section
            Section("About") {
                Text("""
                    StreakSync helps you track your daily puzzle game streaks. \
                    Simply share your game results and we'll automatically track your progress.
                    """)
                    .font(.subheadline)
                    .padding(.vertical, Spacing.xs)
            }

            // Features Section
            Section("Features") {
                FeatureRow(icon: "square.and.arrow.up", text: "Easy result sharing")
                FeatureRow(icon: "flame.fill", text: "Automatic streak tracking")
                FeatureRow(icon: "trophy.fill", text: "Achievement system")
                FeatureRow(icon: SFSymbolCompatibility.getSymbol("chart.line.uptrend.xyaxis"), text: "Progress tracking")
            }

            // Links Section
            Section {
                if let websiteURL = URL(string: "https://streaksync.app") {
                    Link(destination: websiteURL) {
                        HStack {
                            Label("Website", systemImage: "globe")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let privacyURL = URL(string: "https://streaksync.app/privacy") {
                    Link(destination: privacyURL) {
                        HStack {
                            Label("Privacy Policy", systemImage: "hand.raised")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let supportEmailURL = URL(string: "mailto:support@streaksync.app") {
                    Link(destination: supportEmailURL) {
                        HStack {
                            Label("Contact Support", systemImage: "envelope")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Feature Row
private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image.safeSystemName(icon, fallback: "gear")
                .font(.body)
                .foregroundStyle(.blue)
                .frame(width: 28)

            Text(text)
                .font(.subheadline)

            Spacer()
        }
    }
}
