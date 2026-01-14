// MenuBarView - SwiftUI view for the menubar dropdown
// Shows status, controls, and recent activity

import SwiftUI

/// The main menubar dropdown view for Orbit
struct MenuBarView: View {
    @ObservedObject var appState: OrbitAppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Status section
            statusSection

            Divider()

            // Actions section
            actionsSection

            Divider()

            // Recent activity (if any)
            if !appState.recentMoves.isEmpty {
                recentActivitySection
                Divider()
            }

            // Footer section
            footerSection
        }
    }

    // MARK: - Sections

    private var statusSection: some View {
        Group {
            if !appState.hasAccessibility {
                Button {
                    appState.requestAccessibility()
                } label: {
                    Label("Accessibility Required", systemImage: "exclamationmark.triangle")
                }
            } else if let error = appState.configError {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Config Error", systemImage: "exclamationmark.triangle")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            } else if appState.isPaused {
                Label("Paused", systemImage: "pause.circle")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            } else {
                Label("Watching (\(appState.ruleCount) rules)", systemImage: "eye")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
        }
    }

    private var actionsSection: some View {
        Group {
            Button(appState.isPaused ? "Resume" : "Pause") {
                appState.togglePause()
            }
            .disabled(!appState.hasAccessibility)
            .keyboardShortcut("p", modifiers: .command)

            Button("Reload Config") {
                appState.reloadConfig()
            }
            .keyboardShortcut("r", modifiers: .command)

            Divider()

            Button("Settings...") {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut(",", modifiers: .command)

            Button("Open Config...") {
                appState.openConfig()
            }
            .keyboardShortcut(",", modifiers: [.command, .shift])

            Button("Open Log...") {
                appState.openLog()
            }
            .keyboardShortcut("l", modifiers: [.command, .option])
        }
    }

    private var recentActivitySection: some View {
        Menu("Recent Activity") {
            ForEach(appState.recentMoves.prefix(3)) { move in
                Text("\(move.appName) → Space \(move.targetSpace)")
            }
        }
    }

    private var footerSection: some View {
        Group {
            Button("About Orbit") {
                showAbout()
            }

            Divider()

            Button("Quit Orbit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }

    // MARK: - Actions

    private func showAbout() {
        // Create and show about panel
        let alert = NSAlert()
        alert.messageText = "Orbit"
        alert.informativeText = """
            Automatic window-to-space management for macOS.

            Orbit watches for new windows and automatically moves them to designated Spaces based on your configuration rules.

            https://github.com/user/orbit
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - Preview

#Preview {
    MenuBarView(appState: OrbitAppState())
        .frame(width: 250)
}
