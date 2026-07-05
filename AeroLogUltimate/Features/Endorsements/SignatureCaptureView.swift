import PencilKit
import SwiftUI

/// Full-screen Apple Pencil signature capture for CFI signing.
struct SignatureCaptureView: View {
    @Environment(\.dismiss) private var dismiss

    let endorsementTitle: String
    let onComplete: (Data, PKDrawing) -> Void

    @State private var drawing = PKDrawing()
    @State private var showClearConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            header
            signatureArea
            footer
        }
        .navigationTitle("Sign Endorsement")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Done") { complete() }
                    .fontWeight(.semibold)
                    .disabled(drawing.bounds.isEmpty)
            }
        }
        .alert("Clear Signature?", isPresented: $showClearConfirm) {
            Button("Clear", role: .destructive) { drawing = PKDrawing() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(endorsementTitle)
                .font(.headline)
            Text("Sign with Apple Pencil or finger")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
    }

    private var signatureArea: some View {
        ZStack(alignment: .bottomTrailing) {
            SignatureCanvasView(drawing: $drawing)
                .background(Color(.systemBackground))

            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 1)
                .padding(.horizontal, 24)
                .padding(.bottom, 48)

            Button("Clear") { showClearConfirm = true }
                .font(.caption)
                .padding()
        }
        .frame(maxHeight: .infinity)
    }

    private var footer: some View {
        Text("Your signature will be stored with this endorsement record.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding()
    }

    private func complete() {
        guard let data = SignatureRendering.pngData(from: drawing) else { return }
        onComplete(data, drawing)
        dismiss()
    }
}