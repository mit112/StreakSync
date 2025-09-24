//
//  AppearanceSettingsView.swift
//  StreakSync
//
//  Appearance settings with theme selection
//

import SwiftUI

// MARK: - Appearance Settings View
struct AppearanceSettingsView: View {
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @Environment(\.colorScheme) private var currentColorScheme
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            // Theme Selection Section
            Section {
                ForEach(AppearanceMode.allCases) { mode in
                    AppearanceOptionRow(
                        mode: mode,
                        isSelected: appearanceMode == mode
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appearanceMode = mode
                        }
                    }
                }
            } header: {
                Text("Theme")
            } footer: {
                Text("Choose how \(Bundle.main.displayName ?? "StreakSync") appears. System will follow your device settings.")
            }
            
            // Preview Section
            Section {
                AppearancePreviewCard(colorScheme: currentColorScheme)
            } header: {
                Text("Preview")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Appearance Option Row
private struct AppearanceOptionRow: View {
    let mode: AppearanceMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: mode.iconName)
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)
                    .frame(width: 30)
                
                Text(mode.displayName)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Appearance Preview Card
private struct AppearancePreviewCard: View {
    let colorScheme: ColorScheme
    
    var body: some View {
        VStack(spacing: Spacing.md) {
            // Current mode indicator
            HStack {
                Image(systemName: colorScheme == .dark ? "moon.fill" : "sun.max.fill")
                    .font(.title2)
                Text("Currently in \(colorScheme == .dark ? "Dark" : "Light") Mode")
                    .font(.headline)
            }
            .foregroundStyle(.primary)
            
            // Sample UI elements
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Sample Text")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: Spacing.sm) {
                    SampleColorBox(
                        color: Color(.systemBackground),
                        label: "Background"
                    )
                    SampleColorBox(
                        color: Color(.secondarySystemBackground),
                        label: "Secondary"
                    )
                    SampleColorBox(
                        color: Color.accentColor,
                        label: "Accent"
                    )
                }
                
                HStack(spacing: Spacing.sm) {
                    SampleColorBox(
                        color: Color(.label),
                        label: "Text"
                    )
                    SampleColorBox(
                        color: Color(.secondaryLabel),
                        label: "Secondary"
                    )
                    SampleColorBox(
                        color: Color(.tertiaryLabel),
                        label: "Tertiary"
                    )
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Sample Color Box
private struct SampleColorBox: View {
    let color: Color
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 6)
                .fill(color)
                .frame(height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color(.separator), lineWidth: 0.5)
                )
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview
#Preview("Light Mode") {
    NavigationStack {
        AppearanceSettingsView()
    }
    .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    NavigationStack {
        AppearanceSettingsView()
    }
    .preferredColorScheme(.dark)
}
