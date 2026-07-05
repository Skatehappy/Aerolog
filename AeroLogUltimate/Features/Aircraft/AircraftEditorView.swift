import SwiftUI
import SwiftData

/// Create or edit an aircraft or simulator/training device.
struct AircraftEditorView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var aircraft: Aircraft
    let isNew: Bool

    @State private var validationError: String?

    var body: some View {
        Form {
            Section {
                TextField("Registration / ID", text: $aircraft.registration)
                    .textInputAutocapitalization(.characters)
                TextField("Make", text: $aircraft.make)
                TextField("Model", text: $aircraft.model)
                TextField("Type Designator (optional)", text: Binding(
                    get: { aircraft.typeDesignator ?? "" },
                    set: { aircraft.typeDesignator = $0.isEmpty ? nil : $0 }
                ))
            } header: {
                FormSectionHeader(title: "Identification", systemImage: "airplane")
            }

            Section {
                Picker("Device Type", selection: $aircraft.simulatorLevel) {
                    ForEach(SimulatorLevel.allCases, id: \.self) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                .onChange(of: aircraft.simulatorLevel) { _, level in
                    if level != .none {
                        aircraft.tracksHobbs = false
                    }
                }

                if !aircraft.isSimulator {
                    Picker("Category", selection: $aircraft.category) {
                        ForEach(AircraftCategory.allCases, id: \.self) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                    Picker("Class", selection: $aircraft.aircraftClass) {
                        ForEach(AircraftClass.allCases, id: \.self) { cls in
                            Text(cls.displayName).tag(cls)
                        }
                    }
                }
            } header: {
                FormSectionHeader(
                    title: aircraft.isSimulator ? "Simulator / Training Device" : "Classification",
                    systemImage: "tag"
                )
            }

            if !aircraft.isSimulator {
                Section("Capabilities") {
                    Toggle("Complex", isOn: $aircraft.isComplex)
                    Toggle("High Performance", isOn: $aircraft.isHighPerformance)
                    Toggle("Tailwheel", isOn: $aircraft.isTailwheel)
                    Toggle("Retractable Gear", isOn: $aircraft.isRetractable)
                    Toggle("Pressurized", isOn: $aircraft.isPressurized)
                    Toggle("Type Rating Required", isOn: $aircraft.requiresTypeRating)
                }

                Section("Time Tracking") {
                    Toggle("Track Hobbs", isOn: $aircraft.tracksHobbs)
                    Toggle("Track Tach", isOn: $aircraft.tracksTach)
                }
            }

            Section("Preferences") {
                Toggle("Favorite", isOn: $aircraft.isFavorite)
                Toggle("Active", isOn: $aircraft.isActive)
            }

            Section("Notes") {
                TextField("Performance notes, fuel burn, etc.", text: Binding(
                    get: { aircraft.performanceNotes ?? "" },
                    set: { aircraft.performanceNotes = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                .lineLimit(2...4)
                TextField("General notes", text: Binding(
                    get: { aircraft.notes ?? "" },
                    set: { aircraft.notes = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                .lineLimit(2...4)
            }
        }
        .navigationTitle(isNew ? "New Aircraft" : "Edit Aircraft")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    if isNew { modelContext.delete(aircraft) }
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .fontWeight(.semibold)
            }
        }
        .alert("Cannot Save", isPresented: .init(
            get: { validationError != nil },
            set: { if !$0 { validationError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(validationError ?? "")
        }
    }

    private func save() {
        let id = aircraft.registration.trimmingCharacters(in: .whitespaces)
        let make = aircraft.make.trimmingCharacters(in: .whitespaces)
        let model = aircraft.model.trimmingCharacters(in: .whitespaces)

        guard !id.isEmpty || (!make.isEmpty && !model.isEmpty) else {
            validationError = "Enter a registration or make/model."
            return
        }

        aircraft.registration = id
        aircraft.make = make
        aircraft.model = model
        try? environment?.aircraftService.save(aircraft)
        dismiss()
    }
}