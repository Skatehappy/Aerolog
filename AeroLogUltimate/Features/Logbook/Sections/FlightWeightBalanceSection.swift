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

                Button("Add Station") {
                    stations.append(WeightBalanceStation(name: "Station \(stations.count + 1)"))
                    recalculate()
                }

                HStack {
                    Text("Forward CG Limit")
                    Spacer()
                    TextField("in", value: Binding(
                        get: { log.forwardCGLimit },
                        set: { log.forwardCGLimit = $0 }
                    ), format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 90)
                }
                HStack {
                    Text("Aft CG Limit")
                    Spacer()
                    TextField("in", value: Binding(
                        get: { log.aftCGLimit },
                        set: { log.aftCGLimit = $0 }
                    ), format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 90)
                }

                if let calculation {
                    HStack {
                        Text("Ramp Weight / CG")
                        Spacer()
                        Text(String(format: "%.0f lbs @ %.2f", calculation.totalWeight, calculation.centerOfGravity))
                            .foregroundStyle(calculation.isWithinLimits ? .secondary : .red)
                    }
                }

                TextField("Notes", text: Binding(
                    get: { log.notes ?? "" },
                    set: { log.notes = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                .lineLimit(2...4)
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