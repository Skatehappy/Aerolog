import Foundation

/// Typed navigation destinations for programmatic routing.
enum AppRoute: Hashable, Sendable {
    // Logbook
    case flightList
    case flightDetail(UUID)
    case flightEditor(UUID?)

    // Aircraft
    case aircraftList
    case aircraftDetail(UUID)

    // Currency
    case currencyDashboard
    case currencyDetail(CurrencyType)

    // Endorsements
    case endorsementList
    case endorsementDetail(UUID)

    // Training
    case trainingDashboard
    case studentDetail(UUID)

    // Reports
    case reportList
    case reportBuilder(UUID?)

    // Settings
    case settingsRoot
    case pilotProfile
    case dataManagement
    case syncSettings
}