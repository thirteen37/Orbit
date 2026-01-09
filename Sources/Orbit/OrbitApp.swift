// OrbitApp - SwiftUI application entry point
// Menubar app for automatic window-to-space management

import SwiftUI

@main
struct OrbitApp: App {
    @StateObject private var appState = OrbitAppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(appState: appState)
        } label: {
            OrbitIcon(isActive: !appState.isPaused)
        }
    }
}
