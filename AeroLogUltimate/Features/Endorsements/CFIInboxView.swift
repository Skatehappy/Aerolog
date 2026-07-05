import SwiftUI

/// CFI view of endorsements awaiting signature.
struct CFIInboxView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var pending: [Endorsement] = []
    @State private var signingEndorsement: Endorsement?
    @State private var showSignature = false
    @State private var signatureData: Data?
    @State private var certificateNumber = ""
    @State private var signerName = ""
    @State private var errorMessage: String?
    @State private var showShare = false
    @State private var shareURL: URL?

    var body: some View {
        Group {
            if pending.isEmpty {
                ContentUnavailableView {
                    Label("No Pending Signatures", systemImage: "tray")
                } description: {
                    Text("Endorsements awaiting your signature will appear here.")
                }
            } else {
                List(pending) { endorsement in
                    VStack(alignment: .leading, spacing: 8) {
                        EndorsementRowView(endorsement: endorsement)
                        Text(endorsement.endorsementText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                        Button("Review & Sign") {
                            signingEndorsement = endorsement
                            loadSignerInfo()
                            showSignature = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Pending Signatures")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(isPresented: $showSignature) {
            NavigationStack {
                VStack {
                    if let endorsement = signingEndorsement {
                        Form {
                            Section("Instructor Certificate") {
                                TextField("CFI Certificate Number", text: $certificateNumber)
                                    .textInputAutocapitalization(.characters)
                                TextField("Signer Name", text: $signerName)
                            }
                        }
                        SignatureCaptureView(endorsementTitle: endorsement.title) { data, _ in
                            signatureData = data
                            submitSignature(endorsement)
                        }
                    }
                }
            }
        }
        .task { await refresh() }
        .refreshable { await refresh() }
        .sheet(isPresented: $showShare) {
            if let shareURL {
                ShareSheet(items: [shareURL])
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

    private func refresh() async {
        guard let profile = try? environment?.pilotProfileService.primaryProfile(),
              profile.isCFI else { return }
        pending = (try? environment?.endorsementService.pendingForInstructor(profile)) ?? []
    }

    private func loadSignerInfo() {
        if let profile = try? environment?.pilotProfileService.primaryProfile() {
            signerName = profile.fullName
            certificateNumber = profile.cfiCertificateNumber ?? ""
        }
    }

    private func submitSignature(_ endorsement: Endorsement) {
        do {
            try environment?.endorsementService.sign(
                endorsement,
                signerName: signerName,
                certificateNumber: certificateNumber,
                signatureData: signatureData,
                instructor: try environment?.pilotProfileService.primaryProfile()
            )
            if let data = try? environment?.endorsementService.exportPackage(for: endorsement) {
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("AeroLog_Signed_\(endorsement.syncID.uuidString.prefix(8)).json")
                try? data.write(to: url)
                shareURL = url
                showShare = true
            }
            Task { await refresh() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}