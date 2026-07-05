import SwiftUI
import SwiftData

/// Edit the primary pilot profile used for reports and exports.
struct PilotProfileSettingsView: View {
    @Environment(\.appEnvironment) private var environment

    @Query(filter: #Predicate<PilotProfile> { $0.isPrimaryProfile == true })
    private var primaryProfiles: [PilotProfile]

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var certificateNumber = ""
    @State private var homeAirport = ""
    @State private var isCFI = false
    @State private var cfiCertificateNumber = ""
    @State private var errorMessage: String?

    private var pilot: PilotProfile? { primaryProfiles.first }

    var body: some View {
        Form {
            Section("Identity") {
                TextField("First Name", text: $firstName)
                TextField("Last Name", text: $lastName)
                TextField("Certificate Number", text: $certificateNumber)
                    .textInputAutocapitalization(.characters)
            }

            Section("Home Base") {
                TextField("Home Airport ICAO", text: $homeAirport)
                    .textInputAutocapitalization(.characters)
            }

            Section("Instructor") {
                Toggle("I am a CFI", isOn: $isCFI)
                if isCFI {
                    TextField("CFI Certificate Number", text: $cfiCertificateNumber)
                        .textInputAutocapitalization(.characters)
                }
            }

            Section {
                Button("Save Profile") {
                    save()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Pilot Profile")
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
        firstName = pilot.firstName
        lastName = pilot.lastName
        certificateNumber = pilot.certificateNumber ?? ""
        homeAirport = pilot.homeAirportICAO ?? ""
        isCFI = pilot.isCFI
        cfiCertificateNumber = pilot.cfiCertificateNumber ?? ""
    }

    private func save() {
        guard let pilot, let service = environment?.pilotProfileService else { return }
        pilot.firstName = firstName
        pilot.lastName = lastName
        pilot.certificateNumber = certificateNumber.isEmpty ? nil : certificateNumber
        pilot.homeAirportICAO = homeAirport.isEmpty ? nil : homeAirport.uppercased()
        pilot.isCFI = isCFI
        pilot.cfiCertificateNumber = isCFI && !cfiCertificateNumber.isEmpty ? cfiCertificateNumber : nil
        do {
            try service.update(pilot)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}