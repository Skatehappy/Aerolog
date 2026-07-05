import SwiftUI

struct EndorsementRowView: View {
    let endorsement: Endorsement

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(endorsement.title)
                        .font(.headline)
                    EndorsementStatusBadge(status: endorsement.status)
                }

                Text(endorsement.displayStudentName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if endorsement.isSigned, let cert = endorsement.signerCertificateNumber {
                    Text("CFI \(cert)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else if endorsement.isAwaitingSignature {
                    Text("Awaiting \(endorsement.displayInstructorName)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if let date = endorsement.issuedDate ?? endorsement.signedAt {
                    Text(date, format: .dateTime.month(.abbreviated).day().year())
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        switch endorsement.status {
        case .signed: "signature"
        case .pendingSignature: "clock.badge.questionmark"
        case .revoked: "xmark.seal"
        default: "doc.text"
        }
    }

    private var iconColor: Color {
        switch endorsement.status {
        case .signed: .green
        case .pendingSignature: .orange
        case .revoked, .expired: .red
        default: .secondary
        }
    }
}