import Foundation
import os

/// Manages on-disk storage for attachment binary files (offline-first).
final class AttachmentStorageService: Sendable {
    private let logger = Logger(subsystem: SettingsStore.bundleIdentifier, category: "Attachments")
    private let fileManager: FileManager
    private let baseDirectory: URL

    init(
        fileManager: FileManager = .default,
        baseDirectory: URL = SettingsStore.attachmentsDirectory
    ) {
        self.fileManager = fileManager
        self.baseDirectory = baseDirectory
        try? fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
    }

    /// Returns a unique relative path for a new attachment file.
    func allocateRelativePath(fileName: String) -> String {
        let sanitized = fileName.replacingOccurrences(of: "/", with: "_")
        return "\(UUID().uuidString)/\(sanitized)"
    }

    func absoluteURL(for relativePath: String) -> URL {
        baseDirectory.appendingPathComponent(relativePath)
    }

    func write(data: Data, relativePath: String) throws {
        let url = absoluteURL(for: relativePath)
        let directory = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        logger.debug("Wrote attachment to \(relativePath)")
    }

    func read(relativePath: String) throws -> Data {
        try Data(contentsOf: absoluteURL(for: relativePath))
    }

    func delete(relativePath: String) throws {
        let url = absoluteURL(for: relativePath)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
}