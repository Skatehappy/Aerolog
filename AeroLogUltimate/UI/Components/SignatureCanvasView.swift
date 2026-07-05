import PencilKit
import SwiftUI
import UIKit

/// Apple Pencil signature capture canvas using PencilKit.
struct SignatureCanvasView: View {
    @Binding var drawing: PKDrawing
    var inkColor: UIColor = .label
    var preferPencilOnly: Bool = false

    var body: some View {
        PencilCanvasView(
            drawing: $drawing,
            inkColor: inkColor,
            preferPencilOnly: preferPencilOnly,
            backgroundColor: .clear
        )
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