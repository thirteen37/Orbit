// OrbitApp - SwiftUI application entry point
// Menubar app for automatic window-to-space management

import SwiftUI

@main
struct OrbitApp: App {
    @StateObject private var appState = OrbitAppState()

    var body: some Scene {
        // Menubar dropdown
        MenuBarExtra {
            MenuBarView(appState: appState)
        } label: {
            OrbitIcon(isActive: !appState.isPaused)
        }

        // Settings window (opened via openWindow)
        Window("Orbit Settings", id: "settings") {
            SettingsView(appState: appState)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}
