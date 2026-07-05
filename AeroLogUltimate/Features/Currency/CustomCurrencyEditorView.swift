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
        .navigationTitle("Custom Currency")
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

        do {
            try environment?.currencyService.createCustomRequirement(
                name: name.trimmingCharacters(in: .whitespaces),
                lookbackDays: lookbackDays,
                requiredLandings: useLandings ? requiredLandings : nil,
                requiredNightLandings: useNightLandings ? requiredNightLandings : nil,
                requiredApproaches: useApproaches ? requiredApproaches : nil,
                requiredFlightHours: useHours ? requiredHours : nil
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}