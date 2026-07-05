import SwiftUI
import SwiftData

/// Create or edit an endorsement before signing.
struct EndorsementEditorView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \PilotProfile.lastName) private var allProfiles: [PilotProfile]

    private let builtInTemplate: EndorsementTemplateDefinition?
    private let customTemplate: EndorsementTemplate?
    private let endorsement: Endorsement?
    private let isEditing: Bool

    @State private var placeholderValues: [String: String] = [:]
    @State private var selectedStudent: PilotProfile?
    @State private var selectedInstructor: PilotProfile?
    @State private var selectedAircraft: Aircraft?
    @State private var notes = ""
    @State private var showAircraftPicker = false
    @State private var showSignature = false
    @State private var showShare = false
    @State private var exportData: Data?
    @State private var signatureData: Data?
    @State private var certificateNumber = ""
    @State private var errorMessage: String?

    init(builtInTemplate: EndorsementTemplateDefinition) {
        self.builtInTemplate = builtInTemplate
        self.customTemplate = nil
        self.endorsement = nil
        self.isEditing = false
    }

    init(customTemplate: EndorsementTemplate) {
        self.builtInTemplate = nil
        self.customTemplate = customTemplate
        self.endorsement = nil
        self.isEditing = false
    }

    init(endorsement: Endorsement) {
        self.builtInTemplate = nil
        self.customTemplate = nil
        self.endorsement = endorsement
        self.isEditing = true
    }

    private var placeholders: [String] {
        if let builtInTemplate { return builtInTemplate.placeholders }
        if let customTemplate { return customTemplate.placeholders }
        return EndorsementTemplate.extractPlaceholders(from: endorsement?.endorsementText ?? "")
    }

    private var title: String {
        builtInTemplate?.title ?? customTemplate?.title ?? endorsement?.title ?? "Endorsement"
    }

    private var renderedText: String {
        if let builtInTemplate {
            return builtInTemplate.renderedText(values: placeholderValues)
        }
        var text = customTemplate?.bodyText ?? endorsement?.endorsementText ?? ""
        for (key, value) in placeholderValues {
            text = text.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return text
    }

    var body: some View {
        Form {
            Section("Template") {
                Text(title).font(.headline)
                if let reg = builtInTemplate?.regulationReference ?? customTemplate?.regulationReference ?? endorsement?.regulationReference {
                    Text("14 CFR \(reg)").font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("People") {
                Picker("Student", selection: $selectedStudent) {
                    Text("Select Student").tag(nil as PilotProfile?)
                    ForEach(studentProfiles) { profile in
                        Text(profile.fullName).tag(profile as PilotProfile?)
                    }
                }
                Picker("Instructor (CFI)", selection: $selectedInstructor) {
                    Text("Select CFI").tag(nil as PilotProfile?)
                    ForEach(cfiProfiles) { profile in
                        Text(profile.fullName).tag(profile as PilotProfile?)
                    }
                }
            }

            if !placeholders.isEmpty {
                Section("Details") {
                    ForEach(placeholders, id: \.self) { key in
                        TextField(key.replacingOccurrences(of: "_", with: " ").capitalized,
                                  text: binding(for: key))
                    }
                }
            }

            Section("Aircraft") {
                Button { showAircraftPicker = true } label: {
                    HStack {
                        Text("Aircraft")
                        Spacer()
                        Text(selectedAircraft?.displayName ?? endorsement?.aircraftMakeModel ?? "Optional")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Endorsement Text") {
                Text(renderedText).font(.body).textSelection(.enabled)
            }

            Section("Notes") {
                TextField("Optional notes", text: $notes, axis: .vertical).lineLimit(2...4)
            }

            if isEditing, let endorsement {
                existingActions(endorsement)
            } else {
                createActions
            }
        }
        .navigationTitle(isEditing ? "Edit Endorsement" : "New Endorsement")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            if isEditing { ToolbarItem(placement: .confirmationAction) { Button("Save") { saveExisting() } } }
        }
        .sheet(isPresented: $showAircraftPicker) {
            AircraftPickerSheet(selectedAircraft: $selectedAircraft)
        }
        .sheet(isPresented: $showSignature) {
            NavigationStack {
                Form {
                    Section("Instructor Certificate (Required)") {
                        TextField("CFI Certificate Number", text: $certificateNumber)
                            .textInputAutocapitalization(.characters)
                    }
                }
                SignatureCaptureView(endorsementTitle: title) { data, _ in
                    signatureData = data
                    completeSigning()
                }
            }
        }
        .sheet(isPresented: $showShare) {
            if let exportData {
                ShareSheet(items: [temporaryFileURL(data: exportData)])
            }
        }
        .onAppear { loadDefaults() }
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var createActions: some View {
        Section {
            Button("Save as Draft") { createEndorsement(requestSignature: false) }
            Button("Request CFI Signature") { createEndorsement(requestSignature: true) }
            Button("Sign Now (CFI)") {
                prepareSignerDefaults()
                showSignature = true
            }
        }
    }

    @ViewBuilder
    private func existingActions(_ endorsement: Endorsement) -> some View {
        Section {
            if endorsement.isAwaitingSignature {
                Button("Sign as CFI") {
                    prepareSignerDefaults()
                    showSignature = true
                }
                Button("Export for Remote Signing") { exportForSigning(endorsement) }
            }
            if endorsement.isSigned {
                Button("Revoke", role: .destructive) {
                    try? environment?.endorsementService.revoke(endorsement)
                    dismiss()
                }
            }
        }
    }

    private var studentProfiles: [PilotProfile] { allProfiles }
    private var cfiProfiles: [PilotProfile] { allProfiles.filter(\.isCFI) }

    private func binding(for key: String) -> Binding<String> {
        Binding(get: { placeholderValues[key] ?? "" }, set: { placeholderValues[key] = $0 })
    }

    private func loadDefaults() {
        if let endorsement {
            selectedStudent = endorsement.student
            selectedInstructor = endorsement.instructor
            placeholderValues = endorsement.filledPlaceholders
            notes = endorsement.notes ?? ""
            certificateNumber = endorsement.signerCertificateNumber ?? selectedInstructor?.cfiCertificateNumber ?? ""
            return
        }
        selectedStudent = allProfiles.first { $0.isPrimaryProfile }
        selectedInstructor = allProfiles.first(where: { $0.isCFI })
        placeholderValues = EndorsementTemplateCatalog.defaultValues(
            student: selectedStudent, instructor: selectedInstructor, aircraft: selectedAircraft
        )
        prepareSignerDefaults()
    }

    private func prepareSignerDefaults() {
        certificateNumber = selectedInstructor?.cfiCertificateNumber ?? certificateNumber
    }

    private func createEndorsement(requestSignature: Bool) {
        guard let student = selectedStudent else { errorMessage = "Select a student."; return }
        do {
            let created: Endorsement
            if let builtInTemplate {
                created = try environment!.endorsementService.createFromBuiltInTemplate(
                    builtInTemplate, student: student, instructor: selectedInstructor,
                    values: placeholderValues, aircraft: selectedAircraft
                )
            } else if let customTemplate {
                created = try environment!.endorsementService.createFromCustomTemplate(
                    customTemplate, student: student, instructor: selectedInstructor, values: placeholderValues
                )
            } else { return }
            created.notes = notes.isEmpty ? nil : notes
            if requestSignature, let instructor = selectedInstructor {
                let package = try environment!.endorsementService.requestRemoteSignature(for: created, instructor: instructor)
                exportData = try package.encode()
                showShare = true
            } else {
                dismiss()
            }
        } catch { errorMessage = error.localizedDescription }
    }

    private func completeSigning() {
        guard let service = environment?.endorsementService else { return }
        do {
            let target: Endorsement
            if let endorsement {
                target = endorsement
                target.endorsementText = renderedText
                target.filledPlaceholders = placeholderValues
            } else {
                guard let student = selectedStudent else { return }
                if let builtInTemplate {
                    target = try service.createFromBuiltInTemplate(
                        builtInTemplate, student: student, instructor: selectedInstructor,
                        values: placeholderValues, aircraft: selectedAircraft
                    )
                } else if let customTemplate {
                    target = try service.createFromCustomTemplate(
                        customTemplate, student: student, instructor: selectedInstructor, values: placeholderValues
                    )
                } else { return }
            }
            try service.sign(
                target,
                signerName: selectedInstructor?.fullName ?? "",
                certificateNumber: certificateNumber,
                signatureData: signatureData,
                instructor: selectedInstructor
            )
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }

    private func saveExisting() {
        guard let endorsement else { return }
        endorsement.endorsementText = renderedText
        endorsement.filledPlaceholders = placeholderValues
        endorsement.notes = notes.isEmpty ? nil : notes
        endorsement.student = selectedStudent
        endorsement.instructor = selectedInstructor
        try? environment?.endorsementService.save(endorsement)
        dismiss()
    }

    private func exportForSigning(_ endorsement: Endorsement) {
        exportData = try? environment?.endorsementService.exportPackage(for: endorsement)
        showShare = true
    }

    private func temporaryFileURL(data: Data) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("AeroLog_Endorsement_\(UUID().uuidString.prefix(8)).json")
        try? data.write(to: url)
        return url
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}