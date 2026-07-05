import Foundation

/// Typed accessors for app-level configuration constants.
enum SettingsStore {
    static let appName = "AeroLog Ultimate"
    static let bundleIdentifier = "com.aerologultimate.app"
    static let minimumIOSVersion = "17.0"

    /// Attachments subdirectory within Application Support.
    static var attachmentsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = appSupport.appendingPathComponent("AeroLogUltimate/Attachments", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// Local backup archives (JSON or `.aerologbackup` directory bundles).
    static var backupsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = appSupport.appendingPathComponent("AeroLogUltimate/Backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static let backupFileExtension = "aerologbackup"
}