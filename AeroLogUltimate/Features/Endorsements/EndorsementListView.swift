import SwiftUI
import SwiftData

/// Full endorsement history with student and CFI workflows.
struct EndorsementListView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Endorsement.createdAt, order: .reverse) private var allEndorsements: [Endorsement]

    @Binding var selectedEndorsement: Endorsement?

    @State private var filter: EndorsementFilter = .all
    @State private var showTemplatePicker = false
    @State private var showCFIInbox = false
    @State private var showImport = false
    @State private var showCustomTemplates = false
    @State private var isCFI = false

    init(selectedEndorsement: Binding<Endorsement?> = .constant(nil)) {
        _selectedEndorsement = selectedEndorsement
    }

    private var visible: [Endorsement] {
        allEndorsements
            .filter { !($0.syncMetadata?.isSoftDeleted ?? false) }
            .filter { filter.matches($0) }
    }

    var body: some View {
        Group {
            if visible.isEmpty {
                ContentUnavailableView {
                    Label("No Endorsements", systemImage: "signature")
                } description: {
                    Text("Create an endorsement from a template or import a signing package.")
                } actions: {
                    Button("New Endorsement") { showTemplatePicker = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                List(selection: $selectedEndorsement) {
                    ForEach(visible) { endorsement in
                        EndorsementRowView(endorsement: endorsement)
                            .tag(endorsement)
                    }
                }
            }
        }
        .navigationTitle("Endorsements")
        .toolbar { toolbarContent }
        .safeAreaInset(edge: .top) { filterBar }
        .sheet(isPresented: $showTemplatePicker) {
            NavigationStack { TemplatePickerView() }
        }
        .sheet(isPresented: $showCFIInbox) {
            NavigationStack { CFIInboxView() }
        }
        .sheet(isPresented: $showImport) {
            NavigationStack { ImportSigningPackageView() }
        }
        .sheet(isPresented: $showCustomTemplates) {
            NavigationStack { CustomTemplateListView() }
        }
        .task { await loadCFIStatus() }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(EndorsementFilter.allCases, id: \.self) { item in
                    Button {
                        filter = item
                    } label: {
                        Text(item.title)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(filter == item ? Color.accentColor.opacity(0.2) : Color(.tertiarySystemFill))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button { showTemplatePicker = true } label: {
                Label("New", systemImage: "plus")
            }
        }
        ToolbarItem(placement: .secondaryAction) {
            Menu {
                if isCFI {
                    Button {
                        showCFIInbox = true
                    } label: {
                        Label("Pending Signatures", systemImage: "tray")
                    }
                }
                Button {
                    showImport = true
                } label: {
                    Label("Import Signing Package", systemImage: "square.and.arrow.down")
                }
                Button {
                    showCustomTemplates = true
                } label: {
                    Label("Custom Templates", systemImage: "doc.badge.gearshape")
                }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
        }
    }

    private func loadCFIStatus() async {
        isCFI = (try? environment?.pilotProfileService.primaryProfile()?.isCFI) ?? false
    }
}

enum EndorsementFilter: CaseIterable {
    case all, draft, pending, signed, revoked

    var title: String {
        switch self {
        case .all: "All"
        case .draft: "Drafts"
        case .pending: "Pending"
        case .signed: "Signed"
        case .revoked: "Revoked"
        }
    }

    func matches(_ endorsement: Endorsement) -> Bool {
        switch self {
        case .all: true
        case .draft: endorsement.status == .draft
        case .pending: endorsement.status == .pendingSignature
        case .signed: endorsement.status == .signed
        case .revoked: endorsement.status == .revoked || endorsement.status == .expired
        }
    }
}