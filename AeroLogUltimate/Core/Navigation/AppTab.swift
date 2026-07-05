import Foundation

/// Primary iPad sidebar destinations (UI built in later phases).
enum AppTab: String, CaseIterable, Identifiable, Hashable, Sendable {
    case logbook
    case aircraft
    case currency
    case endorsements
    case training
    case reports
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .logbook: "Logbook"
        case .aircraft: "Aircraft"
        case .currency: "Currency"
        case .endorsements: "Endorsements"
        case .training: "Training"
        case .reports: "Reports"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .logbook: "book.closed"
        case .aircraft: "airplane"
        case .currency: "checkmark.shield"
        case .endorsements: "signature"
        case .training: "person.2"
        case .reports: "chart.bar.doc.horizontal"
        case .settings: "gearshape"
        }
    }
}