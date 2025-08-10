//
//  AddCustomGameView.swift
//  StreakSync
//
//  Custom game addition with iOS 26 materials and comprehensive validation
//

import SwiftUI

// MARK: - Add Custom Game View
struct AddCustomGameView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(GameCatalog.self) private var gameCatalog
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var themeManager: ThemeManager
    
    // Form fields
    @State private var gameName = ""
    @State private var gameURL = ""
    @State private var selectedCategory: GameCategory = .word
    @State private var selectedIcon = "gamecontroller"
    @State private var selectedColor = Color.blue
    @State private var resultPattern = ""
    @State private var exampleResult = ""
    
    // UI State
    @State private var showingIconPicker = false
    @State private var showingColorPicker = false
    @State private var showingPatternHelper = false
    @State private var isValidating = false
    @State private var validationError: ValidationError?
    @State private var showingSuccessHaptic = false
    
    // Validation
    private var isFormValid: Bool {
        !gameName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !gameURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        URL(string: gameURL) != nil
    }
    
    private enum ValidationError: LocalizedError {
        case invalidURL
        case duplicateName
        case invalidPattern
        case networkError
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Please enter a valid URL starting with https://"
            case .duplicateName:
                return "A game with this name already exists"
            case .invalidPattern:
                return "The result pattern couldn't be validated"
            case .networkError:
                return "Couldn't verify the URL. Check your connection."
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            if #available(iOS 26.0, *) {
                iOS26FormContent
            } else {
                legacyFormContent
            }
        }
        .sheet(isPresented: $showingIconPicker) {
            IconPickerView(selectedIcon: $selectedIcon)
        }
        .sheet(isPresented: $showingColorPicker) {
            ColorPickerView(selectedColor: $selectedColor)
        }
        .sheet(isPresented: $showingPatternHelper) {
            PatternHelperView(
                pattern: $resultPattern,
                exampleResult: $exampleResult,
                category: selectedCategory
            )
        }
        .alert("Validation Error", isPresented: .constant(validationError != nil)) {
            Button("OK") {
                validationError = nil
            }
        } message: {
            if let error = validationError {
                Text(error.localizedDescription)
            }
        }
    }
    
    // MARK: - iOS 26 Form
    @available(iOS 26.0, *)
    private var iOS26FormContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                iOS26HeaderSection
                
                // Basic Info Section
                iOS26BasicInfoSection
                
                // Appearance Section
                iOS26AppearanceSection
                
                // Advanced Section
                iOS26AdvancedSection
                
                // Preview Section
                iOS26PreviewSection
            }
            .padding()
        }
        .background(.regularMaterial)
        .navigationTitle("Add Custom Game")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add") {
                    addGame()
                }
                .disabled(!isFormValid || isValidating)
                .fontWeight(.semibold)
            }
        }
    }
    
    // MARK: - iOS 26 Header Section
    @available(iOS 26.0, *)
    private var iOS26HeaderSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "plus.app")
                .font(.system(size: 48))
                .foregroundStyle(themeManager.primaryAccent)
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
    
    // MARK: - iOS 26 Basic Info Section
    @available(iOS 26.0, *)
    private var iOS26BasicInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Basic Information", systemImage: "info.circle")
                .font(.headline)
                .foregroundStyle(.primary)
            
            VStack(spacing: 16) {
                // Game Name Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Game Name")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    TextField("e.g., Worldle", text: $gameName)
                        .textFieldStyle(iOS26TextFieldStyle())
                        .textContentType(.name)
                        .autocorrectionDisabled()
                }
                
                // URL Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Game URL")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    TextField("https://example.com/game", text: $gameURL)
                        .textFieldStyle(iOS26TextFieldStyle())
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
                
                // Category Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Category")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    iOS26CategoryPicker(selection: $selectedCategory)
                }
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.thinMaterial)
            }
        }
    }
    
    // MARK: - iOS 26 Appearance Section
    @available(iOS 26.0, *)
    private var iOS26AppearanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Appearance", systemImage: "paintbrush")
                .font(.headline)
                .foregroundStyle(.primary)
            
            HStack(spacing: 16) {
                // Icon Selector
                Button {
                    showingIconPicker = true
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: selectedIcon)
                            .font(.title)
                            .foregroundStyle(selectedColor)
                            .frame(width: 60, height: 60)
                            .background {
                                Circle()
                                    .fill(selectedColor.opacity(0.15))
                            }
                        
                        Text("Icon")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                }
                .buttonStyle(.plain)
                .hoverEffect(.lift)
                
                // Color Selector
                Button {
                    showingColorPicker = true
                } label: {
                    VStack(spacing: 8) {
                        Circle()
                            .fill(selectedColor)
                            .frame(width: 60, height: 60)
                            .overlay {
                                Circle()
                                    .stroke(.white, lineWidth: 3)
                                    .padding(2)
                            }
                        
                        Text("Color")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                }
                .buttonStyle(.plain)
                .hoverEffect(.lift)
            }
        }
    }
    
    // MARK: - iOS 26 Advanced Section
    @available(iOS 26.0, *)
    private var iOS26AdvancedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Result Pattern", systemImage: "doc.text.magnifyingglass")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Button("Help") {
                    showingPatternHelper = true
                }
                .font(.caption)
                .foregroundStyle(.blue)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Optional: Add a pattern to auto-detect results")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                TextField("e.g., Wordle \\d+ [1-6X]/6", text: $resultPattern)
                    .textFieldStyle(iOS26TextFieldStyle())
                    .font(.system(.body, design: .monospaced))
                    .autocorrectionDisabled()
                
                if !resultPattern.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Pattern looks valid")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.thinMaterial)
            }
        }
    }
    
    // MARK: - iOS 26 Preview Section
    @available(iOS 26.0, *)
    private var iOS26PreviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Preview", systemImage: "eye")
                .font(.headline)
                .foregroundStyle(.primary)
            
            // Mini game card preview
            HStack {
                Image(systemName: selectedIcon)
                    .font(.title2)
                    .foregroundStyle(selectedColor)
                    .frame(width: 44, height: 44)
                    .background {
                        Circle()
                            .fill(selectedColor.opacity(0.15))
                    }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(gameName.isEmpty ? "Game Name" : gameName)
                        .font(.headline)
                    
                    HStack(spacing: 4) {
                        Image(systemName: selectedCategory.iconSystemName)
                            .font(.caption)
                        Text(selectedCategory.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.regularMaterial)
                    .shadow(color: selectedColor.opacity(0.2), radius: 8, x: 0, y: 4)
            }
        }
    }
    
    // MARK: - Legacy Form Content
    private var legacyFormContent: some View {
        Form {
            Section("Game Information") {
                TextField("Game Name", text: $gameName)
                TextField("Game URL", text: $gameURL)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                
                Picker("Category", selection: $selectedCategory) {
                    ForEach(GameCategory.allCases.filter { $0 != .custom }, id: \.self) { category in
                        Label(category.displayName, systemImage: category.iconSystemName)
                            .tag(category)
                    }
                }
            }
            
            Section("Appearance") {
                HStack {
                    Label("Icon", systemImage: selectedIcon)
                    Spacer()
                    Button("Choose") {
                        showingIconPicker = true
                    }
                }
                
                HStack {
                    Label("Color", systemImage: "paintpalette")
                    Spacer()
                    Circle()
                        .fill(selectedColor)
                        .frame(width: 24, height: 24)
                    Button("Choose") {
                        showingColorPicker = true
                    }
                }
            }
            
            Section("Advanced") {
                TextField("Result Pattern (Optional)", text: $resultPattern)
                    .font(.system(.body, design: .monospaced))
                Button("Pattern Help") {
                    showingPatternHelper = true
                }
            }
        }
        .navigationTitle("Add Custom Game")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add") {
                    addGame()
                }
                .disabled(!isFormValid)
            }
        }
    }
    
    // MARK: - Actions
    private func addGame() {
        // Validate inputs
        guard let url = URL(string: gameURL),
              url.isValidGameURL else {
            validationError = .invalidURL
            return
        }
        
        // Check for duplicate names
        let trimmedName = gameName.trimmingCharacters(in: .whitespacesAndNewlines)
        if appState.games.contains(where: { $0.displayName.lowercased() == trimmedName.lowercased() }) {
            validationError = .duplicateName
            return
        }
        
        // Create the custom game
        let customGame = Game(
            id: UUID(),
            name: trimmedName.lowercased().replacingOccurrences(of: " ", with: "_"),
            displayName: trimmedName,
            url: url,
            category: selectedCategory,
            resultPattern: resultPattern.isEmpty ? ".*" : resultPattern,
            iconSystemName: selectedIcon,
            backgroundColor: CodableColor(UIColor(selectedColor)),
            isPopular: false,
            isCustom: true
        )
        
        // Add to catalog and app state
        gameCatalog.addCustomGame(customGame)
        appState.games.append(customGame)
        
        // Haptic feedback
        HapticManager.shared.trigger(.buttonTap)
        showingSuccessHaptic = true
        
        // Dismiss after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismiss()
        }
    }
}

