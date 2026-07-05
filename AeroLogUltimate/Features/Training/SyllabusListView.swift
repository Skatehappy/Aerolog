import SwiftUI

/// Browse built-in and custom training syllabi.
struct SyllabusListView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var customSyllabi: [Syllabus] = []
    @State private var showCreate = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Built-in Syllabi") {
                ForEach(SyllabusCatalog.all, id: \.id) { definition in
                    NavigationLink {
                        SyllabusDetailView(definition: definition)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(definition.name)
                                .font(.headline)
                            Text("\(definition.lessons.count) lessons · \(definition.goal.displayName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section("Custom Syllabi") {
                if customSyllabi.isEmpty {
                    Text("No custom syllabi yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(customSyllabi, id: \.persistentModelID) { syllabus in
                        NavigationLink {
                            CustomSyllabusDetailView(syllabus: syllabus)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(syllabus.name)
                                    .font(.headline)
                                Text("\(syllabus.sortedLessons.count) lessons · \(syllabus.goal.displayName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deleteSyllabi)
                }
            }
        }
        .navigationTitle("Syllabi")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { showCreate = true } label: {
                    Label("New", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreate) {
            NavigationStack {
                CustomSyllabusEditorView()
            }
        }
        .task { refresh() }
        .refreshable { refresh() }
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func refresh() {
        guard let instructor = try? environment?.pilotProfileService.primaryProfile() else { return }
        customSyllabi = (try? environment?.syllabusService.customSyllabi(for: instructor)) ?? []
    }

    private func deleteSyllabi(at offsets: IndexSet) {
        for index in offsets {
            let syllabus = customSyllabi[index]
            try? environment?.syllabusService.delete(syllabus)
        }
        refresh()
    }
}