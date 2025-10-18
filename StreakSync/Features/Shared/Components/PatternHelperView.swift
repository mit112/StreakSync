//
//  PatternHelperView.swift
//  StreakSync
//
//  Extracted from AddCustomGameView for better organization
//

/*
 * PATTERNHELPERVIEW - INTELLIGENT GAME RESULT PATTERN ASSISTANCE
 * 
 * WHAT THIS FILE DOES:
 * This file provides a smart helper interface that guides users through creating
 * regex patterns for automatically detecting game results. It's like a "pattern
 * creation assistant" that shows common patterns, provides examples, and allows
 * real-time testing. Think of it as the "regex pattern tutor" that makes it easy
 * for users to set up automatic game result detection without needing to know
 * complex regex syntax.
 * 
 * WHY IT EXISTS:
 * Setting up automatic game result detection requires regex patterns, which can be
 * intimidating for users who aren't familiar with regex syntax. This component
 * provides a user-friendly interface that shows common patterns, provides examples,
 * and allows real-time testing, making it much easier for users to set up their
 * custom games with automatic result detection.
 * 
 * IMPORTANCE TO APPLICATION:
 * - CRITICAL: This enables users to set up automatic game result detection
 * - Creates an intuitive interface for regex pattern creation
 * - Provides common patterns and examples for different game types
 * - Allows real-time testing of patterns with example results
 * - Makes regex pattern creation accessible to non-technical users
 * - Supports different game categories with relevant pattern examples
 * - Reduces the complexity of setting up custom games
 * 
 * WHAT IT REFERENCES:
 * - SwiftUI: For UI components and layout
 * - GameCategory: For categorizing games and providing relevant patterns
 * - TextField: For pattern and example input
 * - TestResultView: For testing pattern matching
 * - PatternExampleRow: For displaying pattern examples
 * - NavigationStack: For modal presentation
 * 
 * WHAT REFERENCES IT:
 * - AddCustomGameView: Uses this for setting up game result patterns
 * - Game customization: Uses this for configuring automatic result detection
 * - Settings views: Use this for pattern configuration
 * - Customization features: Use this for user personalization
 * 
 * CODE IMPROVEMENTS & REFACTORING SUGGESTIONS:
 * 
 * 1. PATTERN ASSISTANCE IMPROVEMENTS:
 *    - The current patterns are good but could be more comprehensive
 *    - Consider adding more pattern categories and variations
 *    - Add support for custom pattern collections
 *    - Implement smart pattern recommendations based on game type
 * 
 * 2. USER EXPERIENCE IMPROVEMENTS:
 *    - The current interface could be more user-friendly
 *    - Add support for pattern validation and error checking
 *    - Implement smart pattern suggestions
 *    - Add support for pattern tutorials and guidance
 * 
 * 3. ACCESSIBILITY IMPROVEMENTS:
 *    - The current accessibility support could be enhanced
 *    - Add better VoiceOver navigation and descriptions
 *    - Implement accessibility shortcuts
 *    - Add support for different accessibility needs
 * 
 * 4. VISUAL DESIGN IMPROVEMENTS:
 *    - The current visual design could be enhanced
 *    - Add support for more sophisticated pattern visualization
 *    - Implement smart visual adaptation for different contexts
 *    - Add support for dynamic visual elements
 * 
 * 5. PERFORMANCE OPTIMIZATIONS:
 *    - The current implementation could be optimized
 *    - Consider implementing efficient pattern testing
 *    - Add support for pattern caching and reuse
 *    - Implement smart pattern management
 * 
 * 6. TESTING IMPROVEMENTS:
 *    - Add comprehensive unit tests for pattern logic
 *    - Test different pattern scenarios and configurations
 *    - Add UI tests for pattern creation interactions
 *    - Test accessibility features
 * 
 * 7. DOCUMENTATION IMPROVEMENTS:
 *    - Add detailed documentation for pattern features
 *    - Document the different pattern types and usage patterns
 *    - Add examples of how to create different patterns
 *    - Create pattern creation guidelines
 * 
 * 8. EXTENSIBILITY IMPROVEMENTS:
 *    - Make it easier to add new pattern types
 *    - Add support for custom pattern configurations
 *    - Implement pattern plugins
 *    - Add support for third-party pattern integrations
 * 
 * LEARNING NOTES FOR BEGINNERS:
 * - Regex patterns: Text patterns used to match and extract information
 * - Pattern matching: Finding specific text patterns in strings
 * - User assistance: Helping users with complex tasks
 * - Real-time testing: Testing patterns as they're created
 * - Game customization: Allowing users to personalize their experience
 * - Text processing: Analyzing and extracting information from text
 * - User experience: Making complex tasks feel simple and intuitive
 * - Accessibility: Making sure pattern creation works for all users
 * - Visual design: Creating appealing and informative interfaces
 * - Component libraries: Collections of reusable UI components
 */

import SwiftUI

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
    PatternHelperView(
        pattern: .constant(""),
        exampleResult: .constant(""),
        category: .word
    )
}
