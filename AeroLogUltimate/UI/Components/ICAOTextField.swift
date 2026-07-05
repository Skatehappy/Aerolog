import SwiftUI

/// Uppercase airport identifier field (ICAO/FAA codes).
struct ICAOTextField: View {
    let label: String
    @Binding var text: String
    var prompt: String = "KXXX"

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField(prompt, text: $text)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 120)
                .onChange(of: text) { _, newValue in
                    text = newValue.uppercased()
                }
        }
    }
}