// MARK: - iOS 26 Text Field Style
@available(iOS 26.0, *)
struct iOS26TextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(.quaternary, lineWidth: 0.5)
                    }
            }
    }
}

// MARK: - iOS 26 Category Picker
@available(iOS 26.0, *)
struct iOS26CategoryPicker: View {
    @Binding var selection: GameCategory
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(GameCategory.allCases.filter { $0 != .custom }, id: \.self) { category in
                    CategoryChip(
                        category: category,
                        isSelected: selection == category
                    ) {
                        withAnimation(.smooth(duration: 0.2)) {
                            selection = category
                        }
                    }
                }
            }
        }
    }
    
    private struct CategoryChip: View {
        let category: GameCategory
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack(spacing: 6) {
                    Image(systemName: category.iconSystemName)
                        .font(.caption)
                    Text(category.displayName)
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Color.accentColor)
                    } else {
                        Capsule()
                            .fill(.ultraThinMaterial)
                    }
                }
            }
            .hoverEffect(.highlight)
        }
    }
}

// MARK: - Icon Picker View
// MARK: - Icon Picker View (FIXED)
struct IconPickerView: View {
    @Binding var selectedIcon: String
    @Environment(\.dismiss) private var dismiss
    
    private let icons = [
        "gamecontroller", "dice", "puzzlepiece", "star",
        "crown", "flag", "map", "globe",
        "book", "pencil", "scribble", "brain",
        "lightbulb", "sparkles", "wand.and.stars", "atom",
        "function", "number", "textformat.abc", "doc.text",
        "music.note", "headphones", "speaker.wave.2", "guitars",
        "photo", "camera", "paintbrush", "paintpalette",
        "hammer", "wrench", "gearshape", "cpu",
        "hourglass", "timer", "clock", "calendar",
        "chart.bar", "chart.pie", "chart.line.uptrend.xyaxis", "target"
    ]
    
