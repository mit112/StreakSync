//
//  AddCustomGameSections.swift
//  StreakSync
//
//  Extracted sections from AddCustomGameView for better organization
//

import SwiftUI

// MARK: - iOS 26 Header Section
struct AddCustomGameHeaderSection: View {
    @Environment(\.colorScheme) private var colorScheme
    let showingSuccessHaptic: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "plus.app")
                .font(.system(size: 48))
                .foregroundStyle(StreakSyncColors.primary(for: colorScheme))
                .symbolEffect(.bounce, value: showingSuccessHaptic)
            
            Text("Add Your Favorite Puzzle")
                .font(.title3.weight(.semibold))
            
            Text("Track any daily puzzle game by adding it here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical)
    }
}

// MARK: - iOS 26 Basic Info Section
struct AddCustomGameBasicInfoSection: View {
    @Binding var gameName: String
    @Binding var gameURL: String
    @Binding var selectedCategory: GameCategory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Basic Information", systemImage: "info.circle")
                .font(.headline)
                .foregroundStyle(.primary)
            
            VStack(spacing: 16) {
                // Game Name Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Game Name")
                        .font(.subheadline.weight(.medium))
                    
                    TextField("e.g., Wordle, Connections", text: $gameName)
                        .textFieldStyle(iOS26TextFieldStyle())
                }
                
                // Game URL Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Game URL")
                        .font(.subheadline.weight(.medium))
                    
                    TextField("https://example.com", text: $gameURL)
                        .textFieldStyle(iOS26TextFieldStyle())
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
                
                // Category Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Category")
                        .font(.subheadline.weight(.medium))
                    
                    iOS26CategoryPicker(selection: $selectedCategory)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - iOS 26 Appearance Section
struct AddCustomGameAppearanceSection: View {
    @Binding var selectedIcon: String
    @Binding var selectedColor: Color
    @Binding var showingIconPicker: Bool
    @Binding var showingColorPicker: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Appearance", systemImage: "paintbrush")
                .font(.headline)
                .foregroundStyle(.primary)
            
            HStack(spacing: 20) {
                // Icon Selection
                VStack(spacing: 8) {
                    Text("Icon")
                        .font(.subheadline.weight(.medium))
                    
                    Button(action: { showingIconPicker = true }) {
                        Image.safeSystemName(selectedIcon, fallback: "gamecontroller")
                            .font(.title2)
                            .foregroundStyle(selectedColor)
                            .frame(width: 50, height: 50)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
                
                // Color Selection
                VStack(spacing: 8) {
                    Text("Color")
                        .font(.subheadline.weight(.medium))
                    
                    Button(action: { showingColorPicker = true }) {
                        Circle()
                            .fill(selectedColor)
                            .frame(width: 50, height: 50)
                            .overlay {
                                Circle()
                                    .stroke(.quaternary, lineWidth: 1)
                            }
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - iOS 26 Advanced Section
struct AddCustomGameAdvancedSection: View {
    @Binding var resultPattern: String
    @Binding var exampleResult: String
    @Binding var showingPatternHelper: Bool
    let selectedCategory: GameCategory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Advanced Settings", systemImage: "gearshape")
                .font(.headline)
                .foregroundStyle(.primary)
            
            VStack(spacing: 16) {
                // Result Pattern Field
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Result Pattern")
                            .font(.subheadline.weight(.medium))
                        
                        Spacer()
                        
                        Button("Help") {
                            showingPatternHelper = true
                        }
                        .font(.caption)
                        .foregroundStyle(.blue)
                    }
                    
                    TextField("Regex pattern to detect results", text: $resultPattern)
                        .textFieldStyle(iOS26TextFieldStyle())
                        .font(.system(.body, design: .monospaced))
                }
                
                // Example Result Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Example Result")
                        .font(.subheadline.weight(.medium))
                    
                    TextField("Paste an example result here", text: $exampleResult, axis: .vertical)
                        .textFieldStyle(iOS26TextFieldStyle())
                        .lineLimit(3...6)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - iOS 26 Preview Section
struct AddCustomGamePreviewSection: View {
    let gameName: String
    let selectedIcon: String
    let selectedColor: Color
    let selectedCategory: GameCategory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Preview", systemImage: "eye")
                .font(.headline)
                .foregroundStyle(.primary)
            
            HStack(spacing: 16) {
                // Game Icon
                Image.safeSystemName(selectedIcon, fallback: "gamecontroller")
                    .font(.title)
                    .foregroundStyle(selectedColor)
                    .frame(width: 50, height: 50)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(gameName.isEmpty ? "Game Name" : gameName)
                        .font(.headline)
                        .foregroundStyle(gameName.isEmpty ? .secondary : .primary)
                    
                    Text(selectedCategory.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        AddCustomGameHeaderSection(showingSuccessHaptic: false)
        
        AddCustomGameBasicInfoSection(
            gameName: .constant("Wordle"),
            gameURL: .constant("https://wordle.com"),
            selectedCategory: .constant(.word)
        )
        
        AddCustomGameAppearanceSection(
            selectedIcon: .constant("gamecontroller"),
            selectedColor: .constant(.blue),
            showingIconPicker: .constant(false),
            showingColorPicker: .constant(false)
        )
    }
    .padding()
}
