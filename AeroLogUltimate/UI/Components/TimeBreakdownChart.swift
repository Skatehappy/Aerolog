import SwiftUI

/// Simple bar chart for monthly flight time without external chart dependencies.
struct TimeBreakdownChart: View {
    let buckets: [MonthlyTimeBucket]

    private var maxTime: Double {
        max(buckets.map(\.totalTime).max() ?? 1, 0.1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Flight Time")
                .font(.headline)

            if buckets.isEmpty {
                Text("No flight data in range")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(buckets.suffix(12)) { bucket in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.accentColor.opacity(0.8))
                                .frame(height: max(4, CGFloat(bucket.totalTime / maxTime) * 100))
                            Text(bucket.label.prefix(3))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 130, alignment: .bottom)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}