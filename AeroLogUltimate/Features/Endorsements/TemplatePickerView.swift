import SwiftUI
import SwiftData

/// Choose a built-in or custom endorsement template.
struct TemplatePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \EndorsementTemplate.name) private var customTemplates: [EndorsementTemplate]

    @State private var selectedBuiltIn: EndorsementTemplateDefinition?
    @State private var selectedCustom: EndorsementTemplate?
    @State private var showEditor = false

    var body: some View {
        List {
            Section("FAA Standard Endorsements") {
                ForEach(EndorsementTemplateCatalog.all) { template in
                    Button {
                        selectedBuiltIn = template
                        selectedCustom = nil
                        showEditor = true
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(template.regulationReference)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Custom Templates") {
                if customTemplates.isEmpty {
                    Text("No custom templates yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(customTemplates) { template in
                        Button {
                            selectedCustom = template
                            selectedBuiltIn = nil
                            showEditor = true
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.title)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(template.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Choose Template")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                if let builtIn = selectedBuiltIn {
                    EndorsementEditorView(builtInTemplate: builtIn)
                } else if let custom = selectedCustom {
                    EndorsementEditorView(customTemplate: custom)
                }
            }
        }
    }
}