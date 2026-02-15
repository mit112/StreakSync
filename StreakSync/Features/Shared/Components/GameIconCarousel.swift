//
//  GameIconCarousel.swift
//  StreakSync
//
//  Horizontally-scrollable game icon strip for leaderboard page navigation.
//

import SwiftUI

struct GameIconCarousel: View {
    let currentIndex: Int
    let totalCount: Int
    let availableGames: [Game]
    let onGameSelected: (Int) -> Void
    private let iconWidth: CGFloat = 60
    private let spacing: CGFloat = 12
    private let fixedHeight: CGFloat = 50
    @State private var scrollSelection: Int? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing) {
                    ForEach(0..<totalCount, id: \.self) { index in
                        GameIconView(
                            game: availableGames[index],
                            isActive: index == (scrollSelection ?? currentIndex)
                        )
                        .frame(width: iconWidth, height: fixedHeight)
                        .id(index)
                        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1.1 : 0.95)
                                .opacity(phase.isIdentity ? 1.0 : 0.7)
                        }
                        .onTapGesture {
                            HapticManager.shared.trigger(.pickerChange)
                            if reduceMotion {
                                scrollSelection = index
                            } else {
                                withAnimation(.easeInOut(duration: 0.25)) { scrollSelection = index }
                            }
                            onGameSelected(index)
                        }
                        .accessibilityLabel(Text("\(availableGames[index].displayName), \(index + 1) of \(max(1, totalCount))"))
                        .accessibilityAddTraits(.isButton)
                    }
                }
                .scrollTargetLayout()
            }
            .frame(height: fixedHeight)
            .contentMargins(.horizontal, max(0, geometry.size.width / 2 - iconWidth / 2), for: .scrollContent)
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrollSelection)
            .onAppear { scrollSelection = currentIndex }
            .onChange(of: currentIndex) { oldIndex, newIndex in
                guard newIndex != scrollSelection else { return }
                if reduceMotion {
                    scrollSelection = newIndex
                } else {
                    withAnimation(.easeInOut(duration: 0.25)) { scrollSelection = newIndex }
                }
            }
            .onChange(of: scrollSelection) { oldSel, newSel in
                guard let newSel, newSel != currentIndex else { return }
                onGameSelected(newSel)
            }
        }
        .frame(height: fixedHeight)
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Game \(currentIndex + 1) of \(max(1, totalCount))"))
    }
}

// MARK: - Individual Game Icon
private struct GameIconView: View {
    let game: Game
    let isActive: Bool
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 4) {
            Image.safeSystemName(gameIconName, fallback: "gamecontroller")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(isActive ? .primary : .secondary)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(isActive ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                )
            Text(game.displayName)
                .font(.caption2)
                .foregroundStyle(isActive ? .primary : .secondary)
                .lineLimit(1)
        }
        .scaleEffect(isActive ? 1.1 : 1.0)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .opacity(isActive ? 1.0 : 0.7)
        .animation(.smooth(duration: 0.3), value: isActive)
        .animation(.smooth(duration: 0.1), value: isPressed)
        .onLongPressGesture(
            minimumDuration: .infinity,
            maximumDistance: .infinity,
            pressing: { pressing in
                isPressed = pressing
            },
            perform: { }
        )
        .accessibilityLabel(Text("\(game.displayName) \(isActive ? "selected" : "" )"))
    }
    
    private var gameIconName: String {
        switch game.displayName.lowercased() {
        case "wordle": return "textformat.abc"
        case "connections": return "puzzlepiece"
        case "mini": return "square.grid.3x3"
        case "spelling bee": return "hexagon"
        case "letter boxed": return "square.stack.3d.up"
        case "vertex": return "triangle"
        case "strands": return "link"
        case "dordle": return "textformat.123"
        case "quordle": return "textformat.123"
        case "octordle": return "textformat.123"
        case "absurdle": return "textformat.abc"
        default: return "gamecontroller"
        }
    }
}
