import Foundation
import SwiftUI

/// Dependency container injected at the app root.
@MainActor
@Observable
final class AppEnvironment {
    let dataStore: DataStore
    let settings: AppSettings
    let navigation: NavigationCoordinator
    let syncCoordinator: SyncCoordinator

    let attachmentStorage: AttachmentStorageService
    let attachmentService: AttachmentService
    let pilotProfileService: PilotProfileService
    let flightService: FlightService
    let aircraftService: AircraftService
    let currencyService: CurrencyService
    let endorsementService: EndorsementService
    let endorsementTemplateService: EndorsementTemplateService
    let reportService: ReportService
    let reportDefinitionService: ReportDefinitionService
    let trainingService: TrainingService
    let syllabusService: SyllabusService
    let dataManagementService: DataManagementService

    init(dataStore: DataStore) {
        self.dataStore = dataStore
        self.settings = AppSettings()
        self.navigation = NavigationCoordinator()
        self.syncCoordinator = SyncCoordinator(configuration: UserPreferences.shared.syncConfiguration)

        self.attachmentStorage = AttachmentStorageService()
        self.attachmentService = AttachmentService(dataStore: dataStore, storage: attachmentStorage)
        self.pilotProfileService = PilotProfileService(dataStore: dataStore)
        self.flightService = FlightService(dataStore: dataStore)
        self.aircraftService = AircraftService(dataStore: dataStore)
        self.currencyService = CurrencyService(dataStore: dataStore)
        self.endorsementService = EndorsementService(dataStore: dataStore)
        self.endorsementTemplateService = EndorsementTemplateService(dataStore: dataStore)
        self.reportService = ReportService(dataStore: dataStore)
        self.reportDefinitionService = ReportDefinitionService(dataStore: dataStore)
        self.trainingService = TrainingService(dataStore: dataStore)
        self.syllabusService = SyllabusService(dataStore: dataStore)
        self.dataManagementService = DataManagementService(
            dataStore: dataStore,
            attachmentStorage: attachmentStorage
        )

        syncCoordinator.attach(dataManagementService: dataManagementService)
        navigation.selectedTab = UserPreferences.shared.lastSelectedTab
    }

    static func production() throws -> AppEnvironment {
        AppEnvironment(dataStore: try DataStore.makeProduction())
    }

    static func preview() throws -> AppEnvironment {
        AppEnvironment(dataStore: try DataStore.makeInMemory())
    }
}

// MARK: - Environment Key

private struct AppEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppEnvironment? = nil
}

extension EnvironmentValues {
    var appEnvironment: AppEnvironment? {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}