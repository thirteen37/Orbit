// OrbitIcon - Menubar icon showing a star with orbiting planet
// Uses PNG asset for crisp rendering at menubar size

import SwiftUI
import AppKit

/// Menubar icon view that loads from PNG asset
struct OrbitIcon: View {
    /// Whether the app is currently watching (filled) or paused (outline)
    var isActive: Bool

    var body: some View {
        Image(nsImage: menubarImage)
            .opacity(isActive ? 1.0 : 0.5)
    }

    private var menubarImage: NSImage {
        // Try to load from bundle resources
        if let resourcePath = Bundle.main.resourcePath {
            let imagePath = "\(resourcePath)/menubar-icon.png"
            if let image = NSImage(contentsOfFile: imagePath) {
                image.isTemplate = true  // Adapts to light/dark mode
                return image
            }
        }

        // Fallback: create a simple placeholder
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()
        NSColor.black.setFill()
        NSBezierPath(ovalIn: NSRect(x: 4, y: 4, width: 10, height: 10)).fill()
        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}

#Preview("Active") {
    OrbitIcon(isActive: true)
        .padding()
        .background(Color.gray.opacity(0.3))
}

#Preview("Paused") {
    OrbitIcon(isActive: false)
        .padding()
        .background(Color.gray.opacity(0.3))
}
