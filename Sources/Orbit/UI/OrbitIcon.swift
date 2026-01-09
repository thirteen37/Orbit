// OrbitIcon - Custom menubar icon representing an eccentric orbit
// Shows an elliptical orbit path with a body at an offset position

import SwiftUI

/// Custom icon view for the menubar showing an eccentric orbit
struct OrbitIcon: View {
    /// Whether the app is currently watching (filled) or paused (outline)
    var isActive: Bool

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let orbitWidth = size.width * 0.8
            let orbitHeight = size.height * 0.5

            // Draw the elliptical orbit path
            let orbitRect = CGRect(
                x: center.x - orbitWidth / 2,
                y: center.y - orbitHeight / 2,
                width: orbitWidth,
                height: orbitHeight
            )
            let orbitPath = Path(ellipseIn: orbitRect)

            if isActive {
                context.stroke(orbitPath, with: .foreground, lineWidth: 1.2)
            } else {
                context.stroke(
                    orbitPath,
                    with: .foreground,
                    style: StrokeStyle(lineWidth: 1.0, dash: [2, 2])
                )
            }

            // Draw the orbiting body at an eccentric position (closer to one focus)
            // Position it at the rightmost point of the ellipse for visual clarity
            let bodyRadius: CGFloat = isActive ? 2.5 : 2.0
            let bodyX = center.x + orbitWidth * 0.35  // Offset toward periapsis
            let bodyY = center.y - orbitHeight * 0.3  // Slight vertical offset
            let bodyRect = CGRect(
                x: bodyX - bodyRadius,
                y: bodyY - bodyRadius,
                width: bodyRadius * 2,
                height: bodyRadius * 2
            )
            let bodyPath = Path(ellipseIn: bodyRect)

            if isActive {
                context.fill(bodyPath, with: .foreground)
            } else {
                context.stroke(bodyPath, with: .foreground, lineWidth: 1.0)
            }

            // Draw small center dot representing the focus/parent body
            let focusRadius: CGFloat = 1.5
            let focusOffset = orbitWidth * 0.15  // Offset from center (eccentricity)
            let focusX = center.x - focusOffset
            let focusRect = CGRect(
                x: focusX - focusRadius,
                y: center.y - focusRadius,
                width: focusRadius * 2,
                height: focusRadius * 2
            )
            let focusPath = Path(ellipseIn: focusRect)

            if isActive {
                context.fill(focusPath, with: .foreground)
            } else {
                context.stroke(focusPath, with: .foreground, lineWidth: 1.0)
            }
        }
        .frame(width: 18, height: 18)
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
