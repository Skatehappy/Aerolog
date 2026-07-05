import SwiftUI

/// Visual status card for a single currency item on the dashboard.
struct CurrencyStatusCard: View {
    let result: CurrencyCalculationResult
    var isSelected: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            statusIcon
                .font(.title2)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(result.requirementName)
                        .font(.headline)
                    Spacer()
                    statusLabel
                }

                Text(result.summaryText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if let warning = result.warningText {
                    Text(warning)
                        .font(.caption)
                        .foregroundStyle(warningColor)
                }

                if let days = result.detail.daysRemaining, result.status != .notApplicable {
                    Text(expirationText(days: days))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding()
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        )
    }

    private var statusIcon: some View {
        Image(systemName: result.status.systemImage)
            .foregroundStyle(statusColor)
    }

    private var statusLabel: some View {
        Text(result.status.displayName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(statusColor.opacity(0.15))
            .foregroundStyle(statusColor)
            .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch result.status {
        case .current: .green
        case .expiringSoon: .orange
        case .expired: .red
        case .notApplicable: .gray
        case .unknown: .yellow
        }
    }

    private var warningColor: Color {
        result.status == .expired ? .red : .orange
    }

    private var backgroundColor: Color {
        if isSelected { return Color.accentColor.opacity(0.08) }
        return Color(.secondarySystemBackground)
    }

    private func expirationText(days: Int) -> String {
        if days < 0 { return "Expired \(abs(days)) day(s) ago" }
        if days == 0 { return "Expires today" }
        return "Expires in \(days) day(s)"
    }
}