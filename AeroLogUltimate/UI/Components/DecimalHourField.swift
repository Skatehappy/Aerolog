import SwiftUI

/// Text field for entering logbook time as decimal hours or H:MM.
struct DecimalHourField: View {
    let label: String
    @Binding var value: Double
    var prompt: String = "0.0"

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField(prompt, text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 100)
                .focused($isFocused)
                .onAppear { syncTextFromValue() }
                .onChange(of: value) { _, _ in
                    if !isFocused { syncTextFromValue() }
                }
                .onChange(of: text) { _, newValue in
                    if let parsed = TimeFormatting.parse(newValue) {
                        value = parsed
                    }
                }
        }
    }

    private func syncTextFromValue() {
        text = value == 0 ? "" : TimeFormatting.display(value)
    }
}