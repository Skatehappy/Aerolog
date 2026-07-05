import Foundation
import SwiftUI

/// Actions triggered from keyboard shortcuts and the command menu.
enum AppShortcutAction: Equatable, Sendable {
    case newFlight
    case focusSearch
    case toggleSidebar
    case save
    case selectTab(AppTab)
}

/// Central dispatch for iPad keyboard shortcuts and menu commands.
@MainActor
@Observable
final class AppShortcutCenter {
    private(set) var pendingAction: AppShortcutAction?
    private(set) var actionGeneration = 0

    func trigger(_ action: AppShortcutAction) {
        pendingAction = action
        actionGeneration += 1
    }

    func consume() -> AppShortcutAction? {
        defer { pendingAction = nil }
        return pendingAction
    }
}

/// Registry of keyboard shortcuts exposed in Settings and the command menu.
enum KeyboardShortcutRegistry {
    static let newFlight = KeyboardShortcut("n", modifiers: .command)
    static let focusSearch = KeyboardShortcut("f", modifiers: .command)
    static let toggleSidebar = KeyboardShortcut("s", modifiers: [.command, .control])
    static let save = KeyboardShortcut("s", modifiers: .command)

    static func selectTab(_ tab: AppTab) -> KeyboardShortcut? {
        guard let key = tab.shortcutKey else { return nil }
        return KeyboardShortcut(key, modifiers: [.command, .shift])
    }

    static var allTabShortcuts: [(AppTab, KeyboardShortcut)] {
        AppTab.allCases.compactMap { tab in
            guard let shortcut = selectTab(tab) else { return nil }
            return (tab, shortcut)
        }
    }
}

extension AppTab {
    /// Digit keys 1–7 for quick tab switching with ⌘⇧.
    var shortcutKey: KeyEquivalent? {
        guard let character = shortcutDigit else { return nil }
        return KeyEquivalent(character)
    }

    var shortcutDigit: Character? {
        switch self {
        case .logbook: "1"
        case .aircraft: "2"
        case .currency: "3"
        case .endorsements: "4"
        case .training: "5"
        case .reports: "6"
        case .settings: "7"
        }
    }

    var shortcutLabel: String? {
        guard let digit = shortcutDigit else { return nil }
        return "⌘⇧\(String(digit))"
    }
}