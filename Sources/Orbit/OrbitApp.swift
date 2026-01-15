// OrbitApp - SwiftUI application entry point
// Menubar app for automatic window-to-space management

import SwiftUI
import Sparkle

@main
struct OrbitApp: App {
    @StateObject private var appState = OrbitAppState()

    /// Sparkle updater controller for automatic updates
    private let updaterController: SPUStandardUpdaterController

    init() {
        // Initialize Sparkle updater
        // startingUpdater: true starts checking for updates automatically
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var body: some Scene {
        // Menubar dropdown
        MenuBarExtra {
            MenuBarView(appState: appState, updater: updaterController.updater)
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
