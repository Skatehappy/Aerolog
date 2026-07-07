import SwiftUI
import SwiftData

/// Detailed student training view with progress, lessons, and checkride readiness.
struct StudentDetailView: View {
    @Environment(\.appEnvironment) private var environment

    let relationshipID: UUID

    @State private var relationship: TrainingRelationship?
    @State private var summary: StudentTrainingSummary?
    @State private var lessonProgress: [LessonProgressItem] = []
    @State private var readiness: CheckrideReadinessReport?
    @State private var activeSheet: ActiveSheet?
    @State private var generatedReport: GeneratedReport?
    @State private var errorMessage: String?

    // A single sheet driver. SwiftUI only reliably presents ONE
    // .sheet(isPresented:) per view — stacking five of them made edit / lesson
    // logging / readiness / report all come up blank. Route every modal through
    // one .sheet(item:) instead.
    private enum ActiveSheet: Identifiable {
        case edit, flightLesson, groundLesson, readiness, report
        var id: Self { self }
    }

    var body: some View {
        Group {
            if let summary, let relationship {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header(summary)
                        progressSection(summary)
                        actionsSection(relationship)
                        lessonProgressSection
                        if let readiness {
                            readinessPreview(readiness)
                        }
                    }
                    .padding()
                }
            } else {
                ProgressView("Loading student...")
            }
        }
        .navigationTitle(summary?.studentName ?? "Student")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if relationship != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button { activeSheet = .edit } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                }
            }
        }
        .sheet(item: $activeSheet, onDismiss: { refresh() }) { sheet in
            switch sheet {
            case .edit:
                if let relationship {
                    NavigationStack { StudentEditorView(relationship: relationship) }
                }
            case .flightLesson:
                if let relationship {
                    NavigationStack { LessonLogView(relationship: relationship, mode: .flight) }
                }
            case .groundLesson:
                if let relationship {
                    NavigationStack { LessonLogView(relationship: relationship, mode: .ground) }
                }
            case .readiness:
                if let readiness {
                    NavigationStack { CheckrideReadinessView(report: readiness) }
                }
            case .report:
                if let generatedReport {
                    NavigationStack { ReportPreviewView(report: generatedReport) }
                }
            }
        }
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .task { refresh() }
        .refreshable { refresh() }
    }

    private func header(_ summary: StudentTrainingSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(summary.goal.displayName)
                .font(.title3.weight(.semibold))
            Text(summary.syllabusName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Training since \(summary.startDate.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func progressSection(_ summary: StudentTrainingSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Progress")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                AnalyticsSummaryCard(title: "Dual Received", value: TimeFormatting.display(summary.dualReceived), systemImage: "clock")
                AnalyticsSummaryCard(title: "Solo", value: TimeFormatting.display(summary.soloTime), systemImage: "person", tint: .blue)
                AnalyticsSummaryCard(title: "Ground", value: TimeFormatting.display(summary.groundInstruction), systemImage: "book", tint: .orange)
                AnalyticsSummaryCard(title: "Endorsements", value: "\(summary.endorsementCount)", systemImage: "signature", tint: .purple)
            }
            HStack {
                Text("Syllabus: \(summary.lessonsCompleted)/\(summary.lessonsTotal)")
                    .font(.caption)
                Spacer()
                Text("\(Int(summary.syllabusProgress * 100))%")
                    .font(.caption.weight(.semibold))
            }
            ProgressView(value: summary.syllabusProgress)
        }
    }

    private func actionsSection(_ relationship: TrainingRelationship) -> some View {
        VStack(spacing: 10) {
            Button { activeSheet = .flightLesson } label: {
                Label("Log Flight Lesson", systemImage: "airplane")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            Button { activeSheet = .groundLesson } label: {
                Label("Log Ground Instruction", systemImage: "book")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            Button { activeSheet = .readiness } label: {
                Label("Checkride Readiness", systemImage: "checkmark.seal")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            Button { generateStudentReport() } label: {
                Label("Generate Student Report", systemImage: "doc.text")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var lessonProgressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Syllabus Lessons")
                .font(.headline)
            if lessonProgress.isEmpty {
                Text("No syllabus lessons configured.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(lessonProgress) { item in
                    HStack {
                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(item.isCompleted ? .green : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(item.lessonNumber). \(item.title)")
                                .font(.subheadline)
                            if let date = item.completedDate {
                                Text(date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func readinessPreview(_ report: CheckrideReadinessReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Checkride Readiness")
                    .font(.headline)
                Spacer()
                Text("\(Int(report.readinessScore * 100))%")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(report.isReady ? .green : .orange)
            }
            ProgressView(value: report.readinessScore)
                .tint(report.isReady ? .green : .orange)
            if let first = report.recommendations.first {
                Text(first)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func refresh() {
        guard let service = environment?.trainingService else { return }
        do {
            relationship = try service.relationship(syncID: relationshipID)
            guard let relationship else { return }
            summary = try service.studentSummary(for: relationship)
            lessonProgress = try service.lessonProgress(for: relationship)
            readiness = try service.checkrideReadiness(for: relationship)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func generateStudentReport() {
        guard let service = environment?.reportService else { return }
        do {
            generatedReport = try service.generate(type: .studentProgress)
            activeSheet = .report
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}