// RulesSettingsTab - Rules list with add/edit/delete

import SwiftUI

/// Rules settings tab with list and detail view
struct RulesSettingsTab: View {
    @ObservedObject var viewModel: SettingsViewModel

    @State private var selectedRuleIndex: Int?
    @State private var isAddingRule = false
    @State private var editingRuleIndex: Int?

    var body: some View {
        HSplitView {
            // Rules list
            VStack(alignment: .leading, spacing: 0) {
                List(selection: $selectedRuleIndex) {
                    ForEach(Array(viewModel.rules.enumerated()), id: \.offset) { index, rule in
                        RuleRowView(rule: rule, index: index)
                            .tag(index)
                    }
                    .onMove { source, destination in
                        viewModel.moveRules(from: source, to: destination)
                    }
                    .onDelete { indexSet in
                        for index in indexSet.sorted().reversed() {
                            viewModel.deleteRule(at: index)
                        }
                        selectedRuleIndex = nil
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))

                // Toolbar at bottom
                HStack {
                    Button(action: { isAddingRule = true }) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)

                    Button(action: {
                        if let index = selectedRuleIndex {
                            viewModel.deleteRule(at: index)
                            selectedRuleIndex = nil
                        }
                    }) {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.borderless)
                    .disabled(selectedRuleIndex == nil)

                    Spacer()
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
            }
            .frame(minWidth: 200, maxWidth: .infinity)

            // Rule detail panel
            if let index = selectedRuleIndex, viewModel.rules.indices.contains(index) {
                RuleDetailView(
                    rule: viewModel.rules[index],
                    onEdit: { editingRuleIndex = index }
                )
                .frame(minWidth: 200, maxWidth: .infinity)
            } else {
                VStack {
                    Spacer()
                    Text("Select a rule to view details")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(minWidth: 200, maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $isAddingRule) {
            RuleEditorSheet(
                rule: nil,
                onSave: { newRule in
                    viewModel.addRule(newRule)
                    isAddingRule = false
                },
                onCancel: { isAddingRule = false }
            )
        }
        .sheet(item: $editingRuleIndex) { index in
            RuleEditorSheet(
                rule: viewModel.rules[index],
                onSave: { updatedRule in
                    viewModel.updateRule(at: index, with: updatedRule)
                    editingRuleIndex = nil
                },
                onCancel: { editingRuleIndex = nil }
            )
        }
    }
}

// MARK: - Rule Row View

struct RuleRowView: View {
    let rule: Rule
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(rule.app)
                .font(.headline)

            HStack {
                if let contains = rule.titleContains {
                    Text("contains \"\(contains)\"")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if let pattern = rule.titlePattern {
                    Text("matches /\(pattern)/")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("any window")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("Space \(rule.space)")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Rule Detail View

struct RuleDetailView: View {
    let rule: Rule
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rule Details")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Application:")
                        .foregroundColor(.secondary)
                        .frame(minWidth: 100, alignment: .trailing)
                    Text(rule.app)
                }

                if let contains = rule.titleContains {
                    GridRow {
                        Text("Title Contains:")
                            .foregroundColor(.secondary)
                            .frame(minWidth: 100, alignment: .trailing)
                        Text(contains)
                    }
                }

                if let pattern = rule.titlePattern {
                    GridRow {
                        Text("Title Pattern:")
                            .foregroundColor(.secondary)
                            .frame(minWidth: 100, alignment: .trailing)
                        Text(pattern)
                            .font(.system(.body, design: .monospaced))
                    }
                }

                if rule.titleContains == nil && rule.titlePattern == nil {
                    GridRow {
                        Text("Title Matching:")
                            .foregroundColor(.secondary)
                            .frame(minWidth: 100, alignment: .trailing)
                        Text("Any window")
                    }
                }

                GridRow {
                    Text("Target Space:")
                        .foregroundColor(.secondary)
                        .frame(minWidth: 100, alignment: .trailing)
                    Text("Space \(rule.space)")
                }
            }

            Spacer()

            HStack {
                Spacer()
                Button("Edit...") {
                    onEdit()
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Int Identifiable Conformance

extension Int: @retroactive Identifiable {
    public var id: Int { self }
}
