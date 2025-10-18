//
//  SettingsView.swift
//  StreakSync
//
//  Modernized Settings with iOS 26 native list styles and effects
//  Maintains backward compatibility with iOS 25 and earlier
//

/*
 * SETTINGSVIEW - APP CONFIGURATION AND PREFERENCES CENTER
 * 
 * WHAT THIS FILE DOES:
 * This file creates the "settings screen" where users can configure the app to their preferences.
 * It's like the "control panel" of the app, allowing users to adjust notifications, appearance,
 * data management, and other app settings. Think of it as the "preferences menu" that gives
 * users control over how the app behaves and looks. It provides different interfaces for
 * different iOS versions, ensuring a great experience on both older and newer devices.
 * 
 * WHY IT EXISTS:
 * Every app needs a way for users to customize their experience. This settings screen provides
 * a centralized place for all app configuration options. It handles the complexity of different
 * iOS versions by providing enhanced features for newer iOS versions while maintaining
 * compatibility with older versions. This ensures all users get the best possible experience
 * regardless of their device.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This provides user control over app behavior and preferences
 * - Manages notification settings and permissions
 * - Handles appearance and theme customization
 * - Provides data management and privacy controls
 * - Supports different iOS versions with appropriate features
 * - Integrates with system settings and permissions
 * - Provides access to app information and support
 * 
 * WHAT IT REFERENCES:
 * - SettingsViewModel: Manages settings state and business logic
 * - NavigationCoordinator: For navigating to specific settings screens
 * - AppState: Access to app data and state
 * - NotificationSettingsView: Notification configuration screen
 * - AppearanceSettingsView: Theme and appearance settings
 * - DataManagementView: Data export, import, and privacy controls
 * 
 * WHAT REFERENCES IT:
 * - MainTabView: This is the main content of the Settings tab
 * - NavigationCoordinator: Can navigate to this view
 * - AppContainer: Provides the data and services this view needs
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. CODE ORGANIZATION:
 *    - The current file is large (400+ lines) - should be split into smaller components
 *    - Consider separating into: SettingsSections.swift, SettingsRows.swift, SettingsContent.swift
 *    - Move iOS version-specific code to separate files
 *    - Create reusable settings components
 * 
 * 2. iOS VERSION COMPATIBILITY:
 *    - The current approach uses #available - could be more sophisticated
 *    - Consider using a protocol-based approach for different iOS versions
 *    - Add support for more iOS version-specific features
 *    - Implement graceful degradation for older iOS versions
 * 
 * 3. USER EXPERIENCE IMPROVEMENTS:
 *    - The current settings could be more intuitive
 *    - Add search functionality for settings
 *    - Implement smart defaults based on user behavior
 *    - Add settings recommendations and tips
 * 
 * 4. ACCESSIBILITY IMPROVEMENTS:
 *    - The current accessibility support could be enhanced
 *    - Add better VoiceOver navigation
 *    - Implement accessibility shortcuts
 *    - Add support for different accessibility needs
 * 
 * 5. TESTING IMPROVEMENTS:
 *    - Add comprehensive unit tests for settings logic
 *    - Test different iOS versions and configurations
 *    - Add UI tests for settings interactions
 *    - Test accessibility features
 * 
 * 6. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for each settings section
 *    - Document the settings flow and relationships
 *    - Add examples of how to use different settings
 *    - Create settings flow diagrams
 * 
 * 7. PERFORMANCE OPTIMIZATIONS:
 *    - The current implementation could be optimized
 *    - Consider lazy loading for settings sections
 *    - Add caching for settings data
 *    - Implement efficient state management
 * 
 * 8. EXTENSIBILITY IMPROVEMENTS:
 *    - Make it easier to add new settings
 *    - Add support for dynamic settings
 *    - Implement settings plugins
 *    - Add support for custom settings types
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - Settings screens: Places where users can configure app preferences
 * - iOS version compatibility: Making sure the app works on different iOS versions
 * - #available: Swift feature for checking iOS version capabilities
 * - Navigation: Moving between different screens in the app
 * - State management: Keeping track of user preferences and settings
 * - Accessibility: Making sure the app is usable for everyone
 * - User experience: Making sure the app is easy and pleasant to use
 * - Backward compatibility: Making sure the app works on older devices
 * - Conditional compilation: Writing different code for different iOS versions
 * - Settings persistence: Saving user preferences so they survive app restarts
 */

