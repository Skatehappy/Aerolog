import SwiftUI

struct TrainingRelationshipRowView: View {
    let summary: StudentTrainingSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(summary.studentName)
                    .font(.headline)
                Spacer()
                Text(summary.status.displayName)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(summary.status == .active ? Color.green.opacity(0.15) : Color.gray.opacity(0.15))
                    .clipShape(Capsule())
            }
            Text(summary.goal.displayName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Label(TimeFormatting.display(summary.dualReceived) + " dual", systemImage: "clock")
                Label("\(summary.lessonsCompleted)/\(summary.lessonsTotal) lessons", systemImage: "book")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            ProgressView(value: summary.syllabusProgress)
                .tint(.accentColor)
        }
        .padding(.vertical, 4)
    }
}