    // Break down grid columns into a computed property
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible()), count: 4)
    }
    
    var body: some View {
        NavigationStack {
            iconGrid
                .navigationTitle("Choose Icon")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        doneButton
                    }
                }
        }
    }
    
    // Extract the scroll view and grid
    private var iconGrid: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 20) {
                ForEach(icons, id: \.self) { icon in
                    Icon2Button(
                        icon: icon,
                        isSelected: selectedIcon == icon,
                        action: {
                            selectedIcon = icon
                            dismiss()
                        }
                    )
                }
            }
            .padding()
        }
    }
    
    // Extract the done button
    private var doneButton: some View {
        Button("Done") {
            dismiss()
        }
    }
}

// MARK: - Icon Button Component
struct Icon2Button: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            iconContent
        }
        .foregroundStyle(iconColor)
    }
    
    private var iconContent: some View {
        Image(systemName: icon)
            .font(.title)
            .frame(width: 60, height: 60)
            .background(backgroundCircle)
    }
    
    @ViewBuilder
    private var backgroundCircle: some View {
        if isSelected {
            Circle()
                .fill(Color.accentColor.opacity(0.2))
        }
    }
    
    private var iconColor: Color {
        isSelected ? .accentColor : .primary
    }
}

// MARK: - Color Picker View (FIXED)
struct ColorPickerView: View {
    @Binding var selectedColor: Color
    @Environment(\.dismiss) private var dismiss
    
