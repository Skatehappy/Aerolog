import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Transferable wrapper for PhotosPicker image and video imports.
struct MediaData: Transferable {
    let data: Data
    let isVideo: Bool

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            MediaData(data: data, isVideo: false)
        }
        DataRepresentation(importedContentType: .movie) { data in
            MediaData(data: data, isVideo: true)
        }
        DataRepresentation(importedContentType: .video) { data in
            MediaData(data: data, isVideo: true)
        }
    }
}