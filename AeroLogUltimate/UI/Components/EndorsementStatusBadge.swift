import SwiftUI

struct EndorsementStatusBadge: View {
    let status: EndorsementStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var color: Color {
        switch status {
        case .draft: .gray
        case .pendingSignature: .orange
        case .signed: .green
        case .expired: .red
        case .revoked: .purple
        }
    }
}