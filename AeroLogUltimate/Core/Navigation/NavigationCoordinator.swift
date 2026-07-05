import Foundation
import SwiftUI

/// Central navigation state for the iPad split-view shell.
@MainActor
@Observable
final class NavigationCoordinator {
    var selectedTab: AppTab = .logbook
    var logbookPath: [AppRoute] = []
    var aircraftPath: [AppRoute] = []
    var currencyPath: [AppRoute] = []
    var endorsementsPath: [AppRoute] = []
    var trainingPath: [AppRoute] = []
    var reportsPath: [AppRoute] = []
    var settingsPath: [AppRoute] = []

    var columnVisibility: NavigationSplitViewVisibility = .all

    func path(for tab: AppTab) -> [AppRoute] {
        switch tab {
        case .logbook: logbookPath
        case .aircraft: aircraftPath
        case .currency: currencyPath
        case .endorsements: endorsementsPath
        case .training: trainingPath
        case .reports: reportsPath
        case .settings: settingsPath
        }
    }

    func setPath(_ path: [AppRoute], for tab: AppTab) {
        switch tab {
        case .logbook: logbookPath = path
        case .aircraft: aircraftPath = path
        case .currency: currencyPath = path
        case .endorsements: endorsementsPath = path
        case .training: trainingPath = path
        case .reports: reportsPath = path
        case .settings: settingsPath = path
        }
    }

    func navigate(to route: AppRoute, in tab: AppTab? = nil) {
        let targetTab = tab ?? selectedTab
        var path = path(for: targetTab)
        path.append(route)
        setPath(path, for: targetTab)
        if let tab { selectedTab = tab }
    }

    func popToRoot(in tab: AppTab? = nil) {
        setPath([], for: tab ?? selectedTab)
    }

    func selectTab(_ tab: AppTab) {
        selectedTab = tab
    }
}