import SwiftUI

/// Horizontal bar chart comparing flight time categories.
struct TimeCategoryChart: View {
    let picTime: Double
    let soloTime: Double
    let dualReceived: Double
    let dualGiven: Double
    let crossCountryTime: Double
    let nightTime: Double
    let instrumentTime: Double

    private var items: [(label: String, value: Double, color: Color)] {
        [
            ("PIC", picTime, .blue),
            ("Solo", soloTime, .teal),
            ("Dual Rcvd", dualReceived, .orange),
            ("Dual Given", dualGiven, .purple),
            ("Cross Country", crossCountryTime, .green),
            ("Night", nightTime, .indigo),
            ("Instrument", instrumentTime, .cyan)
        ].filter { $0.value > 0 }
    }

    private var maxValue: Double {
        max(items.map(\.value).max() ?? 1, 0.1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time by Category")
                .font(.headline)

            if items.isEmpty {
                Text("No categorized time in range")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        HStack(spacing: 10) {
                            Text(item.label)
                                .font(.caption)
                                .frame(width: 72, alignment: .leading)
                                .foregroundStyle(.secondary)

                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(item.color.opacity(0.8))
                                    .frame(width: max(4, geo.size.width * CGFloat(item.value / maxValue)))
                            }
                            .frame(height: 12)

                            Text(TimeFormatting.display(item.value))
                                .font(.caption.monospacedDigit().weight(.medium))
                                .frame(width: 36, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Ranked horizontal bar chart for airports or aircraft.
struct RankingBarChart: View {
    let title: String
    let systemImage: String
    let items: [(label: String, value: Double, detail: String?)]

    private var maxValue: Double {
        max(items.map(\.value).max() ?? 1, 0.1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)

            if items.isEmpty {
                Text("No data in range")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.label)
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                Text(TimeFormatting.display(item.value) + " hrs")
                                    .font(.caption.monospacedDigit().weight(.semibold))
                            }
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.accentColor.opacity(0.75))
                                    .frame(width: max(4, geo.size.width * CGFloat(item.value / maxValue)))
                            }
                            .frame(height: 10)
                            if let detail = item.detail {
                                Text(detail)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}