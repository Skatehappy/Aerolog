import SwiftUI

/// Labeled integer stepper for landings, holds, and approach counts.
struct StepperField: View {
    let label: String
    @Binding var value: Int
    var range: ClosedRange<Int> = 0...99

    var body: some View {
        Stepper(value: $value, in: range) {
            HStack {
                Text(label)
                Spacer()
                Text("\(value)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
}