import PencilKit
import SwiftUI

/// Handwritten notes sheet — appends a Pencil annotation marker to flight remarks.
struct PencilNotesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appEnvironment) private var environment

    @Binding var remarks: String?
    @State private var drawing = PKDrawing()
    @State private var typedNote = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("Optional typed note", text: $typedNote, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                PencilInkToolbar(drawing: $drawing)

                PencilCanvasView(
                    drawing: $drawing,
                    preferPencilOnly: environment?.settings.preferPencilOnlyInput ?? false,
                    backgroundColor: UIColor.secondarySystemBackground
                )
                .clipShape(RoundedRectangle(cornerRadius: AviationTheme.cardCornerRadius))
                .padding(.horizontal)

                Text("Use Apple Pencil or finger to jot squawks, maneuvers, or briefing notes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
            .navigationTitle("Pencil Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add to Remarks") {
                        applyNotes()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(drawing.bounds.isEmpty && typedNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func applyNotes() {
        var parts: [String] = []
        if !typedNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(typedNote.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if !drawing.bounds.isEmpty {
            let stamp = Date().formatted(date: .abbreviated, time: .shortened)
            parts.append("[Pencil note \(stamp)]")
        }
        guard !parts.isEmpty else { return }
        let addition = parts.joined(separator: "\n")
        if let existing = remarks, !existing.isEmpty {
            remarks = existing + "\n" + addition
        } else {
            remarks = addition
        }
    }
}