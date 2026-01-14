// RuleEditorSheet - Add/edit rule modal sheet

import SwiftUI

/// Sheet for adding or editing a rule
struct RuleEditorSheet: View {
    let rule: Rule?
    let onSave: (Rule) -> Void
    let onCancel: () -> Void

    @State private var app: String
    @State private var titleMatchType: TitleMatchType
    @State private var titleContains: String
    @State private var titlePattern: String
    @State private var space: Int
    @State private var validationError: String?

    enum TitleMatchType: String, CaseIterable {
        case none = "Any title"
        case contains = "Title contains"
        case pattern = "Title matches regex"
    }

    init(rule: Rule?, onSave: @escaping (Rule) -> Void, onCancel: @escaping () -> Void) {
        self.rule = rule
        self.onSave = onSave
        self.onCancel = onCancel

        // Initialize state from existing rule or defaults
        _app = State(initialValue: rule?.app ?? "")
        _titleContains = State(initialValue: rule?.titleContains ?? "")
        _titlePattern = State(initialValue: rule?.titlePattern ?? "")
        _space = State(initialValue: rule?.space ?? 1)

        if rule?.titlePattern != nil {
            _titleMatchType = State(initialValue: .pattern)
        } else if rule?.titleContains != nil {
            _titleMatchType = State(initialValue: .contains)
        } else {
            _titleMatchType = State(initialValue: .none)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text(rule == nil ? "Add Rule" : "Edit Rule")
                .font(.headline)
                .padding()

            Divider()

            // Form
            Form {
                Section("Application") {
                    TextField("Name or Bundle ID", text: $app)
                        .textFieldStyle(.roundedBorder)

                    Text("e.g., \"Google Chrome\" or \"com.google.Chrome\"")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Title Matching") {
                    Picker("Match Type", selection: $titleMatchType) {
                        ForEach(TitleMatchType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    switch titleMatchType {
                    case .none:
                        Text("All windows from this app will match")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    case .contains:
                        TextField("Text to match", text: $titleContains)
                            .textFieldStyle(.roundedBorder)
                        Text("Case-insensitive substring match")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    case .pattern:
                        TextField("Regex pattern", text: $titlePattern)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                        Text("Swift regex syntax, e.g., ^dev-.*")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Target Space") {
                    Stepper("Space \(space)", value: $space, in: 1...16)
                }
            }
            .formStyle(.grouped)

            // Validation error
            if let error = validationError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }

            Divider()

            // Buttons
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(rule == nil ? "Add" : "Save") {
                    saveRule()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(app.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(width: 450, height: 420)
    }

    private func saveRule() {
        let trimmedApp = app.trimmingCharacters(in: .whitespaces)

        // Build rule based on title match type
        let newRule: Rule
        switch titleMatchType {
        case .none:
            newRule = Rule(app: trimmedApp, space: space)
        case .contains:
            newRule = Rule(
                app: trimmedApp,
                titleContains: titleContains.isEmpty ? nil : titleContains,
                space: space
            )
        case .pattern:
            newRule = Rule(
                app: trimmedApp,
                titlePattern: titlePattern.isEmpty ? nil : titlePattern,
                space: space
            )
        }

        // Validate
        do {
            try newRule.validate()
            validationError = nil
            onSave(newRule)
        } catch let error as RuleValidationError {
            validationError = describeValidationError(error)
        } catch {
            validationError = error.localizedDescription
        }
    }

    private func describeValidationError(_ error: RuleValidationError) -> String {
        switch error {
        case .emptyAppName:
            return "Application name cannot be empty"
        case .invalidSpaceNumber(let n):
            return "Invalid space number: \(n)"
        case .invalidRegexPattern(let pattern):
            return "Invalid regex pattern: \(pattern)"
        case .bothTitleMatchersSpecified:
            return "Cannot specify both contains and pattern"
        }
    }
}
