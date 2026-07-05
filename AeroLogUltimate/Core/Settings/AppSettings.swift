import Foundation
import SwiftUI

/// Observable application settings facade for SwiftUI injection.
@MainActor
@Observable
final class AppSettings {
    var preferredColorScheme: ColorScheme? {
        didSet { preferences.preferredColorScheme = preferredColorScheme?.storageValue }
    }

    var showDecimalHours: Bool {
        didSet { preferences.showDecimalHours = showDecimalHours }
    }

    var defaultFlightRole: FlightRole {
        didSet { preferences.defaultFlightRole = defaultFlightRole }
    }

    var confirmBeforeDelete: Bool {
        didSet { preferences.confirmBeforeDelete = confirmBeforeDelete }
    }

    var syncConfiguration: EncryptedSyncConfiguration {
        didSet { preferences.syncConfiguration = syncConfiguration }
    }

    private let preferences: UserPreferences

    init(preferences: UserPreferences = .shared) {
        self.preferences = preferences
        self.showDecimalHours = preferences.showDecimalHours
        self.defaultFlightRole = preferences.defaultFlightRole
        self.confirmBeforeDelete = preferences.confirmBeforeDelete
        self.syncConfiguration = preferences.syncConfiguration
        self.preferredColorScheme = preferences.preferredColorScheme.flatMap(ColorScheme.init(storageValue:))
    }
}

// MARK: - ColorScheme Helpers

private extension ColorScheme {
    init?(storageValue: String) {
        switch storageValue {
        case "light": self = .light
        case "dark": self = .dark
        default: return nil
        }
    }

    var storageValue: String {
        switch self {
        case .light: "light"
        case .dark: "dark"
        @unknown default: "light"
        }
    }
}