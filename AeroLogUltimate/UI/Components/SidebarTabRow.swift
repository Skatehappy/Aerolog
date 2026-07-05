import SwiftUI

/// Sidebar navigation row with aviation styling and keyboard shortcut hint.
struct SidebarTabRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.aviationPaletteEnabled) private var paletteEnabled

    let tab: AppTab
    let isSelected: Bool

    var body: some View {
        let surface = AviationSurface(colorScheme: colorScheme, paletteEnabled: paletteEnabled)

        HStack(spacing: 14) {
            Image(systemName: tab.systemImage)
                .font(.title3)
                .foregroundStyle(isSelected ? surface.accent : surface.secondaryText)
                .frame(width: 28)

            Text(tab.title)
                .font(.body.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? surface.primaryText : surface.secondaryText)

            Spacer()

            if let hint = tab.shortcutLabel {
                Text(hint)
                    .font(.caption2.monospaced())
                    .foregroundStyle(surface.secondaryText.opacity(0.7))
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            isSelected ? surface.selectionHighlight : Color.clear,
            in: RoundedRectangle(cornerRadius: 10)
        )
        .cockpitTouchTarget()
    }
}