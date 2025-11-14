#!/usr/bin/env swift

import Foundation
import AppKit

// Simple icon generator for StreakSync
// Creates a basic app icon with a flame/streak symbol

func createIcon(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    
    // Background gradient (blue to purple)
    let gradient = NSGradient(colors: [
        NSColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1.0),  // Blue
        NSColor(red: 0.6, green: 0.3, blue: 0.9, alpha: 1.0)   // Purple
    ])
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    gradient?.draw(in: rect, angle: 135)
    
    // Draw a flame/streak symbol
    let context = NSGraphicsContext.current!.cgContext
    context.setFillColor(NSColor.white.cgColor)
    
    // Draw flame shape (simplified)
    let centerX = CGFloat(size) / 2
    let centerY = CGFloat(size) / 2
    let flameSize = CGFloat(size) * 0.4
    
    // Create flame path
    let path = NSBezierPath()
    path.move(to: CGPoint(x: centerX, y: centerY - flameSize * 0.3))
    path.curve(to: CGPoint(x: centerX - flameSize * 0.3, y: centerY + flameSize * 0.2),
               controlPoint1: CGPoint(x: centerX - flameSize * 0.1, y: centerY - flameSize * 0.1),
               controlPoint2: CGPoint(x: centerX - flameSize * 0.2, y: centerY + flameSize * 0.1))
    path.curve(to: CGPoint(x: centerX, y: centerY + flameSize * 0.5),
               controlPoint1: CGPoint(x: centerX - flameSize * 0.1, y: centerY + flameSize * 0.3),
               controlPoint2: CGPoint(x: centerX, y: centerY + flameSize * 0.4))
    path.curve(to: CGPoint(x: centerX + flameSize * 0.3, y: centerY + flameSize * 0.2),
               controlPoint1: CGPoint(x: centerX, y: centerY + flameSize * 0.4),
               controlPoint2: CGPoint(x: centerX + flameSize * 0.1, y: centerY + flameSize * 0.3))
    path.curve(to: CGPoint(x: centerX, y: centerY - flameSize * 0.3),
               controlPoint1: CGPoint(x: centerX + flameSize * 0.2, y: centerY + flameSize * 0.1),
               controlPoint2: CGPoint(x: centerX + flameSize * 0.1, y: centerY - flameSize * 0.1))
    path.close()
    
    path.fill()
    
    image.unlockFocus()
    return image
}

func saveIcon(size: Int, filename: String) {
    let icon = createIcon(size: size)
    guard let tiffData = icon.tiffRepresentation,
          let bitmapImage = NSBitmapImageRep(data: tiffData),
          let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG for \(filename)")
        return
    }
    
    let url = URL(fileURLWithPath: filename)
    try? pngData.write(to: url)
    print("Created: \(filename) (\(size)x\(size))")
}

// Generate all required icon sizes
let iconSizes = [
    (20, 2, "AppIcon-20x20@2x.png"),      // 40x40
    (20, 3, "AppIcon-20x20@3x.png"),      // 60x60
    (29, 2, "AppIcon-29x29@2x.png"),      // 58x58
    (29, 3, "AppIcon-29x29@3x.png"),      // 87x87
    (40, 2, "AppIcon-40x40@2x.png"),      // 80x80
    (40, 3, "AppIcon-40x40@3x.png"),      // 120x120 (REQUIRED)
    (60, 2, "AppIcon-60x60@2x.png"),      // 120x120 (REQUIRED)
    (60, 3, "AppIcon-60x60@3x.png"),      // 180x180
    (20, 1, "AppIcon-20x20@1x.png"),      // 20x20 (iPad)
    (20, 2, "AppIcon-20x20@2x-ipad.png"), // 40x40 (iPad)
    (29, 1, "AppIcon-29x29@1x.png"),      // 29x29 (iPad)
    (29, 2, "AppIcon-29x29@2x-ipad.png"), // 58x58 (iPad)
    (40, 1, "AppIcon-40x40@1x.png"),      // 40x40 (iPad)
    (40, 2, "AppIcon-40x40@2x-ipad.png"), // 80x80 (iPad)
    (76, 1, "AppIcon-76x76@1x.png"),      // 76x76 (iPad)
    (76, 2, "AppIcon-76x76@2x.png"),      // 152x152 (REQUIRED - iPad)
    (83.5, 2, "AppIcon-83.5x83.5@2x.png"), // 167x167 (iPad Pro)
    (1024, 1, "AppIcon-1024x1024.png")     // 1024x1024 (App Store)
]

let outputDir = "./StreakSync/Assets.xcassets/AppIcon.appiconset/"

// Create directory if it doesn't exist
let fileManager = FileManager.default
if !fileManager.fileExists(atPath: outputDir) {
    try? fileManager.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
}

print("Generating app icons...")
print("Output directory: \(outputDir)")

for (baseSize, scale, filename) in iconSizes {
    let actualSize = Int(Double(baseSize) * Double(scale))
    let filepath = outputDir + filename
    saveIcon(size: actualSize, filename: filepath)
}

print("\n✅ All icons generated!")
print("Next steps:")
print("1. Open Xcode")
print("2. Select AppIcon in Assets.xcassets")
print("3. Drag the generated icons to their respective slots")
print("4. Or the icons should already be in place if filenames match")

