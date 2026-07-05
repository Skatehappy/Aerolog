import SwiftUI
import UniformTypeIdentifiers

/// Import a remote signing package from another device.
struct ImportSigningPackageView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var showFilePicker = false
    @State private var importedPackage: RemoteSigningPackage?
    @State private var successMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            if let package = importedPackage {
                packagePreview(package)
            } else {
                ContentUnavailableView {
                    Label("Import Package", systemImage: "square.and.arrow.down")
                } description: {
                    Text("Import an endorsement signing package shared by a student or CFI.")
                } actions: {
                    Button("Choose File") { showFilePicker = true }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("Import")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .alert("Imported", isPresented: .init(
            get: { successMessage != nil },
            set: { if !$0 { successMessage = nil; dismiss() } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(successMessage ?? "")
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

    private func packagePreview(_ package: RemoteSigningPackage) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(package.title)
                .font(.title2.weight(.bold))
            DetailRow(label: "Student", value: package.studentName)
            if package.isSigned {
                DetailRow(label: "Signed by", value: package.signerName ?? "—")
                DetailRow(label: "CFI Cert #", value: package.signerCertificateNumber ?? "—")
            } else {
                Text("Awaiting CFI signature")
                    .foregroundStyle(.orange)
            }
            Text(package.endorsementText)
                .font(.body)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Button("Apply to Logbook") {
                applyPackage(package)
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
        .padding()
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                let data = try Data(contentsOf: url)
                importedPackage = try RemoteSigningPackage.decode(from: data)
            } catch {
                errorMessage = error.localizedDescription
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func applyPackage(_ package: RemoteSigningPackage) {
        do {
            _ = try environment?.endorsementService.applySignedPackage(package)
            successMessage = package.isSigned
                ? "Signed endorsement imported successfully."
                : "Endorsement imported — awaiting signature."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}