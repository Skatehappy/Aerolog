import SwiftUI
import SwiftData

@main
struct AeroLogUltimateApp: App {
    @State private var environment: AppEnvironment

    init() {
        do {
            _environment = State(initialValue: try AppEnvironment.production())
        } catch {
            fatalError("Failed to initialize data store: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(navigation: environment.navigation)
                .environment(\.appEnvironment, environment)
                .preferredColorScheme(environment.settings.preferredColorScheme)
                .modelContainer(environment.dataStore.container)
        }
    }
}