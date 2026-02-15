//
//  SettingsView.swift
//  StreakSync
//
//  Modernized Settings with iOS 26 native list styles and effects
//  Maintains backward compatibility with iOS 25 and earlier
//

import SwiftUI
import UserNotifications

// MARK: - Settings View
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @Environment(AppState.self) private var appState
    
    var body: some View {
        iOS26SettingsContent(viewModel: viewModel)
    }
}

// MARK: - iOS 26 Implementation
private struct iOS26SettingsContent: View {
    @ObservedObject var viewModel: SettingsViewModel
    @EnvironmentObject private var container: AppContainer
    
    @State private var scrollPosition = ScrollPosition()
    @State private var hoveredSection: SettingsSection? = nil
    
    enum SettingsSection: String, CaseIterable {
        case account, notifications, appearance, data, about
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Account Section
                iOS26SettingsSection(
                    section: .account,
                    isHovered: hoveredSection == .account
                ) {
                    iOS26SettingsNavigationRow(
                        icon: container.firebaseAuthManager.isAnonymous ? "person.crop.circle.badge.questionmark" : "person.crop.circle.fill",
                        iconColor: container.firebaseAuthManager.isAnonymous ? .orange : .blue,
                        title: "Account",
                        subtitle: container.firebaseAuthManager.isAnonymous
                            ? "Sign in to set your name"
                            : (container.firebaseAuthManager.displayName ?? "Signed in"),
                        showChevron: true
                    ) {
                        AccountView(authManager: container.firebaseAuthManager)
                            .environmentObject(container)
                    }
                }
                .onHover { isHovered in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        hoveredSection = isHovered ? .account : nil
                    }
                }

                // Notifications Section
                iOS26SettingsSection(
                    section: .notifications,
                    isHovered: hoveredSection == .notifications
                ) {
                    iOS26SettingsNavigationRow(
                        icon: "bell.badge",
                        iconColor: .blue,
                        title: "Notifications",
                        subtitle: viewModel.notificationsEnabled ? "Enabled" : "Disabled",
                        showChevron: true
                    ) {
                        NotificationSettingsView()
                    }
                }
                .onHover { isHovered in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        hoveredSection = isHovered ? .notifications : nil
                    }
                }
                
                // Appearance Section
                iOS26SettingsSection(
                    section: .appearance,
                    isHovered: hoveredSection == .appearance
                ) {
                    iOS26SettingsNavigationRow(
                        icon: "moon.circle",
                        iconColor: .indigo,
                        title: "Appearance",
                        subtitle: viewModel.appearanceMode.displayName,
                        showChevron: true
                    ) {
                        AppearanceSettingsView()
                    }
                }
                .onHover { isHovered in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        hoveredSection = isHovered ? .appearance : nil
                    }
                }
                
                // Data Section
                iOS26SettingsSection(
                    section: .data,
                    isHovered: hoveredSection == .data
                ) {
                    iOS26SettingsNavigationRow(
                        icon: "square.and.arrow.down.on.square",
                        iconColor: .green,
                        title: "Data & Privacy",
                        subtitle: "Export, import, or clear data",
                        showChevron: true
                    ) {
                        DataManagementView()
                    }
                }
                .onHover { isHovered in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        hoveredSection = isHovered ? .data : nil
                    }
                }
                
                // About Section
                iOS26SettingsSection(
                    section: .about,
                    isHovered: hoveredSection == .about
                ) {
                    VStack(spacing: 0) {
                        iOS26SettingsNavigationRow(
                            icon: "info.circle",
                            iconColor: .gray,
                            title: "About",
                            subtitle: "Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")",
                            showChevron: true
                        ) {
                            AboutView()
                        }
                        
                        Divider()
                            .padding(.horizontal)
                        
                        iOS26SettingsLinkRow(
                            icon: "hand.raised.circle",
                            iconColor: .purple,
                            title: "Privacy Policy",
                            url: URL(string: "https://streaksync.app/privacy")!
                        )
                        
                        Divider()
                            .padding(.horizontal)
                        
                        iOS26SettingsLinkRow(
                            icon: "envelope.circle",
                            iconColor: .orange,
                            title: "Contact Support",
                            url: URL(string: "mailto:support@streaksync.app")!
                        )
                    }
                }
                .onHover { isHovered in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        hoveredSection = isHovered ? .about : nil
                    }
                }
            }
            .padding()
        }
        .scrollPosition($scrollPosition)
        .scrollBounceBehavior(.automatic)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadSettings()
        }
    }
}

// MARK: - iOS 26 Settings Section Container
private struct iOS26SettingsSection<Content: View>: View {
    let section: iOS26SettingsContent.SettingsSection
    let isHovered: Bool
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isHovered ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(Color(.secondarySystemGroupedBackground)))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                colorScheme == .dark ?
                                    Color(.separator).opacity(0.3) :
                                    Color(.separator).opacity(0.6),
                                lineWidth: colorScheme == .dark ? 0.5 : 1
                            )
                    }
                    .shadow(
                        color: .black.opacity(isHovered ? 0.1 : (colorScheme == .dark ? 0.05 : 0.07)),
                        radius: isHovered ? 12 : 6,
                        y: isHovered ? 6 : 2
                    )
                    .shadow(
                        color: colorScheme == .dark ? .clear : .black.opacity(0.04),
                        radius: 14,
                        y: 6
                    )
            }
            .scrollTransition { content, phase in
                content
                    .opacity(phase.isIdentity ? 1 : 0.8)
                    .scaleEffect(phase.isIdentity ? 1 : 0.98)
                    .blur(radius: phase.isIdentity ? 0 : 0.5)
            }
    }
}

// MARK: - iOS 26 Settings Navigation Row
private struct iOS26SettingsNavigationRow<Destination: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    let showChevron: Bool
    @ViewBuilder let destination: Destination
    
    @State private var isPressed = false
    @State private var iconBounce = false
    
    var body: some View {
        NavigationLink {
            destination
        } label: {
            HStack(spacing: 12) {
                // Animated Icon
                Image.safeSystemName(icon, fallback: "gear")
                    .font(.system(size: 22))
                    .foregroundStyle(iconColor)
                    .symbolEffect(.bounce, value: iconBounce)
                    .frame(width: 32, height: 32)
                    .background {
                        Circle()
                            .fill(iconColor.opacity(0.1))
                    }
                
                // Text Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Chevron
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .scaleEffect(isPressed ? 0.8 : 1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .hoverEffect(.lift)
        .onTapGesture {
            iconBounce.toggle()
        }
        .scaleEffect(isPressed ? 0.98 : 1)
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            },
            perform: {}
        )
    }
}

// MARK: - iOS 26 Settings Link Row
private struct iOS26SettingsLinkRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let url: URL
    
    @State private var isPressed = false
    @State private var iconRotation = false
    
    var body: some View {
        Link(destination: url) {
            HStack(spacing: 12) {
                // Animated Icon
                Image.safeSystemName(icon, fallback: "gear")
                    .font(.system(size: 22))
                    .foregroundStyle(iconColor)
                    .symbolEffect(.rotate, value: iconRotation)
                    .frame(width: 32, height: 32)
                    .background {
                        Circle()
                            .fill(iconColor.opacity(0.1))
                    }
                
                // Title
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // External Link Icon
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
                    .scaleEffect(isPressed ? 0.8 : 1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .hoverEffect(.highlight)
        .onTapGesture {
            iconRotation.toggle()
        }
        .scaleEffect(isPressed ? 0.98 : 1)
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            },
            perform: {}
        )
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
