import SwiftUI
import SwiftData

struct CustomTemplateEditorView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var template: EndorsementTemplate
    let isNew: Bool

    var body: some View {
        Form {
            Section("Template Info") {
                TextField("Template Name", text: $template.name)
                TextField("Endorsement Title", text: $template.title)
                TextField("Regulation (optional)", text: Binding(
                    get: { template.regulationReference ?? "" },
                    set: { template.regulationReference = $0.isEmpty ? nil : $0 }
                ))
            }

            Section("Body Text") {
                Text("Use {{placeholder}} syntax for merge fields.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Endorsement text", text: $template.bodyText, axis: .vertical)
                    .lineLimit(6...16)
            }

            Section("Detected Placeholders") {
                let keys = EndorsementTemplate.extractPlaceholders(from: template.bodyText)
                if keys.isEmpty {
                    Text("No placeholders detected")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(keys, id: \.self) { key in
                        Text("{{\(key)}}")
                            .font(.caption.monospaced())
                    }
                }
            }
        }
        .navigationTitle(isNew ? "New Template" : "Edit Template")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    if isNew { modelContext.delete(template) }
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .fontWeight(.semibold)
            }
        }
    }

    private func save() {
        try? environment?.endorsementTemplateService.save(template)
        dismiss()
    }
}