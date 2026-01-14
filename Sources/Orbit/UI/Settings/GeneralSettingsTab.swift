// GeneralSettingsTab - General settings (log level, launch at login)

import SwiftUI

/// General settings tab
struct GeneralSettingsTab: View {
    @ObservedObject var viewModel: SettingsViewModel
    let launchAgent: LaunchAgent

    @State private var launchAtLogin: Bool = false
    @State private var launchAgentError: String?

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        toggleLaunchAtLogin(enabled: newValue)
                    }

                if let error = launchAgentError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Section("Logging") {
                Picker("Log Level", selection: $viewModel.logLevel) {
                    ForEach(SettingsViewModel.validLogLevels, id: \.self) { level in
                        Text(level.capitalized).tag(level)
                    }
                }
                .pickerStyle(.menu)

                Text("View logs: log stream --predicate 'subsystem == \"com.orbit.Orbit\"'")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            launchAtLogin = launchAgent.isEnabled
        }
    }

    private func toggleLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try launchAgent.enable()
            } else {
                try launchAgent.disable()
            }
            launchAgentError = nil
        } catch {
            launchAgentError = error.localizedDescription
            // Revert the toggle
            launchAtLogin = launchAgent.isEnabled
        }
    }
}
