import SwiftUI

/// Detailed checkride readiness breakdown with requirements and recommendations.
struct CheckrideReadinessView: View {
    @Environment(\.dismiss) private var dismiss

    let report: CheckrideReadinessReport

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                scoreHeader
                requirementsSection
                if !report.recommendations.isEmpty {
                    recommendationsSection
                }
            }
            .padding()
        }
        .navigationTitle("Checkride Readiness")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private var scoreHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: report.isReady ? "checkmark.seal.fill" : "seal")
                .font(.system(size: 48))
                .foregroundStyle(report.isReady ? .green : .orange)
            Text(report.studentName)
                .font(.title2.weight(.bold))
            Text(report.goal.displayName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(Int(report.readinessScore * 100))% Ready")
                .font(.title3.weight(.semibold))
                .foregroundStyle(report.isReady ? .green : .orange)
            ProgressView(value: report.readinessScore)
                .tint(report.isReady ? .green : .orange)
            Text("Syllabus: \(report.lessonsCompleted)/\(report.lessonsTotal) lessons (\(Int(report.syllabusProgress * 100))%)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var requirementsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rating Requirements")
                .font(.headline)
            ForEach(report.requirements) { req in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: req.isMet ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(req.isMet ? .green : .secondary)
                        Text(req.label)
                            .font(.subheadline)
                        Spacer()
                        Text("\(format(req.actual)) / \(format(req.required)) \(req.unit)")
                            .font(.caption.monospacedDigit())
                    }
                    ProgressView(value: req.progress)
                        .tint(req.isMet ? .green : .accentColor)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Recommendations", systemImage: "lightbulb")
                .font(.headline)
            ForEach(report.recommendations, id: \.self) { rec in
                Text("• \(rec)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func format(_ value: Double) -> String {
        TimeFormatting.display(value)
    }
}