import SwiftUI
import UserNotifications

// MARK: - Settings View
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @Environment(AppState.self) private var appState
    
    var body: some View {
        if #available(iOS 26.0, *) {
            iOS26SettingsContent(viewModel: viewModel)
        } else {
            LegacySettingsContent(viewModel: viewModel)
        }
    }
}

// MARK: - iOS 26 Implementation
@available(iOS 26.0, *)
private struct iOS26SettingsContent: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    @State private var scrollPosition = ScrollPosition()
    @State private var hoveredSection: SettingsSection? = nil
    
    enum SettingsSection: String, CaseIterable {
        case notifications, appearance, data, about
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
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
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadSettings()
        }
    }
}

// MARK: - iOS 26 Settings Section Container
@available(iOS 26.0, *)
private struct iOS26SettingsSection<Content: View>: View {
    let section: iOS26SettingsContent.SettingsSection
    let isHovered: Bool
    @ViewBuilder let content: Content
    
    var body: some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isHovered ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(Color(.secondarySystemGroupedBackground)))
                    .shadow(color: .black.opacity(isHovered ? 0.1 : 0.05), radius: isHovered ? 12 : 8, y: 4)
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
@available(iOS 26.0, *)
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
@available(iOS 26.0, *)
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

// MARK: - Legacy iOS 25 Implementation
private struct LegacySettingsContent: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        List {
            // Notifications section
            Section {
                NavigationLink {
                    NotificationSettingsView()
                } label: {
                    SettingsRow(
                        icon: "bell",
                        title: "Notifications",
                        subtitle: viewModel.notificationsEnabled ? "Enabled" : "Disabled"
                    )
                }
            }
            
            // Appearance section
            Section {
                NavigationLink {
                    AppearanceSettingsView()
                } label: {
                    SettingsRow(
                        icon: "moon",
                        title: "Appearance",
                        subtitle: viewModel.appearanceMode.displayName
                    )
                }
            }
            
            // Data section
            Section {
                NavigationLink {
                    DataManagementView()
                } label: {
                    SettingsRow(
                        icon: "square.and.arrow.down",
                        title: "Data & Privacy",
                        subtitle: "Export, import, or clear data"
                    )
                }
            }
            
            // About section
            Section {
                NavigationLink {
                    AboutView()
                } label: {
                    SettingsRow(
                        icon: "info.circle",
                        title: "About",
                        subtitle: "Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")"
                    )
                }
                
                Link(destination: URL(string: "https://streaksync.app/privacy")!) {
                    SettingsRow(
                        icon: "hand.raised",
                        title: "Privacy Policy",
                        subtitle: nil
                    )
                }
                
                Link(destination: URL(string: "mailto:support@streaksync.app")!) {
                    SettingsRow(
                        icon: "envelope",
                        title: "Contact Support",
                        subtitle: nil
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadSettings()
        }
    }
}

// MARK: - Settings Row (Legacy)
struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    
    var body: some View {
        HStack(spacing: 12) {
            Image.safeSystemName(icon, fallback: "gear")
                .font(.body)
                .foregroundStyle(.blue)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
    }
}

// MARK: - Preview
#Preview("Settings - iOS 26") {
    NavigationStack {
        SettingsView()
            .environmentObject(NavigationCoordinator())
    }
}


// MARK: - Preview
#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(NavigationCoordinator())
    }
}
