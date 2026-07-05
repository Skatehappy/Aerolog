import SwiftUI

/// Cockpit-friendly color palette optimized for briefing rooms and dim lighting.
enum AviationTheme {
    // MARK: - Brand

    static let brandNavy = Color(red: 0.09, green: 0.18, blue: 0.42)
    static let brandSky = Color(red: 0.35, green: 0.62, blue: 0.92)

    // MARK: - Aviation Dark Palette

    static let panelBackground = Color(red: 0.06, green: 0.09, blue: 0.14)
    static let sidebarBackground = Color(red: 0.08, green: 0.12, blue: 0.18)
    static let cardBackground = Color(red: 0.11, green: 0.15, blue: 0.21)
    static let elevatedBackground = Color(red: 0.14, green: 0.18, blue: 0.24)
    static let borderSubtle = Color.white.opacity(0.08)
    static let textPrimary = Color(red: 0.94, green: 0.96, blue: 0.98)
    static let textSecondary = Color(red: 0.65, green: 0.72, blue: 0.80)
    static let accentAmber = Color(red: 1.0, green: 0.78, blue: 0.28)
    static let statusCurrent = Color(red: 0.35, green: 0.82, blue: 0.55)
    static let statusExpired = Color(red: 0.95, green: 0.42, blue: 0.38)

    // MARK: - Light Palette

    static let lightPanel = Color(red: 0.96, green: 0.97, blue: 0.99)
    static let lightSidebar = Color(red: 0.93, green: 0.95, blue: 0.98)
    static let lightCard = Color.white

    // MARK: - Metrics

    static let minimumTouchTarget: CGFloat = 44
    static let sidebarIdealWidth: CGFloat = 280
    static let contentMaxReadableWidth: CGFloat = 920
    static let detailMaxReadableWidth: CGFloat = 1100
    static let sectionSpacing: CGFloat = 20
    static let cardCornerRadius: CGFloat = 12
}

// MARK: - Environment

private struct AviationPaletteEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var aviationPaletteEnabled: Bool {
        get { self[AviationPaletteEnabledKey.self] }
        set { self[AviationPaletteEnabledKey.self] = newValue }
    }
}

// MARK: - Semantic Surfaces

struct AviationSurface {
    let colorScheme: ColorScheme
    let paletteEnabled: Bool

    var background: Color {
        guard paletteEnabled else { return Color(.systemGroupedBackground) }
        return colorScheme == .dark ? AviationTheme.panelBackground : AviationTheme.lightPanel
    }

    var sidebar: Color {
        guard paletteEnabled else { return Color(.secondarySystemGroupedBackground) }
        return colorScheme == .dark ? AviationTheme.sidebarBackground : AviationTheme.lightSidebar
    }

    var card: Color {
        guard paletteEnabled else { return Color(.secondarySystemBackground) }
        return colorScheme == .dark ? AviationTheme.cardBackground : AviationTheme.lightCard
    }

    var primaryText: Color {
        guard paletteEnabled, colorScheme == .dark else { return Color.primary }
        return AviationTheme.textPrimary
    }

    var secondaryText: Color {
        guard paletteEnabled, colorScheme == .dark else { return Color.secondary }
        return AviationTheme.textSecondary
    }

    var accent: Color {
        guard paletteEnabled, colorScheme == .dark else { return AviationTheme.brandNavy }
        return AviationTheme.accentAmber
    }

    var selectionHighlight: Color {
        accent.opacity(colorScheme == .dark ? 0.22 : 0.12)
    }
}

// MARK: - Modifiers

struct AviationThemeModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let paletteEnabled: Bool

    private var surface: AviationSurface {
        AviationSurface(colorScheme: colorScheme, paletteEnabled: paletteEnabled)
    }

    func body(content: Content) -> some View {
        content
            .environment(\.aviationPaletteEnabled, paletteEnabled)
            .tint(surface.accent)
            .background(surface.background.ignoresSafeArea())
    }
}

extension View {
    func aviationTheme(enabled: Bool) -> some View {
        modifier(AviationThemeModifier(paletteEnabled: enabled))
    }
}

/// Card container with aviation styling and generous touch padding.
struct AviationCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.aviationPaletteEnabled) private var paletteEnabled

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let surface = AviationSurface(colorScheme: colorScheme, paletteEnabled: paletteEnabled)
        content
            .padding(AviationTheme.sectionSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(surface.card)
            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AviationTheme.cardCornerRadius)
                    .stroke(
                        paletteEnabled && colorScheme == .dark ? AviationTheme.borderSubtle : Color.clear,
                        lineWidth: 1
                    )
            )
    }
}