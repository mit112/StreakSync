//
//  DashboardSearchBar.swift
//  StreakSync
//
//  Search bar component for dashboard
//

import SwiftUI

struct DashboardSearchBar: View {
    @Binding var searchText: String
    @FocusState.Binding var isSearchFieldFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("Search games...", text: $searchText)
                .focused($isSearchFieldFocused)
                .submitLabel(.search)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal)
    }
}

// MARK: - Preview
#Preview {
    struct StatefulPreview: View {
        @State var searchText = "Wordle"
        @FocusState var isSearchFieldFocused: Bool

        var body: some View {
            VStack {
                DashboardSearchBar(
                    searchText: $searchText,
                    isSearchFieldFocused: $isSearchFieldFocused
                )

                DashboardSearchBar(
                    searchText: .constant(""),
                    isSearchFieldFocused: $isSearchFieldFocused
                )
            }
            .padding()
        }
    }

    return StatefulPreview()
}

