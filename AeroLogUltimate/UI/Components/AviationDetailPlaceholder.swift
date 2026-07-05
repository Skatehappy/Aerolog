import SwiftUI

/// Polished empty state for iPad split-view detail columns.
struct AviationDetailPlaceholder: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.aviationPaletteEnabled) private var paletteEnabled

    let title: String
    let systemImage: String
    let description: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        let surface = AviationSurface(colorScheme: colorScheme, paletteEnabled: paletteEnabled)

        VStack(spacing: 24) {
            Image(systemName: systemImage)
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(surface.accent.opacity(0.85))
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(surface.primaryText)
                Text(description)
                    .font(.body)
                    .foregroundStyle(surface.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .background(surface.background)
    }
}