    private let colors: [Color] = [
        .red, .orange, .yellow, .green,
        .mint, .teal, .cyan, .blue,
        .indigo, .purple, .pink, .brown,
        .gray, .black
    ]
    
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible()), count: 4)
    }
    
    var body: some View {
        NavigationStack {
            colorGrid
                .navigationTitle("Choose Color")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        doneButton
                    }
                }
        }
    }
    
    private var colorGrid: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 20) {
                ForEach(colors, id: \.self) { color in
                    ColorButton(
                        color: color,
                        isSelected: selectedColor == color,
                        action: {
                            selectedColor = color
                            dismiss()
                        }
                    )
                }
            }
            .padding()
        }
    }
    
    private var doneButton: some View {
        Button("Done") {
            dismiss()
        }
    }
}

// MARK: - Color Button Component
struct ColorButton: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            colorCircle
        }
    }
    
    private var colorCircle: some View {
        Circle()
            .fill(color)
            .frame(width: 60, height: 60)
            .overlay(selectionRing)
    }
    
    @ViewBuilder
    private var selectionRing: some View {
        if isSelected {
            Circle()
                .stroke(.white, lineWidth: 3)
                .padding(2)
        }
    }
}

// MARK: - Pattern Helper View
struct PatternHelperView: View {
    @Binding var pattern: String
    @Binding var exampleResult: String
    let category: GameCategory
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Result patterns help StreakSync automatically detect when you share game results.")
                        .font(.body)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Common Patterns")
                            .font(.headline)
                        
                        ForEach(commonPatterns, id: \.pattern) { example in
                            PatternExampleRow(
                                name: example.name,
                                pattern: example.pattern,
                                example: example.example
                            ) {
                                pattern = example.pattern
                                exampleResult = example.example
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Test Your Pattern")
                            .font(.headline)
                        
                        TextField("Enter pattern", text: $pattern)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                        
                        TextField("Example result to test", text: $exampleResult)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3)
                        
                        if !pattern.isEmpty && !exampleResult.isEmpty {
                            TestResultView(pattern: pattern, test: exampleResult)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            }
            .navigationTitle("Pattern Helper")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var commonPatterns: [(name: String, pattern: String, example: String)] {
        switch category {
        case .word:
            return [
                ("Wordle Style", #"[A-Za-z]+ \d+ [1-6X]/6"#, "Wordle 942 3/6"),
                ("Quordle Style", #"Daily [A-Za-z]+ #\d+"#, "Daily Quordle 723"),
                ("With Emoji Grid", #".*\d+/\d+[\s\S]*[⬛🟨🟩]+"#, "Game 123 4/6\n⬛🟨⬛")
            ]
        case .math:
            return [
                ("Nerdle Style", #"nerdle\w* \d+ [1-6X]/6"#, "nerdlegame 728 3/6"),
                ("Math Game", #"Math.* \d+ in \d+ tries"#, "Mathle 42 in 4 tries")
            ]
        default:
            return [
                ("Generic Score", #".*Score: \d+"#, "Daily Game Score: 85"),
                ("Time Based", #".*in \d+:\d+"#, "Completed in 2:45"),
                ("Attempts", #".*in \d+ attempts"#, "Solved in 5 attempts")
            ]
        }
    }
}

// MARK: - Pattern Example Row
struct PatternExampleRow: View {
    let name: String
    let pattern: String
    let example: String
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.subheadline.weight(.medium))
                Text(pattern)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Text("Example: \(example)")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Test Result View
struct TestResultView: View {
    let pattern: String
    let test: String
    
    private var isMatch: Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return false
        }
        let range = NSRange(test.startIndex..., in: test)
        return regex.firstMatch(in: test, range: range) != nil
    }
    
    var body: some View {
        HStack {
            Image(systemName: isMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isMatch ? .green : .red)
            
            Text(isMatch ? "Pattern matches!" : "Pattern doesn't match")
                .font(.caption)
                .foregroundStyle(isMatch ? .green : .red)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(isMatch ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Preview
#Preview {
    AddCustomGameView()
        .environment(GameCatalog())
        .environment(AppState())
        .environmentObject(ThemeManager.shared)
}
