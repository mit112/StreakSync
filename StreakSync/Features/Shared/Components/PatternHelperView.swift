//
//  PatternHelperView.swift
//  StreakSync
//
//  Extracted from AddCustomGameView for better organization
//

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
