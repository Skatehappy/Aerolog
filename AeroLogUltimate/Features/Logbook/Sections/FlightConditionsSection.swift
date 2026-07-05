import SwiftUI

struct FlightConditionsSection: View {
    @Bindable var flight: Flight

    private var selected: Set<FlightCondition> {
        Set(flight.conditions)
    }

    var body: some View {
        Section {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                ForEach(FlightCondition.allCases, id: \.self) { condition in
                    ConditionChip(
                        condition: condition,
                        isSelected: selected.contains(condition)
                    ) {
                        toggle(condition)
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            FormSectionHeader(title: "Conditions", systemImage: "cloud.sun")
        }
    }

    private func toggle(_ condition: FlightCondition) {
        var current = flight.conditions
        if let index = current.firstIndex(of: condition) {
            current.remove(at: index)
        } else {
            current.append(condition)
        }
        flight.setConditions(current)
    }
}

private struct ConditionChip: View {
    let condition: FlightCondition
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: condition.systemImage)
                    .font(.caption)
                Text(condition.displayName)
                    .font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color(.tertiarySystemFill))
            .foregroundStyle(isSelected ? Color.accentColor : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}