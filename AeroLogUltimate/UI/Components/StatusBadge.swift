import SwiftUI

/// Colored badge for draft/finalized flight status.
struct StatusBadge: View {
    let status: FlightStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(backgroundColor.opacity(0.15))
            .foregroundStyle(backgroundColor)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch status {
        case .draft: .orange
        case .finalized: .green
        }
    }
}