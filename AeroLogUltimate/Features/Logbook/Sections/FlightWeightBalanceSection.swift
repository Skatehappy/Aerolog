import SwiftUI

struct FlightWeightBalanceSection: View {
    @Environment(\.appEnvironment) private var environment
    @Bindable var flight: Flight

    @State private var log: WeightBalanceLog?
    @State private var stations: [WeightBalanceStation] = []
    @State private var calculation: WeightBalanceCalculator.Result?

    var body: some View {
        Section {
            if let log {
                WeightBalanceWorksheetForm(
                    log: log,
                    stations: $stations,
                    calculation: calculation,
                    onAddStation: addStation
                )
            } else {
                Button("Add Weight & Balance Worksheet") {
                    loadLog(createIfNeeded: true)
                }
            }
        } header: {
            FormSectionHeader(title: "Weight & Balance", systemImage: "scalemass")
        }
        .onAppear { loadLog(createIfNeeded: false) }
        .onChange(of: log?.emptyWeight) { _, _ in recalculate() }
        .onChange(of: log?.emptyArm) { _, _ in recalculate() }
        .onChange(of: stations) { _, _ in recalculate() }
        .onChange(of: log?.forwardCGLimit) { _, _ in recalculate() }
        .onChange(of: log?.aftCGLimit) { _, _ in recalculate() }
    }

    private func addStation() {
        stations.append(WeightBalanceStation(name: "Station \(stations.count + 1)"))
        recalculate()
    }

    private func loadLog(createIfNeeded: Bool) {
        if let existing = flight.weightBalanceLog {
            log = existing
            stations = existing.stationEntries
            recalculate()
            return
        }
        guard createIfNeeded else { return }
        do {
            log = try environment?.flightService.ensureWeightBalanceLog(for: flight)
            stations = [
                WeightBalanceStation(name: "Pilot", weight: 0, arm: 0),
                WeightBalanceStation(name: "Fuel", weight: 0, arm: 0)
            ]
            recalculate()
        } catch {}
    }

    private func recalculate() {
        guard let log else { return }
        log.stationEntries = stations
        calculation = WeightBalanceCalculator.calculate(
            emptyWeight: log.emptyWeight,
            emptyArm: log.emptyArm,
            stations: stations,
            forwardLimit: log.forwardCGLimit,
            aftLimit: log.aftCGLimit
        )
        log.rampWeight = calculation?.totalWeight
        log.rampCG = calculation?.centerOfGravity
        try? environment?.flightService.updateWeightBalance(log)
    }
}

private struct WeightBalanceWorksheetForm: View {
    @Bindable var log: WeightBalanceLog
    @Binding var stations: [WeightBalanceStation]
    let calculation: WeightBalanceCalculator.Result?
    let onAddStation: () -> Void

    var body: some View {
        WeightBalanceEmptyWeightFields(log: log)
        WeightBalanceStationList(stations: $stations)
        Button("Add Station", action: onAddStation)
        WeightBalanceLimitFields(log: log)
        WeightBalanceCalculationRow(calculation: calculation)
        WeightBalanceNotesField(log: log)
    }
}

private struct WeightBalanceEmptyWeightFields: View {
    @Bindable var log: WeightBalanceLog

    var body: some View {
        HStack {
            Text("Empty Weight")
            Spacer()
            TextField("lbs", value: $log.emptyWeight, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 90)
        }
        HStack {
            Text("Empty Arm")
            Spacer()
            TextField("in", value: $log.emptyArm, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 90)
        }
    }
}

private struct WeightBalanceStationList: View {
    @Binding var stations: [WeightBalanceStation]

    var body: some View {
        ForEach($stations) { $station in
            VStack(alignment: .leading, spacing: 8) {
                TextField("Station name", text: $station.name)
                HStack {
                    TextField("Weight", value: $station.weight, format: .number)
                        .keyboardType(.decimalPad)
                    TextField("Arm", value: $station.arm, format: .number)
                        .keyboardType(.decimalPad)
                }
            }
        }
    }
}

private struct WeightBalanceLimitFields: View {
    @Bindable var log: WeightBalanceLog

    var body: some View {
        HStack {
            Text("Forward CG Limit")
            Spacer()
            optionalNumberField(value: $log.forwardCGLimit, placeholder: "in")
        }
        HStack {
            Text("Aft CG Limit")
            Spacer()
            optionalNumberField(value: $log.aftCGLimit, placeholder: "in")
        }
    }

    private func optionalNumberField(value: Binding<Double?>, placeholder: String) -> some View {
        TextField(placeholder, value: value, format: .number)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 90)
    }
}

private struct WeightBalanceCalculationRow: View {
    let calculation: WeightBalanceCalculator.Result?

    var body: some View {
        if let calculation {
            HStack {
                Text("Ramp Weight / CG")
                Spacer()
                Text(String(format: "%.0f lbs @ %.2f", calculation.totalWeight, calculation.centerOfGravity))
                    .foregroundStyle(calculation.isWithinLimits ? Color.secondary : Color.red)
            }
        }
    }
}

private struct WeightBalanceNotesField: View {
    @Bindable var log: WeightBalanceLog

    var body: some View {
        TextField("Notes", text: notesBinding, axis: .vertical)
            .lineLimit(2...4)
    }

    private var notesBinding: Binding<String> {
        Binding(
            get: { log.notes ?? "" },
            set: { log.notes = $0.isEmpty ? nil : $0 }
        )
    }
}