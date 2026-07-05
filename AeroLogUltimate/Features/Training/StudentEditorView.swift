import SwiftUI

/// Create a new student and training relationship.
struct StudentEditorView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var goal: TrainingGoal = .privatePilot
    @State private var selectedSyllabusID = SyllabusCatalog.privatePilot.id
    @State private var useCustomSyllabus = false
    @State private var customSyllabi: [Syllabus] = []
    @State private var selectedCustomSyllabus: Syllabus?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Student") {
                TextField("First Name", text: $firstName)
                TextField("Last Name", text: $lastName)
            }
            Section("Training Goal") {
                Picker("Goal", selection: $goal) {
                    ForEach(TrainingGoal.allCases, id: \.self) { g in
                        Text(g.displayName).tag(g)
                    }
                }
                .onChange(of: goal) { _, newGoal in
                    if let first = SyllabusCatalog.definitions(for: newGoal).first {
                        selectedSyllabusID = first.id
                    }
                }
            }
            Section("Syllabus") {
                Toggle("Use Custom Syllabus", isOn: $useCustomSyllabus)
                if useCustomSyllabus {
                    if customSyllabi.isEmpty {
                        Text("No custom syllabi. Create one from the Syllabi screen.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Custom Syllabus", selection: $selectedCustomSyllabus) {
                            Text("Select...").tag(nil as Syllabus?)
                            ForEach(customSyllabi, id: \.persistentModelID) { syllabus in
                                Text(syllabus.name).tag(syllabus as Syllabus?)
                            }
                        }
                    }
                } else {
                    Picker("Built-in Syllabus", selection: $selectedSyllabusID) {
                        ForEach(SyllabusCatalog.definitions(for: goal), id: \.id) { def in
                            Text(def.name).tag(def.id)
                        }
                    }
                }
            }
            Section {
                Button("Create Student") { create() }
                    .fontWeight(.semibold)
                    .disabled(firstName.isEmpty || lastName.isEmpty)
            }
        }
        .navigationTitle("Add Student")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
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
        .task { loadCustomSyllabi() }
    }

    private func loadCustomSyllabi() {
        guard let instructor = try? environment?.pilotProfileService.primaryProfile() else { return }
        customSyllabi = (try? environment?.syllabusService.customSyllabi(for: instructor)) ?? []
    }

    private func create() {
        guard let service = environment?.trainingService,
              let instructor = try? service.requireCFI() else { return }
        do {
            if useCustomSyllabus, let custom = selectedCustomSyllabus {
                _ = try service.createStudent(
                    firstName: firstName,
                    lastName: lastName,
                    goal: goal,
                    instructor: instructor,
                    customSyllabus: custom
                )
            } else {
                _ = try service.createStudent(
                    firstName: firstName,
                    lastName: lastName,
                    goal: goal,
                    instructor: instructor,
                    builtInSyllabusID: selectedSyllabusID
                )
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}