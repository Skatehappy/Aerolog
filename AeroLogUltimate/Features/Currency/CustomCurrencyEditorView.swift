import SwiftUI

/// Create or edit a user-defined custom currency requirement.
struct CustomCurrencyEditorView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var lookbackDays = 90
    @State private var requiredLandings = 0
    @State private var useLandings = false
    @State private var requiredNightLandings = 0
    @State private var useNightLandings = false
    @State private var requiredApproaches = 0
    @State private var useApproaches = false
    @State private var requiredHours = 0.0
    @State private var useHours = false
    @State private var errorMessage: String?

    /// Non-nil when editing an existing custom requirement; nil when creating one.
    private let editingRequirement: CurrencyRequirement?
    private var isNew: Bool { editingRequirement == nil }

    /// Create a new custom currency requirement.
    init() {
        self.editingRequirement = nil
    }

    /// Edit an existing custom currency requirement. Follows the same "existing
    /// record" convention as AircraftEditorView(aircraft:isNew:).
    init(requirement: CurrencyRequirement) {
        self.editingRequirement = requirement
        _name = State(initialValue: requirement.displayName)
        _lookbackDays = State(initialValue: requirement.lookbackDays)
        _requiredLandings = State(initialValue: requirement.requiredLandings ?? 0)
        _useLandings = State(initialValue: requirement.requiredLandings != nil)
        _requiredNightLandings = State(initialValue: requirement.requiredNightLandings ?? 0)
        _useNightLandings = State(initialValue: requirement.requiredNightLandings != nil)
        _requiredApproaches = State(initialValue: requirement.requiredApproaches ?? 0)
        _useApproaches = State(initialValue: requirement.requiredApproaches != nil)
        _requiredHours = State(initialValue: requirement.requiredFlightHours ?? 0.0)
        _useHours = State(initialValue: requirement.requiredFlightHours != nil)
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("e.g. Company SFRA Currency", text: $name)
            }

            Section("Lookback Period") {
                Stepper("\(lookbackDays) days", value: $lookbackDays, in: 7...730, step: 7)
            }

            Section("Requirements") {
                Toggle("Minimum Landings", isOn: $useLandings)
                if useLandings {
                    Stepper("\(requiredLandings) landings", value: $requiredLandings, in: 1...20)
                }
                Toggle("Minimum Night Landings", isOn: $useNightLandings)
                if useNightLandings {
                    Stepper("\(requiredNightLandings) night", value: $requiredNightLandings, in: 1...20)
                }
                Toggle("Minimum Approaches", isOn: $useApproaches)
                if useApproaches {
                    Stepper("\(requiredApproaches) approaches", value: $requiredApproaches, in: 1...20)
                }
                Toggle("Minimum Flight Hours", isOn: $useHours)
                if useHours {
                    DecimalHourField(label: "Hours", value: $requiredHours)
                }
            }
        }
        .navigationTitle(isNew ? "Custom Currency" : "Edit Custom Currency")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .fontWeight(.semibold)
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

    private func save() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Enter a name for this currency."
            return
        }
        guard useLandings || useNightLandings || useApproaches || useHours else {
            errorMessage = "Select at least one requirement criterion."
            return
        }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        do {
            if let requirement = editingRequirement {
                requirement.displayName = trimmedName
                requirement.lookbackDays = lookbackDays
                requirement.requiredLandings = useLandings ? requiredLandings : nil
                requirement.requiredNightLandings = useNightLandings ? requiredNightLandings : nil
                requirement.requiredApproaches = useApproaches ? requiredApproaches : nil
                requirement.requiredFlightHours = useHours ? requiredHours : nil
                try environment?.currencyService.saveRequirement(requirement)
            } else {
                try environment?.currencyService.createCustomRequirement(
                    name: trimmedName,
                    lookbackDays: lookbackDays,
                    requiredLandings: useLandings ? requiredLandings : nil,
                    requiredNightLandings: useNightLandings ? requiredNightLandings : nil,
                    requiredApproaches: useApproaches ? requiredApproaches : nil,
                    requiredFlightHours: useHours ? requiredHours : nil
                )
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}