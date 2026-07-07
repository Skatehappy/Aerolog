import SwiftUI
import SwiftData

/// Edit pilot profile dates used for medical, flight review, and IPC currency.
struct PilotRecencySettingsView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<PilotProfile> { $0.isPrimaryProfile == true })
    private var primaryProfiles: [PilotProfile]

    @State private var medicalExpiration: Date = .now
    @State private var medicalClass: MedicalClass = .third
    @State private var hasMedical = false
    @State private var flightReviewDate: Date = .now
    @State private var hasFlightReview = false
    @State private var ipcDate: Date = .now
    @State private var hasIPC = false
    @State private var cfiExpiration: Date = .now
    @State private var hasCFI = false
    @State private var isCFI = false
    @State private var errorMessage: String?

    private var pilot: PilotProfile? { primaryProfiles.first }

    var body: some View {
        Form {
            Section("Medical Certificate") {
                Picker("Class", selection: $medicalClass) {
                    ForEach(MedicalClass.allCases, id: \.self) { cls in
                        Text(cls.rawValue.capitalized).tag(cls)
                    }
                }
                Toggle("Expiration Date Set", isOn: $hasMedical)
                if hasMedical {
                    DatePicker("Expires", selection: $medicalExpiration, displayedComponents: .date)
                }
            }

            Section("Flight Review (61.56)") {
                Toggle("Last Flight Review Recorded", isOn: $hasFlightReview)
                if hasFlightReview {
                    DatePicker("Date", selection: $flightReviewDate, displayedComponents: .date)
                }
            }

            Section("Instrument Proficiency Check") {
                Toggle("Last IPC Recorded", isOn: $hasIPC)
                if hasIPC {
                    DatePicker("Date", selection: $ipcDate, displayedComponents: .date)
                }
            }

            Section("CFI Certificate") {
                Toggle("I am a CFI", isOn: $isCFI)
                if isCFI {
                    Toggle("CFI Expiration Set", isOn: $hasCFI)
                    if hasCFI {
                        DatePicker("CFI Expires", selection: $cfiExpiration, displayedComponents: .date)
                    }
                }
            }
        }
        .navigationTitle("Pilot Recency")
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
        .onAppear { loadFromProfile() }
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func loadFromProfile() {
        guard let pilot else { return }
        isCFI = pilot.isCFI
        if let exp = pilot.medicalExpirationDate {
            hasMedical = true
            medicalExpiration = exp
        }
        if let cls = pilot.medicalClass { medicalClass = cls }
        if let bfr = pilot.lastFlightReviewDate {
            hasFlightReview = true
            flightReviewDate = bfr
        }
        if let ipc = pilot.lastIPCDate {
            hasIPC = true
            ipcDate = ipc
        }
        if let cfi = pilot.cfiExpirationDate {
            hasCFI = true
            cfiExpiration = cfi
        }
    }

    private func save() {
        // Surface an explicit error rather than a silent dismiss when the primary
        // profile is missing — this distinguishes "no primary profile" from a
        // persistence failure so we can tell which failure mode occurred (bug #2).
        guard let pilot else {
            errorMessage = "No primary pilot profile was found, so recency settings could not be saved. The initial profile seed may not have completed — reopen the app and try again."
            return
        }
        guard let service = environment?.pilotProfileService else {
            errorMessage = "The app environment is unavailable, so recency settings could not be saved."
            return
        }
        pilot.isCFI = isCFI
        pilot.medicalClass = medicalClass
        pilot.medicalExpirationDate = hasMedical ? medicalExpiration : nil
        pilot.lastFlightReviewDate = hasFlightReview ? flightReviewDate : nil
        pilot.lastIPCDate = hasIPC ? ipcDate : nil
        pilot.cfiExpirationDate = (isCFI && hasCFI) ? cfiExpiration : nil
        do {
            try service.update(pilot)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}