//
//  SettingsView.swift
//  StreakSync
//
//  Settings on native grouped surfaces with a restrained two-colour row palette
//

import SwiftUI

// MARK: - Settings View
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @EnvironmentObject private var coordinator: NavigationCoordinator

    var body: some View {
        IOS26SettingsContent(viewModel: viewModel)
    }
}

// MARK: - iOS 26 Implementation
private struct IOS26SettingsContent: View {
    @ObservedObject var viewModel: SettingsViewModel
    @EnvironmentObject private var container: AppContainer

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    // Ordinary navigation rows are brand blue; About is the one neutral row. Orange, red,
    // and emerald now live only inside destinations that report a real state
    // (anonymous/warning, destructive, success), not on a row for variety (§4.9).
    var body: some View {
        List {
            Section {
                IOS26SettingsNavigationRow(
                    icon: container.firebaseAuthManager.isAnonymous
                        ? "person.crop.circle.badge.questionmark"
                        : "person.crop.circle.fill",
                    iconColor: StreakSyncBrand.primary,
                    title: "Account",
                    subtitle: container.firebaseAuthManager.isAnonymous
                        ? "Sign in to set your name"
                        : (container.firebaseAuthManager.displayName ?? "Signed in")
                ) {
                    AccountView(authManager: container.firebaseAuthManager)
                        .environmentObject(container)
                }
            }

            Section {
                IOS26SettingsNavigationRow(
                    icon: "bell.badge",
                    iconColor: StreakSyncBrand.primary,
                    title: "Notifications",
                    subtitle: viewModel.notificationsEnabled ? "Enabled" : "Disabled"
                ) {
                    NotificationSettingsView()
                }

                IOS26SettingsNavigationRow(
                    icon: "moon.circle",
                    iconColor: StreakSyncBrand.primary,
                    title: "Appearance",
                    subtitle: viewModel.appearanceMode.displayName
                ) {
                    AppearanceSettingsView()
                }

                IOS26SettingsNavigationRow(
                    icon: "square.and.arrow.down.on.square",
                    iconColor: StreakSyncBrand.primary,
                    title: "Data & Privacy",
                    subtitle: "Export, import, or clear data"
                ) {
                    DataManagementView()
                }
            }

            Section {
                IOS26SettingsNavigationRow(
                    icon: "square.and.arrow.up.on.square",
                    iconColor: StreakSyncBrand.primary,
                    title: "How StreakSync works",
                    subtitle: nil
                ) {
                    ShareDiscoverySheet(onDismiss: {})
                }

                IOS26SettingsNavigationRow(
                    icon: "info.circle",
                    iconColor: .secondary,
                    title: "About",
                    subtitle: "Version \(appVersion)"
                ) {
                    AboutView()
                }

                if let privacyURL = URL(string: "https://streaksync.app/privacy") {
                    IOS26SettingsLinkRow(
                        icon: "hand.raised.circle",
                        iconColor: StreakSyncBrand.primary,
                        title: "Privacy Policy",
                        url: privacyURL
                    )
                }

                if let supportURL = URL(string: "mailto:support@streaksync.app") {
                    IOS26SettingsLinkRow(
                        icon: "envelope.circle",
                        iconColor: StreakSyncBrand.primary,
                        title: "Contact Support",
                        url: supportURL
                    )
                }
            }

            #if DEBUG
            Section {
                IOS26SettingsNavigationRow(
                    icon: "hammer.circle.fill",
                    iconColor: StreakSyncBrand.primary,
                    title: "Debug Seeder",
                    subtitle: "Seed realistic test data"
                ) {
                    DebugDataSeederView()
                }
            }
            #endif
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadSettings()
        }
    }
}

// MARK: - iOS 26 Settings Navigation Row
private struct IOS26SettingsNavigationRow<Destination: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    @ViewBuilder let destination: Destination

    // No layered onTapGesture, press scaling, or hover lift: the List row supplies the
    // chevron, the highlight, and the 44pt hit area natively.
    var body: some View {
        NavigationLink {
            destination
        } label: {
            Label {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(title)
                        .fixedSize(horizontal: false, vertical: true)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } icon: {
                Image.safeSystemName(icon, fallback: "gear")
                    .foregroundStyle(iconColor)
                    .frame(width: 28)
            }
        }
    }
}

// MARK: - iOS 26 Settings Link Row
private struct IOS26SettingsLinkRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            Label {
                HStack {
                    Text(title)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: Spacing.sm)
                    Image(systemName: "arrow.up.right.square")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            } icon: {
                Image.safeSystemName(icon, fallback: "gear")
                    .foregroundStyle(iconColor)
                    .frame(width: 28)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AppContainer(isPreview: true))
            .environmentObject(NavigationCoordinator())
    }
}
