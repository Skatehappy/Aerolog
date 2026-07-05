import SwiftUI

/// Adaptive layout helpers for iPad split view and large regular size class.
enum IPadAdaptiveLayout {
    static var isRegularWidth: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    static func readableWidth(_ maxWidth: CGFloat = AviationTheme.contentMaxReadableWidth) -> CGFloat {
        maxWidth
    }
}

/// Constrains content to a comfortable reading width on large iPads.
struct ReadableContentWidth: ViewModifier {
    var maxWidth: CGFloat = AviationTheme.contentMaxReadableWidth
    var horizontalPadding: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, horizontalPadding)
    }
}

/// Applies cockpit-friendly spacing and minimum touch targets.
struct CockpitTouchTarget: ViewModifier {
    var minHeight: CGFloat = AviationTheme.minimumTouchTarget

    func body(content: Content) -> some View {
        content
            .frame(minHeight: minHeight)
            .contentShape(Rectangle())
    }
}

/// Split-view column styling for sidebar, content, and detail panes.
struct SplitColumnStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.aviationPaletteEnabled) private var paletteEnabled
    let role: SplitColumnRole

    enum SplitColumnRole {
        case sidebar, content, detail
    }

    func body(content: Content) -> some View {
        let surface = AviationSurface(colorScheme: colorScheme, paletteEnabled: paletteEnabled)
        let background: Color = switch role {
        case .sidebar: surface.sidebar
        case .content: surface.background
        case .detail: surface.background
        }
        content.background(background)
    }
}

extension View {
    func readableContentWidth(maxWidth: CGFloat = AviationTheme.contentMaxReadableWidth) -> some View {
        modifier(ReadableContentWidth(maxWidth: maxWidth))
    }

    func cockpitTouchTarget(minHeight: CGFloat = AviationTheme.minimumTouchTarget) -> some View {
        modifier(CockpitTouchTarget(minHeight: minHeight))
    }

    func splitColumnStyle(_ role: SplitColumnStyle.SplitColumnRole) -> some View {
        modifier(SplitColumnStyle(role: role))
    }
}