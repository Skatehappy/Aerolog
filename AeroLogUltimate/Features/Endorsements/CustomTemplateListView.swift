import SwiftUI
import SwiftData

struct CustomTemplateListView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \EndorsementTemplate.name) private var templates: [EndorsementTemplate]

    @State private var editorTemplate: EndorsementTemplate?
    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if templates.isEmpty {
                ContentUnavailableView {
                    Label("No Custom Templates", systemImage: "doc.badge.gearshape")
                } description: {
                    Text("Create reusable endorsement templates with {{placeholders}}.")
                } actions: {
                    Button("Create Template") { createNew() }
                }
            } else {
                List(templates) { template in
                    Button {
                        isCreating = false
                        editorTemplate = template
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.title)
                                .font(.headline)
                            Text(template.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !template.placeholders.isEmpty {
                                Text(template.placeholders.map { "{{\($0)}}" }.joined(separator: ", "))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .swipeActions {
                        Button("Delete", role: .destructive) {
                            do {
                                try environment?.endorsementTemplateService.delete(template)
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Custom Templates")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { createNew() } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(item: $editorTemplate) { template in
            NavigationStack {
                CustomTemplateEditorView(template: template, isNew: isCreating)
            }
        }
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func createNew() {
        let template = EndorsementTemplate(
            name: "New Template",
            title: "Custom Endorsement",
            bodyText: "I certify that {{student_name}} has met the requirements.\n\n{{details}}"
        )
        modelContext.insert(template)
        editorTemplate = template
        isCreating = true
    }
}