import SwiftUI
import SwiftData

@main
struct AeroLogUltimateApp: App {
    @State private var environment: AppEnvironment

    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    init() {
        do {
            let store = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
                ? try DataStore.makeInMemory()
                : try DataStore.makeProduction()
            _environment = State(initialValue: AppEnvironment(dataStore: store))
        } catch {
            fatalError("Failed to initialize data store: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if isRunningTests {
                    TestHostView()
                } else {
                    RootView(navigation: environment.navigation)
                        .environment(\.appEnvironment, environment)
                        .aviationTheme(enabled: environment.settings.useAviationDarkPalette)
                        .preferredColorScheme(environment.settings.preferredColorScheme)
                }
            }
            .modelContainer(environment.dataStore.container)
        }
        .commands {
            if !isRunningTests {
                AppCommands()
            }
        }
    }
}

/// Minimal shell used when XCTest launches the app as a test host.
private struct TestHostView: View {
    var body: some View {
        Color.clear
            .accessibilityHidden(true)
    }
}