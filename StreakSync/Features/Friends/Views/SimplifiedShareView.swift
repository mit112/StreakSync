//
//  SimplifiedShareView.swift
//  StreakSync
//
//  Lightweight share flow for the beta friends experience.
//

import SwiftUI
import UIKit

struct SimplifiedShareView: View {
    let socialService: SocialService
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var betaFlags: BetaFeatureFlags

    @State private var shareLink: URL?
    @State private var isLoadingLink = false
    @State private var showShareSheet = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue)

                VStack(spacing: 6) {
                    Text("Invite Friends")
                        .font(.title2).bold()
                    Text("Share this link so friends can see your daily scores.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                if isLoadingLink {
                    ProgressView("Generating link…")
                        .progressViewStyle(.circular)
                } else if let link = shareLink {
                    VStack(spacing: 12) {
                        Button {
                            showShareSheet = true
                        } label: {
                            Label("Share Invite Link", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        Text(link.absoluteString)
                            .font(.footnote.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .multilineTextAlignment(.center)
                            .padding(8)
                            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

                        Button("Copy Link") {
                            UIPasteboard.general.string = link.absoluteString
                            HapticManager.shared.trigger(.achievement)
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    VStack(spacing: 12) {
                        Text(errorMessage ?? "Invite links require iCloud syncing.")
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Button("Try Again") {
                            Task { await loadShareLink() }
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Invite Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadShareLink()
            }
            .sheet(isPresented: $showShareSheet) {
                if let link = shareLink {
                    ShareSheet(activityItems: [link])
                        .ignoresSafeArea()
                }
            }
        }
    }

    private func loadShareLink() async {
        guard betaFlags.shareLinks else {
            errorMessage = "Sharing is disabled in this beta build."
            return
        }
        guard let cloudService = socialService as? CloudKitSocialService else {
            errorMessage = "Invite links require iCloud syncing."
            return
        }
        isLoadingLink = true
        errorMessage = nil
        defer { isLoadingLink = false }
        do {
            if let url = try await cloudService.ensureFriendsShareURL() {
                shareLink = url
                BetaMetrics.track(.inviteLinkCreated)
            } else {
                errorMessage = "Unable to create a share link right now."
                BetaMetrics.track(.inviteLinkFailed, properties: ["reason": "missing_url"])
            }
        } catch {
            errorMessage = error.localizedDescription
            BetaMetrics.track(.inviteLinkFailed, properties: ["reason": error.localizedDescription])
        }
    }
}

