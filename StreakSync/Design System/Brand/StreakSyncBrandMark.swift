//
//  StreakSyncBrandMark.swift
//  StreakSync
//
//  The approved compact grid mark for StreakSync.
//

import SwiftUI

struct StreakSyncBrandMark: View {
    let size: CGFloat
    let showsBackground: Bool
    let accessibilityLabel: String?

    init(
        size: CGFloat,
        showsBackground: Bool = true,
        accessibilityLabel: String? = "StreakSync"
    ) {
        self.size = size
        self.showsBackground = showsBackground
        self.accessibilityLabel = accessibilityLabel
    }

    var body: some View {
        Canvas { context, canvasSize in
            let markSize = min(canvasSize.width, canvasSize.height)
            let tileSize = markSize * 0.18
            let spacing = markSize * 0.075
            let originX = (canvasSize.width - (tileSize * 3 + spacing * 2)) / 2
            let topY = (canvasSize.height - (tileSize * 3 + spacing * 2)) / 2 + markSize * 0.055
            let liftedTopY = topY - tileSize * 0.75
            let cornerRadius = tileSize * 0.28

            if showsBackground {
                let background = CGRect(
                    x: (canvasSize.width - markSize) / 2,
                    y: (canvasSize.height - markSize) / 2,
                    width: markSize,
                    height: markSize
                )
                context.fill(
                    RoundedRectangle(cornerRadius: markSize * 0.24).path(in: background),
                    with: .color(StreakSyncBrand.primary)
                )
            }

            for row in 0..<3 {
                for column in 0..<3 {
                    let isLiftedTile = row == 0 && column == 1
                    let tileY = isLiftedTile
                        ? liftedTopY
                        : topY + CGFloat(row) * (tileSize + spacing)
                    let tileRect = CGRect(
                        x: originX + CGFloat(column) * (tileSize + spacing),
                        y: tileY,
                        width: tileSize,
                        height: tileSize
                    )
                    let tileColor = isLiftedTile
                        ? StreakSyncBrand.streak
                        : showsBackground
                            ? StreakSyncBrand.primary.opacity(0.58)
                            : StreakSyncBrand.primary

                    context.fill(
                        RoundedRectangle(cornerRadius: cornerRadius).path(in: tileRect),
                        with: .color(tileColor)
                    )
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel ?? "")
        .accessibilityAddTraits(.isImage)
        .accessibilityHidden(accessibilityLabel == nil)
    }
}

#Preview("Light") {
    HStack(alignment: .bottom, spacing: 20) {
        StreakSyncBrandMark(size: 44)
        StreakSyncBrandMark(size: 64)
        StreakSyncBrandMark(size: 128)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Dark") {
    HStack(alignment: .bottom, spacing: 20) {
        StreakSyncBrandMark(size: 44)
        StreakSyncBrandMark(size: 64)
        StreakSyncBrandMark(size: 128)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
    .preferredColorScheme(.dark)
}
