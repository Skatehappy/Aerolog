import Foundation

/// Lightweight user preferences stored in UserDefaults (non-logbook settings).
final class UserPreferences: @unchecked Sendable {
    static let shared = UserPreferences()

    private let defaults: UserDefaults
    private let prefix = "com.aerologultimate.preferences."

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Keys

    private enum Key: String {
        case hasCompletedInitialSeed
        case preferredColorScheme
        case defaultFlightRole
        case showDecimalHours
        case confirmBeforeDelete
        case lastSelectedTab
        case syncConfigurationJSON
        case useAviationDarkPalette
        case preferPencilOnlyInput
        case compactSidebar
    }

    // MARK: - App Lifecycle

    var hasCompletedInitialSeed: Bool {
        get { defaults.bool(forKey: key(.hasCompletedInitialSeed)) }
        set { defaults.set(newValue, forKey: key(.hasCompletedInitialSeed)) }
    }

    // MARK: - Display

    /// `nil` = system, otherwise "light" or "dark"
    var preferredColorScheme: String? {
        get { defaults.string(forKey: key(.preferredColorScheme)) }
        set { defaults.set(newValue, forKey: key(.preferredColorScheme)) }
    }

    var showDecimalHours: Bool {
        get { defaults.object(forKey: key(.showDecimalHours)) as? Bool ?? true }
        set { defaults.set(newValue, forKey: key(.showDecimalHours)) }
    }

    // MARK: - Logging Defaults

    var defaultFlightRole: FlightRole {
        get {
            guard let raw = defaults.string(forKey: key(.defaultFlightRole)),
                  let role = FlightRole(rawValue: raw) else { return .pic }
            return role
        }
        set { defaults.set(newValue.rawValue, forKey: key(.defaultFlightRole)) }
    }

    // MARK: - Safety

    var confirmBeforeDelete: Bool {
        get { defaults.object(forKey: key(.confirmBeforeDelete)) as? Bool ?? true }
        set { defaults.set(newValue, forKey: key(.confirmBeforeDelete)) }
    }

    // MARK: - Navigation Persistence

    var lastSelectedTab: AppTab {
        get {
            guard let raw = defaults.string(forKey: key(.lastSelectedTab)),
                  let tab = AppTab(rawValue: raw) else { return .logbook }
            return tab
        }
        set { defaults.set(newValue.rawValue, forKey: key(.lastSelectedTab)) }
    }

    // MARK: - iPad / Cockpit

    /// Applies refined aviation dark palette (navy panels, amber accents) in dark mode.
    var useAviationDarkPalette: Bool {
        get { defaults.object(forKey: key(.useAviationDarkPalette)) as? Bool ?? true }
        set { defaults.set(newValue, forKey: key(.useAviationDarkPalette)) }
    }

    /// Restrict PencilKit canvases to Apple Pencil only (no finger drawing).
    var preferPencilOnlyInput: Bool {
        get { defaults.object(forKey: key(.preferPencilOnlyInput)) as? Bool ?? false }
        set { defaults.set(newValue, forKey: key(.preferPencilOnlyInput)) }
    }

    /// Use compact sidebar tab labels on smaller iPad windows.
    var compactSidebar: Bool {
        get { defaults.object(forKey: key(.compactSidebar)) as? Bool ?? false }
        set { defaults.set(newValue, forKey: key(.compactSidebar)) }
    }

    // MARK: - Sync

    var syncConfiguration: EncryptedSyncConfiguration {
        get {
            guard let json = defaults.string(forKey: key(.syncConfigurationJSON)),
                  let data = json.data(using: .utf8),
                  let config = try? JSONDecoder().decode(EncryptedSyncConfiguration.self, from: data) else {
                return .disabled
            }
            return config
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                defaults.set(json, forKey: key(.syncConfigurationJSON))
            }
        }
    }

    private func key(_ key: Key) -> String {
        prefix + key.rawValue
    }
}