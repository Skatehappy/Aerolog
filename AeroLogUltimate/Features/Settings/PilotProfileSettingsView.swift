import SwiftUI
import SwiftData

/// Edit the primary pilot profile used for reports and exports.
struct PilotProfileSettingsView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<PilotProfile> { $0.isPrimaryProfile == true })
    private var primaryProfiles: [PilotProfile]

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var certificateNumber = ""
    @State private var homeAirport = ""
    @State private var isCFI = false
    @State private var cfiCertificateNumber = ""
    @State private var selectedRatings: Set<PilotRating> = []
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

            // C4/WS1.1: ratings drive class/category currency grouping and the
            // "training toward" vs held distinction. ASEL is the base airplane
            // rating and is assumed for every airplane pilot (not listed here).
            ForEach(PilotRating.Group.allCases, id: \.self) { group in
                let ratings = PilotRating.allCases.filter { $0.group == group }
                Section(group.rawValue) {
                    ForEach(ratings, id: \.self) { rating in
                        Toggle(rating.displayName, isOn: Binding(
                            get: { selectedRatings.contains(rating) },
                            set: { on in
                                if on { selectedRatings.insert(rating) } else { selectedRatings.remove(rating) }
                            }
                        ))
                    }
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
        selectedRatings = Set(pilot.ratings)
    }

    private func save() {
        guard let pilot, let service = environment?.pilotProfileService else { return }
        pilot.firstName = firstName
        pilot.lastName = lastName
        pilot.certificateNumber = certificateNumber.isEmpty ? nil : certificateNumber
        pilot.homeAirportICAO = homeAirport.isEmpty ? nil : homeAirport.uppercased()
        pilot.isCFI = isCFI
        pilot.cfiCertificateNumber = isCFI && !cfiCertificateNumber.isEmpty ? cfiCertificateNumber : nil
        pilot.setRatings(Array(selectedRatings))
        do {
            try service.update(pilot)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}