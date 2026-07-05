import PencilKit
import SwiftUI
import UIKit

/// Apple Pencil signature capture canvas using PencilKit.
struct SignatureCanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    var inkColor: UIColor = .label

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawing = drawing
        canvas.delegate = context.coordinator
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: inkColor, width: 3)
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if uiView.drawing != drawing {
            uiView.drawing = drawing
        }
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

enum SignatureRendering {
    static func pngData(from drawing: PKDrawing, bounds: CGRect = CGRect(x: 0, y: 0, width: 600, height: 200)) -> Data? {
        let image = drawing.image(from: drawing.bounds.isEmpty ? bounds : drawing.bounds, scale: 2.0)
        return image.pngData()
    }

    static func image(from data: Data?) -> UIImage? {
        guard let data else { return nil }
        return UIImage(data: data)
    }
}