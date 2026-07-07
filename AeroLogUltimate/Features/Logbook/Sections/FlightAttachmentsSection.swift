import SwiftUI
import PhotosUI

struct FlightAttachmentsSection: View {
    @Bindable var flight: Flight

    var body: some View {
        Section {
            FlightAttachmentsGallery(flight: flight, readOnly: false)
        } header: {
            FormSectionHeader(title: "Attachments", subtitle: "Photos, videos, and documents", systemImage: "paperclip")
        }
    }
}

/// Photo/video gallery with picker for flight attachments.
struct FlightAttachmentsGallery: View {
    @Environment(\.appEnvironment) private var environment

    @Bindable var flight: Flight
    let readOnly: Bool

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var attachmentError: String?

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !readOnly {
                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: 10,
                    matching: .any(of: [.images, .videos])
                ) {
                    Label("Add Photos or Videos", systemImage: "photo.on.rectangle.angled")
                }
                .onChange(of: selectedItems) { _, items in
                    Task { await importItems(items) }
                }
            }

            if flight.sortedAttachments.isEmpty {
                Text("No attachments")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(flight.sortedAttachments, id: \.persistentModelID) { attachment in
                        AttachmentThumbnail(
                            attachment: attachment,
                            readOnly: readOnly,
                            onDelete: { remove(attachment) }
                        )
                    }
                }
            }
        }
        .alert("Attachment Error", isPresented: .init(
            get: { attachmentError != nil },
            set: { if !$0 { attachmentError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(attachmentError ?? "")
        }
    }

    private func importItems(_ items: [PhotosPickerItem]) async {
        guard let env = environment else { return }
        let service = AttachmentService(dataStore: env.dataStore, storage: env.attachmentStorage)

        for item in items {
            do {
                if let media = try await item.loadTransferable(type: MediaData.self) {
                    let kind: AttachmentKind = media.isVideo ? .video : .photo
                    let mime = media.isVideo ? "video/quicktime" : "image/jpeg"
                    let ext = media.isVideo ? "mov" : "jpg"
                    _ = try service.addAttachment(
                        data: media.data,
                        fileName: "attachment.\(ext)",
                        mimeType: mime,
                        kind: kind,
                        to: flight
                    )
                }
            } catch {
                attachmentError = error.localizedDescription
            }
        }
        selectedItems = []
    }

    private func remove(_ attachment: Attachment) {
        guard let env = environment else { return }
        let service = AttachmentService(dataStore: env.dataStore, storage: env.attachmentStorage)
        do {
            try service.remove(attachment)
        } catch {
            attachmentError = error.localizedDescription
        }
    }
}

private struct AttachmentThumbnail: View {
    @Environment(\.appEnvironment) private var environment
    let attachment: Attachment
    let readOnly: Bool
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if attachment.kind == .photo,
                   let data = attachment.thumbnailData ?? loadFullImage(),
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Color(.tertiarySystemFill)
                        Image(systemName: attachment.kind == .video ? "video.fill" : "doc.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if !readOnly {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white, .red)
                }
                .offset(x: 6, y: -6)
            }
        }
    }

    private func loadFullImage() -> Data? {
        guard let env = environment else { return nil }
        return try? env.attachmentStorage.read(relativePath: attachment.relativeStoragePath)
    }
}