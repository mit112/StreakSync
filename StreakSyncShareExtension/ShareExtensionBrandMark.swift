//
//  ShareExtensionBrandMark.swift
//  StreakSyncShareExtension
//
//  Extension-local rendering of the approved StreakSync brand mark.
//

import SwiftUI

struct ShareExtensionBrandMark: View {
    let size: CGFloat

    private enum BrandColor {
        static let primary = Color(.sRGB, red: 22 / 255, green: 139 / 255, blue: 250 / 255)
        static let streak = Color(.sRGB, red: 1, green: 159 / 255, blue: 10 / 255)
        static let success = Color(.sRGB, red: 12 / 255, green: 166 / 255, blue: 120 / 255)
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
            let background = CGRect(
                x: (canvasSize.width - markSize) / 2,
                y: (canvasSize.height - markSize) / 2,
                width: markSize,
                height: markSize
            )
            context.fill(
                RoundedRectangle(cornerRadius: markSize * 0.24).path(in: background),
                with: .color(BrandColor.primary)
            )

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
                    let tileColor = isLiftedTile ? BrandColor.streak : BrandColor.primary.opacity(0.58)

                    context.fill(
                        RoundedRectangle(cornerRadius: cornerRadius).path(in: tileRect),
                        with: .color(tileColor)
                    )
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
