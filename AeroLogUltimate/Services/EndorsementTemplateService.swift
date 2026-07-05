import Foundation
import SwiftData

/// CRUD for user-created endorsement templates.
@MainActor
struct EndorsementTemplateService {
    let dataStore: DataStore

    func allCustomTemplates() throws -> [EndorsementTemplate] {
        let descriptor = FetchDescriptor<EndorsementTemplate>(
            sortBy: [SortDescriptor(\.name)]
        )
        return try dataStore.fetch(descriptor)
    }

    @discardableResult
    func create(
        name: String,
        title: String,
        bodyText: String,
        regulationReference: String? = nil
    ) throws -> EndorsementTemplate {
        let template = EndorsementTemplate(
            name: name,
            title: title,
            bodyText: bodyText,
            regulationReference: regulationReference
        )
        template.setPlaceholders(EndorsementTemplate.extractPlaceholders(from: bodyText))
        dataStore.insert(template)
        try dataStore.save()
        return template
    }

    func save(_ template: EndorsementTemplate) throws {
        template.setPlaceholders(EndorsementTemplate.extractPlaceholders(from: template.bodyText))
        template.touch()
        try dataStore.save()
    }

    func delete(_ template: EndorsementTemplate) throws {
        dataStore.delete(template)
        try dataStore.save()
    }

    func template(syncID: UUID) throws -> EndorsementTemplate? {
        try allCustomTemplates().first { $0.syncMetadata?.syncID == syncID }
    }
}