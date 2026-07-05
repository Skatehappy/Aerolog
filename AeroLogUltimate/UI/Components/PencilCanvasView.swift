import PencilKit
import SwiftUI
import UIKit

/// Reusable Apple Pencil canvas for signatures, remarks, and annotations.
struct PencilCanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    var inkColor: UIColor = .label
    var preferPencilOnly: Bool = false
    var backgroundColor: UIColor = .clear

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawing = drawing
        canvas.delegate = context.coordinator
        canvas.drawingPolicy = preferPencilOnly ? .pencilOnly : .anyInput
        canvas.tool = PKInkingTool(.pen, color: inkColor, width: 2.5)
        canvas.backgroundColor = backgroundColor
        canvas.isOpaque = backgroundColor != .clear
        canvas.alwaysBounceVertical = false
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if uiView.drawing != drawing {
            uiView.drawing = drawing
        }
        uiView.drawingPolicy = preferPencilOnly ? .pencilOnly : .anyInput
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(drawing: $drawing)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding var drawing: PKDrawing

        init(drawing: Binding<PKDrawing>) {
            _drawing = drawing
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            drawing = canvasView.drawing
        }
    }
}

/// Toolbar for PencilKit canvases — pen, marker, eraser, clear.
struct PencilInkToolbar: View {
    @Binding var drawing: PKDrawing
    var inkUIColor: UIColor = .label

    @State private var selectedTool: PencilTool = .pen

    enum PencilTool: String, CaseIterable {
        case pen, marker, eraser

        var icon: String {
            switch self {
            case .pen: "pencil.tip"
            case .marker: "highlighter"
            case .eraser: "eraser"
            }
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ForEach(PencilTool.allCases, id: \.self) { tool in
                Button {
                    selectedTool = tool
                } label: {
                    Image(systemName: tool.icon)
                        .frame(width: 36, height: 36)
                        .background(
                            selectedTool == tool
                                ? Color.accentColor.opacity(0.2)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tool.rawValue.capitalized)
            }

            Spacer()

            Button("Clear") {
                drawing = PKDrawing()
            }
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .onChange(of: selectedTool) { _, tool in
            _ = tool
        }
    }
}