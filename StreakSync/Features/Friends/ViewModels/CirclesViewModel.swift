//
//  CirclesViewModel.swift
//  StreakSync
//

import Foundation

@MainActor
final class CirclesViewModel: ObservableObject {
    @Published var circles: [SocialCircle] = []
    @Published var newCircleName: String = ""
    @Published var inviteCode: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var activeCircleId: UUID?
    
    private let manager: CircleManaging?
    private let flags = BetaFeatureFlags.shared
    
    init(socialService: SocialService) {
        self.manager = socialService as? CircleManaging
        self.activeCircleId = manager?.activeCircleId
    }
    
    var isAvailable: Bool { flags.multipleCircles && manager != nil }
    
    func load() async {
        guard flags.multipleCircles, let manager else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            circles = try await manager.listCircles()
            activeCircleId = manager.activeCircleId
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func createCircle() async {
        guard flags.multipleCircles, let manager else { return }
        let name = newCircleName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "Circle name cannot be empty."
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await manager.createCircle(name: name)
            newCircleName = ""
            circles = try await manager.listCircles()
            activeCircleId = manager.activeCircleId
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func joinCircle() async {
        guard flags.multipleCircles, let manager else { return }
        let code = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await manager.joinCircle(using: code)
            inviteCode = ""
            circles = try await manager.listCircles()
            activeCircleId = manager.activeCircleId
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func leave(circle: SocialCircle) async {
        guard flags.multipleCircles, let manager else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            try await manager.leaveCircle(id: circle.id)
            circles = try await manager.listCircles()
            activeCircleId = manager.activeCircleId
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func select(circle: SocialCircle?) async {
        guard flags.multipleCircles, let manager else { return }
        isLoading = true
        defer { isLoading = false }
        await manager.selectCircle(id: circle?.id)
        activeCircleId = manager.activeCircleId
    }
}

