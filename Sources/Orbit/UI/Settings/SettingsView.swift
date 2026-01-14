// SettingsView - Main settings window with tabs

import SwiftUI

/// Main settings window view with tabs for General, Shortcuts, and Rules
struct SettingsView: View {
    @ObservedObject var appState: OrbitAppState
    @StateObject private var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showingValidationAlert = false
    @State private var showingSaveErrorAlert = false

    init(appState: OrbitAppState) {
        self.appState = appState
        // Create view model with current config
        _viewModel = StateObject(wrappedValue: SettingsViewModel(
            configManager: appState.configManager,
            config: appState.currentConfig
        ))
    }

    var body: some View {
        TabView {
            GeneralSettingsTab(viewModel: viewModel, launchAgent: appState.launchAgent)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            ShortcutsSettingsTab(viewModel: viewModel)
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }

            RulesSettingsTab(viewModel: viewModel)
                .tabItem {
                    Label("Rules", systemImage: "list.bullet.rectangle")
                }
        }
        .frame(minWidth: 550, minHeight: 450)
        .toolbar {
            ToolbarItemGroup(placement: .confirmationAction) {
                if viewModel.hasUnsavedChanges {
                    Button("Revert") {
                        viewModel.revertChanges()
                    }
                }

                Button("Save") {
                    saveSettings()
                }
                .disabled(!viewModel.hasUnsavedChanges || viewModel.isSaving)
                .keyboardShortcut("s", modifiers: .command)
            }
        }
        .alert("Validation Errors", isPresented: $showingValidationAlert) {
            Button("OK") {
                showingValidationAlert = false
            }
        } message: {
            Text(viewModel.validationErrors.joined(separator: "\n"))
        }
        .alert("Save Error", isPresented: $showingSaveErrorAlert) {
            Button("OK") {
                viewModel.saveError = nil
                showingSaveErrorAlert = false
            }
        } message: {
            if let error = viewModel.saveError {
                Text(error)
            }
        }
    }

    private func saveSettings() {
        Task {
            do {
                try await viewModel.save()
                // Reload app state to pick up changes
                appState.reloadConfig()
            } catch {
                if !viewModel.validationErrors.isEmpty {
                    showingValidationAlert = true
                } else {
                    viewModel.saveError = error.localizedDescription
                    showingSaveErrorAlert = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView(appState: OrbitAppState())
}
