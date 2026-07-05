import SwiftUI

/// Read-only endorsement detail with signature display and export.
struct EndorsementDetailView: View {
    @Environment(\.appEnvironment) private var environment

    let endorsement: Endorsement

    @State private var showEditor = false
    @State private var showShare = false
    @State private var shareURL: URL?
    @State private var showDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                peopleSection
                textSection
                if endorsement.isSigned { signatureSection }
                if let notes = endorsement.notes, !notes.isEmpty {
                    notesSection(notes)
                }
                metadataSection
            }
            .padding()
        }
        .navigationTitle(endorsement.title)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                EndorsementEditorView(endorsement: endorsement)
            }
        }
        .sheet(isPresented: $showShare) {
            if let shareURL {
                ShareSheet(items: [shareURL])
            }
        }
        .deleteConfirmation(
            title: "Delete Endorsement?",
            message: "This endorsement will be removed from your history.",
            isPresented: $showDeleteConfirm,
            onConfirm: {
                try? environment?.endorsementService.delete(endorsement)
            }
        )
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                EndorsementStatusBadge(status: endorsement.status)
                if let reg = endorsement.regulationReference {
                    Text("14 CFR \(reg)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let date = endorsement.issuedDate ?? endorsement.signedAt {
                VStack(alignment: .trailing) {
                    Text("Issued")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(date, format: .dateTime.month(.abbreviated).day().year())
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var peopleSection: some View {
        DetailSection(title: "People", icon: "person.2") {
            DetailRow(label: "Student", value: endorsement.displayStudentName)
            DetailRow(label: "Instructor", value: endorsement.displayInstructorName)
            if let cert = endorsement.signerCertificateNumber {
                DetailRow(label: "CFI Certificate #", value: cert)
            }
        }
    }

    private var textSection: some View {
        DetailSection(title: "Endorsement", icon: "doc.text") {
            Text(endorsement.endorsementText)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }

    private var signatureSection: some View {
        DetailSection(title: "Signature", icon: "signature") {
            if let image = SignatureRendering.image(from: endorsement.signatureImageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 120)
                    .padding(.vertical, 8)
            }
            if let signer = endorsement.signerName {
                DetailRow(label: "Signed by", value: signer)
            }
            if let signedAt = endorsement.signedAt {
                DetailRow(label: "Signed at", value: signedAt.formatted(date: .abbreviated, time: .shortened))
            }
        }
    }

    private func notesSection(_ notes: String) -> some View {
        DetailSection(title: "Notes", icon: "note.text") {
            Text(notes)
                .font(.body)
        }
    }

    private var metadataSection: some View {
        DetailSection(title: "Record", icon: "info.circle") {
            if let token = endorsement.remoteSigningToken {
                DetailRow(label: "Signing Token", value: String(token.prefix(12)) + "…")
            }
            DetailRow(label: "Created", value: endorsement.createdAt.formatted(date: .abbreviated, time: .omitted))
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if endorsement.status != .signed {
                Button { showEditor = true } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
            Button {
                prepareExport()
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func prepareExport() {
        guard let data = try? environment?.endorsementService.exportPackage(for: endorsement) else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("AeroLog_Endorsement_\(endorsement.syncID.uuidString.prefix(8)).json")
        try? data.write(to: url)
        shareURL = url
        showShare = true
    }
}