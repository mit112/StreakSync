//
//  EditGameResultView.swift
//  StreakSync
//
//  Sheet for editing an existing game result.
//

import SwiftUI

struct EditGameResultView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: EditGameResultViewModel

    /// Called after a successful save so the parent can react.
    var onSaved: (() -> Void)?

    init(result: GameResult, game: Game?, onSaved: (() -> Void)? = nil) {
        _viewModel = StateObject(
            wrappedValue: EditGameResultViewModel(result: result, game: game)
        )
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                contextSection
                editableFieldsSection
            }
            .navigationTitle("Edit Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveResult() }
                        .fontWeight(.semibold)
                        .disabled(!viewModel.isValid)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Context (Read-Only)

    private var contextSection: some View {
        Section {
            LabeledContent("Game", value: viewModel.original.gameName.capitalized)
            if let puzzle = viewModel.original.parsedData["puzzleNumber"] {
                LabeledContent("Puzzle", value: "#\(puzzle)")
            }
        } header: {
            Text("Details")
        }
    }

    // MARK: - Editable Fields

    private var editableFieldsSection: some View {
        Section {
            Toggle("Completed", isOn: $viewModel.completed)

            if viewModel.showsScore {
                HStack {
                    Text(viewModel.scoreLabel)
                    Spacer()
                    TextField(
                        viewModel.scorePlaceholder,
                        text: $viewModel.scoreText
                    )
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 120)
                }
            }

            DatePicker(
                "Date",
                selection: $viewModel.date,
                in: ...Date(),
                displayedComponents: .date
            )
        } header: {
            Text("Edit")
        }
    }

    // MARK: - Actions

    private func saveResult() {
        Task {
            let success = await viewModel.save(appState: appState)
            if success {
                HapticManager.shared.trigger(.buttonTap)
                onSaved?()
                dismiss()
            }
        }
    }
}
