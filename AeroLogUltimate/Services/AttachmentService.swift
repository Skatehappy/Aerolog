import Foundation
import SwiftData
import UIKit

/// Manages attachment metadata and on-disk file storage for flights.
@MainActor
struct AttachmentService {
    let dataStore: DataStore
    let storage: AttachmentStorageService

    func addAttachment(
        data: Data,
        fileName: String,
        mimeType: String,
        kind: AttachmentKind,
        to flight: Flight,
        thumbnail: Data? = nil
    ) throws -> Attachment {
        let relativePath = storage.allocateRelativePath(fileName: fileName)
        try storage.write(data: data, relativePath: relativePath)

        let attachment = Attachment(
            kind: kind,
            linkType: .flight,
            fileName: fileName,
            mimeType: mimeType,
            fileSizeBytes: Int64(data.count),
            relativeStoragePath: relativePath
        )
        attachment.thumbnailData = thumbnail ?? generateThumbnail(data: data, mimeType: mimeType)
        attachment.sortOrder = (flight.attachments?.count ?? 0)
        attachment.flight = flight

        dataStore.insert(attachment)
        flight.touch()
        try dataStore.save()
        return attachment
    }

    func remove(_ attachment: Attachment) throws {
        try storage.delete(relativePath: attachment.relativeStoragePath)
        dataStore.delete(attachment)
        try dataStore.save()
    }

    func updateCaption(_ attachment: Attachment, caption: String) throws {
        attachment.caption = caption
        attachment.touch()
        try dataStore.save()
    }

    func loadImage(for attachment: Attachment) -> UIImage? {
        guard attachment.kind == .photo,
              let data = try? storage.read(relativePath: attachment.relativeStoragePath) else {
            return nil
        }
        return UIImage(data: data)
    }

    private func generateThumbnail(data: Data, mimeType: String) -> Data? {
        guard mimeType.hasPrefix("image/"),
              let image = UIImage(data: data) else { return nil }
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        let thumbnail = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return thumbnail.jpegData(compressionQuality: 0.7)
    }
}