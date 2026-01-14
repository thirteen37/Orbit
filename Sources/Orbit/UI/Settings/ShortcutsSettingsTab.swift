// ShortcutsSettingsTab - Keyboard shortcuts configuration

import SwiftUI

/// Shortcuts settings tab
struct ShortcutsSettingsTab: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section {
                Text("Enter shortcuts that match your System Settings > Keyboard > Shortcuts > Mission Control")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Direct Space Jumps") {
                ForEach(1...9, id: \.self) { space in
                    HStack {
                        Text("Space \(space):")
                            .frame(width: 80, alignment: .trailing)
                        TextField("e.g., ctrl+\(space)", text: shortcutBinding(forSpace: space))
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 120, maxWidth: 200)
                    }
                }
            }

            Section("Relative Movement") {
                HStack {
                    Text("Space Left:")
                        .frame(width: 80, alignment: .trailing)
                    TextField("e.g., ctrl+left", text: spaceLeftBinding())
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 120, maxWidth: 200)
                }

                HStack {
                    Text("Space Right:")
                        .frame(width: 80, alignment: .trailing)
                    TextField("e.g., ctrl+right", text: spaceRightBinding())
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 120, maxWidth: 200)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    /// Create a binding for a direct jump shortcut
    private func shortcutBinding(forSpace space: Int) -> Binding<String> {
        Binding(
            get: { viewModel.shortcuts.directJumps[space] ?? "" },
            set: { newValue in
                if newValue.isEmpty {
                    viewModel.shortcuts.directJumps.removeValue(forKey: space)
                } else {
                    viewModel.shortcuts.directJumps[space] = newValue
                }
                // Trigger change detection by reassigning
                viewModel.shortcuts = viewModel.shortcuts
            }
        )
    }

    /// Create a binding for spaceLeft
    private func spaceLeftBinding() -> Binding<String> {
        Binding(
            get: { viewModel.shortcuts.spaceLeft ?? "" },
            set: { newValue in
                viewModel.shortcuts.spaceLeft = newValue.isEmpty ? nil : newValue
            }
        )
    }

    private func spaceRightBinding() -> Binding<String> {
        Binding(
            get: { viewModel.shortcuts.spaceRight ?? "" },
            set: { newValue in
                viewModel.shortcuts.spaceRight = newValue.isEmpty ? nil : newValue
            }
        )
    }
}
