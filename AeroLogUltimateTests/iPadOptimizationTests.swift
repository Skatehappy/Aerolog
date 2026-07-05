import XCTest
import SwiftUI
@testable import AeroLogUltimate

final class iPadOptimizationTests: XCTestCase {
    func testAllTabsHaveUniqueKeyboardShortcuts() {
        let shortcuts = KeyboardShortcutRegistry.allTabShortcuts.map(\.0)
        XCTAssertEqual(shortcuts.count, AppTab.allCases.count)
        XCTAssertEqual(Set(shortcuts).count, AppTab.allCases.count)
    }

    func testAppTabShortcutKeysAreDigitsOneThroughSeven() {
        let keys = AppTab.allCases.compactMap(\.shortcutDigit).map(String.init)
        XCTAssertEqual(keys, ["1", "2", "3", "4", "5", "6", "7"])
    }

    func testAviationThemeDefinesCockpitMetrics() {
        XCTAssertGreaterThanOrEqual(AviationTheme.minimumTouchTarget, 44)
        XCTAssertGreaterThan(AviationTheme.sidebarIdealWidth, 200)
        XCTAssertGreaterThan(AviationTheme.contentMaxReadableWidth, 600)
    }

    @MainActor
    func testShortcutCenterDispatchesAndConsumes() {
        let center = AppShortcutCenter()
        center.trigger(.newFlight)
        XCTAssertEqual(center.consume(), .newFlight)
        XCTAssertNil(center.consume())
    }

    func testAviationSurfaceAdaptsToDarkPalette() {
        let dark = AviationSurface(colorScheme: .dark, paletteEnabled: true)
        let light = AviationSurface(colorScheme: .light, paletteEnabled: true)
        XCTAssertNotEqual(dark.background, light.background)
    }
}