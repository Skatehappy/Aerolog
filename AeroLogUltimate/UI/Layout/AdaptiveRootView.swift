import SwiftUI

/// Chooses iPad split view or iPhone tab layout based on horizontal size class.
struct AdaptiveRootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let navigation: NavigationCoordinator

    var body: some View {
        if horizontalSizeClass == .compact {
            CompactRootView(navigation: navigation)
        } else {
            RootView(navigation: navigation)
        }
    }
}