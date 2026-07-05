import Foundation
import SwiftData

/// User-created endorsement template with merge-field placeholders.
@Model
final class EndorsementTemplate {
    var name: String
    var title: String
    var bodyText: String
    var regulationReference: String?

    /// JSON array of placeholder keys, e.g. ["student_name","airport","aircraft"].
    var placeholdersJSON: String?

    var isFavorite: Bool
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade)
    var syncMetadata: SyncMetadata?

    init(
        name: String,
        title: String,
        bodyText: String,
        regulationReference: String? = nil
    ) {
        self.name = name
        self.title = title
        self.bodyText = bodyText
        self.regulationReference = regulationReference
        self.isFavorite = false
        self.createdAt = .now
        self.updatedAt = .now
        self.syncMetadata = SyncMetadata()
    }

    var placeholders: [String] {
        guard let json = placeholdersJSON,
              let data = json.data(using: .utf8),
              let keys = try? JSONDecoder().decode([String].self, from: data) else {
            return Self.extractPlaceholders(from: bodyText)
        }
        return keys
    }

    func setPlaceholders(_ keys: [String]) {
        if let data = try? JSONEncoder().encode(keys),
           let json = String(data: data, encoding: .utf8) {
            placeholdersJSON = json
        }
    }

    func touch() {
        updatedAt = .now
        syncMetadata?.markModified()
    }

    static func extractPlaceholders(from text: String) -> [String] {
        let pattern = /\{\{([a-zA-Z0-9_]+)\}\}/
        var keys: [String] = []
        for match in text.matches(of: pattern) {
            let key = String(match.1)
            if !keys.contains(key) { keys.append(key) }
        }
        return keys
    }
}