import SwiftUI

/// Reusable destructive-action confirmation alert.
struct DeleteConfirmationModifier: ViewModifier {
    let title: String
    let message: String
    let confirmLabel: String
    @Binding var isPresented: Bool
    let onConfirm: () -> Void

    func body(content: Content) -> some View {
        content
            .alert(title, isPresented: $isPresented) {
                Button("Cancel", role: .cancel) {}
                Button(confirmLabel, role: .destructive, action: onConfirm)
            } message: {
                Text(message)
            }
    }
}

extension View {
    func deleteConfirmation(
        title: String = "Delete Entry?",
        message: String,
        confirmLabel: String = "Delete",
        isPresented: Binding<Bool>,
        onConfirm: @escaping () -> Void
    ) -> some View {
        modifier(DeleteConfirmationModifier(
            title: title,
            message: message,
            confirmLabel: confirmLabel,
            isPresented: isPresented,
            onConfirm: onConfirm
        ))
    }
}