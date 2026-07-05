import Foundation
import SwiftData

/// CRUD for saved report configurations.
@MainActor
struct ReportDefinitionService {
    let dataStore: DataStore

    func allDefinitions() throws -> [ReportDefinition] {
        let descriptor = FetchDescriptor<ReportDefinition>(
            sortBy: [SortDescriptor(\.name)]
        )
        return try dataStore.fetch(descriptor)
    }

    func favorites() throws -> [ReportDefinition] {
        try allDefinitions().filter(\.isFavorite)
    }

    @discardableResult
    func create(
        name: String,
        reportType: ReportType,
        outputFormat: ReportOutputFormat? = nil,
        filter: ReportFilter = .allTime,
        owner: PilotProfile?
    ) throws -> ReportDefinition {
        let definition = ReportDefinition(
            name: name,
            reportType: reportType,
            outputFormat: outputFormat ?? reportType.defaultFormat
        )
        definition.filter = filter
        definition.owner = owner
        dataStore.insert(definition)
        try dataStore.save()
        return definition
    }

    func save(_ definition: ReportDefinition) throws {
        definition.touch()
        try dataStore.save()
    }

    func delete(_ definition: ReportDefinition) throws {
        dataStore.delete(definition)
        try dataStore.save()
    }

    func definition(syncID: UUID) throws -> ReportDefinition? {
        try allDefinitions().first { $0.syncMetadata?.syncID == syncID }
    }
}