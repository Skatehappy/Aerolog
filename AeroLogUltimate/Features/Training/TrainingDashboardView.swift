import SwiftUI
import SwiftData

/// CFI training hub with student list, stats, and quick actions.
struct TrainingDashboardView: View {
    @Environment(\.appEnvironment) private var environment

    @Binding var selectedRelationshipID: UUID?

    @State private var dashboard: TrainingDashboardSummary?
    @State private var relationships: [TrainingRelationship] = []
    @State private var summaries: [UUID: StudentTrainingSummary] = [:]
    @State private var isCFI = false
    @State private var isLoading = true
    @State private var showAddStudent = false
    @State private var showSyllabi = false
    @State private var errorMessage: String?

    init(selectedRelationshipID: Binding<UUID?> = .constant(nil)) {
        _selectedRelationshipID = selectedRelationshipID
    }

    var body: some View {
        Group {
            if isLoading && dashboard == nil {
                ProgressView("Loading training data...")
            } else if !isCFI {
                cfiRequiredView
            } else if let dashboard {
                dashboardContent(dashboard)
            } else {
                ContentUnavailableView {
                    Label("Training", systemImage: "person.2")
                } description: {
                    Text("Add students to begin tracking training progress.")
                } actions: {
                    Button("Add Student") { showAddStudent = true }
                }
            }
        }
        .navigationTitle("Training")
        .toolbar { toolbarContent }
        .sheet(isPresented: $showAddStudent) {
            NavigationStack {
                StudentEditorView()
            }
        }
        .sheet(isPresented: $showSyllabi) {
            NavigationStack {
                SyllabusListView()
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

    private var cfiRequiredView: some View {
        ContentUnavailableView {
            Label("CFI Profile Required", systemImage: "graduationcap")
        } description: {
            Text("Enable CFI in your pilot profile to manage students, log lessons, and track checkride readiness.")
        }
    }

    @ViewBuilder
    private func dashboardContent(_ dashboard: TrainingDashboardSummary) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                statsGrid(dashboard)
                if !dashboard.studentsNeedingAttention.isEmpty {
                    attentionSection(dashboard.studentsNeedingAttention)
                }
                studentsSection
                if !dashboard.recentLessons.isEmpty {
                    recentLessonsSection(dashboard.recentLessons)
                }
            }
            .padding()
        }
    }

    private func statsGrid(_ dashboard: TrainingDashboardSummary) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            AnalyticsSummaryCard(title: "Active Students", value: "\(dashboard.activeStudentCount)", systemImage: "person.2")
            AnalyticsSummaryCard(title: "Lessons This Month", value: "\(dashboard.lessonsThisMonth)", systemImage: "calendar", tint: .blue)
            AnalyticsSummaryCard(title: "Dual Given", value: TimeFormatting.display(dashboard.totalDualGiven), subtitle: "hrs", systemImage: "clock", tint: .green)
            AnalyticsSummaryCard(title: "Ground Given", value: TimeFormatting.display(dashboard.totalGroundGiven), subtitle: "hrs", systemImage: "book", tint: .orange)
        }
    }

    private func attentionSection(_ items: [StudentAttentionItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Needs Attention", systemImage: "exclamationmark.triangle")
                .font(.headline)
                .foregroundStyle(.orange)
            ForEach(items) { item in
                Button {
                    selectedRelationshipID = item.relationshipID
                } label: {
                    StatisticRow(label: item.studentName, value: item.reason)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var studentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Students")
                    .font(.headline)
                Spacer()
                Button("Add") { showAddStudent = true }
                    .font(.subheadline.weight(.medium))
            }
            if relationships.isEmpty {
                Text("No active students. Tap Add to create a training relationship.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(relationships, id: \.syncID) { relationship in
                    if let summary = summaries[relationship.syncID] {
                        Button {
                            selectedRelationshipID = relationship.syncID
                        } label: {
                            TrainingRelationshipRowView(summary: summary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func recentLessonsSection(_ lessons: [RecentLessonEntry]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Lessons")
                .font(.headline)
            ForEach(lessons) { lesson in
                StatisticRow(
                    label: lesson.studentName,
                    value: TimeFormatting.display(lesson.duration) + " hrs",
                    detail: "\(lesson.lessonTitle) · \(lesson.date.formatted(date: .abbreviated, time: .omitted))"
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if isCFI {
            ToolbarItem(placement: .primaryAction) {
                Button { showAddStudent = true } label: {
                    Label("Add Student", systemImage: "person.badge.plus")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button { showSyllabi = true } label: {
                    Label("Syllabi", systemImage: "book.closed")
                }
            }
        }
    }

    private func refresh() {
        isLoading = true
        defer { isLoading = false }
        guard let service = environment?.trainingService,
              let profile = try? environment?.pilotProfileService.primaryProfile() else { return }
        isCFI = profile.isCFI
        guard isCFI else { return }
        do {
            dashboard = try service.dashboard(for: profile)
            relationships = try service.activeRelationships(for: profile)
            var map: [UUID: StudentTrainingSummary] = [:]
            for relationship in relationships {
                map[relationship.syncID] = try service.studentSummary(for: relationship)
            }
            summaries = map
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}