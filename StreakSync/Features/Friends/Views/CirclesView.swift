//
//  CirclesView.swift
//  StreakSync
//

import SwiftUI

struct CirclesView: View {
    @StateObject private var viewModel: CirclesViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var betaFlags: BetaFeatureFlags
    let showsCloseButton: Bool
    
    init(socialService: SocialService, showsCloseButton: Bool = true) {
        _viewModel = StateObject(wrappedValue: CirclesViewModel(socialService: socialService))
        self.showsCloseButton = showsCloseButton
    }
    
    var body: some View {
        Group {
            if viewModel.isAvailable {
                List {
                    createSection
                    joinSection
                    circlesSection
                }
                .listStyle(.insetGrouped)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "person.3")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text(betaFlags.multipleCircles ? "Circles require the latest social features. Enable iCloud to continue." : "Circles are disabled in this beta build.")
                        .multilineTextAlignment(.center)
                        .font(.headline)
                    if showsCloseButton {
                        Button("Close") { dismiss() }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Circles")
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .alert(isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { _ in viewModel.errorMessage = nil })) {
            Alert(title: Text("Circles"), message: Text(viewModel.errorMessage ?? ""), dismissButton: .default(Text("OK")))
        }
        .task {
            await viewModel.load()
        }
    }
}

private extension CirclesView {
    var createSection: some View {
        Section("Create a circle") {
            TextField("Family, coworkers...", text: $viewModel.newCircleName)
                .textInputAutocapitalization(.words)
            Button("Create") {
                Task { await viewModel.createCircle() }
            }
            .disabled(viewModel.newCircleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
    
    var joinSection: some View {
        Section("Join via invite code") {
            TextField("Paste invite code (UUID)", text: $viewModel.inviteCode)
                .textInputAutocapitalization(.none)
                .disableAutocorrection(true)
            Button("Join Circle") {
                Task { await viewModel.joinCircle() }
            }
            .disabled(viewModel.inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
    
    var circlesSection: some View {
        Section("Your circles") {
            Button {
                Task { await viewModel.select(circle: nil) }
            } label: {
                HStack {
                    Text("All Friends")
                    Spacer()
                    if viewModel.activeCircleId == nil {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
            .buttonStyle(.plain)
            if viewModel.circles.isEmpty {
                Text("No circles yet. Create one or join via an invite code.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.circles) { circle in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(circle.name)
                                .font(.headline)
                            Text("\(circle.members.count) members")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if viewModel.activeCircleId == circle.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                        Menu {
                            Button("Set Active") {
                                Task { await viewModel.select(circle: circle) }
                            }
                            Button(role: .destructive) {
                                Task { await viewModel.leave(circle: circle) }
                            } label: {
                                Label("Leave Circle", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                        }
                    }
                }
            }
        }
    }
}

