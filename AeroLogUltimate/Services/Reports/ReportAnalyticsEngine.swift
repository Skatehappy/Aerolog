import Foundation

/// Aggregates logbook flights into analytics and report payloads.
struct ReportAnalyticsEngine: Sendable {
    func filteredFlights(_ flights: [Flight], filter: ReportFilter) -> [Flight] {
        flights.filter { filter.matches($0) }.sorted { $0.flightDate > $1.flightDate }
    }

    // MARK: - Dashboard

    func dashboard(flights: [Flight], filter: ReportFilter, pilot: PilotProfile) -> AnalyticsDashboard {
        let scoped = filteredFlights(flights, filter: filter)
        return AnalyticsDashboard(
            calculatedAt: .now,
            filter: filter,
            pilotName: pilot.fullName,
            totalFlights: scoped.count,
            totalTime: scoped.reduce(0) { $0 + $1.totalTime },
            picTime: scoped.reduce(0) { $0 + $1.picTime },
            dualReceived: scoped.reduce(0) { $0 + $1.dualReceived },
            dualGiven: scoped.reduce(0) { $0 + $1.dualGiven },
            soloTime: scoped.reduce(0) { $0 + $1.soloTime },
            crossCountryTime: scoped.reduce(0) { $0 + $1.crossCountryTime },
            nightTime: scoped.reduce(0) { $0 + $1.nightTime },
            actualInstrumentTime: scoped.reduce(0) { $0 + $1.actualInstrumentTime },
            simulatedInstrumentTime: scoped.reduce(0) { $0 + $1.simulatedInstrumentTime },
            dayLandings: scoped.reduce(0) { $0 + $1.dayLandings },
            nightLandings: scoped.reduce(0) { $0 + $1.nightLandings },
            monthlyBuckets: monthlyBreakdown(flights: scoped),
            topAirports: airportStatistics(flights: scoped).prefix(5).map { $0 },
            topAircraft: aircraftStatistics(flights: scoped).prefix(5).map { $0 }
        )
    }

    // MARK: - Total Time

    func totalTimeSummary(flights: [Flight], filter: ReportFilter, pilot: PilotProfile) -> TotalTimeSummary {
        let scoped = filteredFlights(flights, filter: filter)
        return TotalTimeSummary(
            pilotName: pilot.fullName,
            generatedAt: .now,
            filterSummary: filter.displaySummary,
            totalFlights: scoped.count,
            totalTime: sum(scoped, \.totalTime),
            picTime: sum(scoped, \.picTime),
            sicTime: sum(scoped, \.sicTime),
            dualReceived: sum(scoped, \.dualReceived),
            dualGiven: sum(scoped, \.dualGiven),
            soloTime: sum(scoped, \.soloTime),
            crossCountryTime: sum(scoped, \.crossCountryTime),
            nightTime: sum(scoped, \.nightTime),
            actualInstrumentTime: sum(scoped, \.actualInstrumentTime),
            simulatedInstrumentTime: sum(scoped, \.simulatedInstrumentTime),
            groundInstructionTime: sum(scoped, \.groundInstructionTime),
            simulatorTime: sum(scoped, \.simulatorTime),
            dayLandings: scoped.reduce(0) { $0 + $1.dayLandings },
            nightLandings: scoped.reduce(0) { $0 + $1.nightLandings },
            fullStopDayLandings: scoped.reduce(0) { $0 + $1.fullStopDayLandings },
            fullStopNightLandings: scoped.reduce(0) { $0 + $1.fullStopNightLandings },
            holds: scoped.reduce(0) { $0 + $1.holds },
            approachCount: scoped.reduce(0) { $0 + $1.totalApproachCount }
        )
    }

    // MARK: - FAA 8710

    func faa8710Totals(flights: [Flight], filter: ReportFilter, pilot: PilotProfile) -> FAA8710Totals {
        let scoped = filteredFlights(flights, filter: filter)
        var singleEngine: Double = 0
        var multiEngine: Double = 0
        var helicopter: Double = 0

        for flight in scoped {
            guard let aircraft = flight.aircraft else { continue }
            switch aircraft.category {
            case .airplane:
                if aircraft.aircraftClass == .multiEngineLand || aircraft.aircraftClass == .multiEngineSea {
                    multiEngine += flight.totalTime
                } else {
                    singleEngine += flight.totalTime
                }
            case .rotorcraft:
                helicopter += flight.totalTime
            default:
                break
            }
        }

        let address = [pilot.addressLine1, pilot.city, pilot.state, pilot.postalCode]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
            .joined(separator: ", ")

        return FAA8710Totals(
            pilotName: pilot.fullName,
            certificateNumber: pilot.certificateNumber,
            addressLine: address.isEmpty ? nil : address,
            generatedAt: .now,
            totalTime: sum(scoped, \.totalTime),
            picTime: sum(scoped, \.picTime),
            sicTime: sum(scoped, \.sicTime),
            dualReceived: sum(scoped, \.dualReceived),
            soloTime: sum(scoped, \.soloTime),
            crossCountryTime: sum(scoped, \.crossCountryTime),
            nightTime: sum(scoped, \.nightTime),
            actualInstrumentTime: sum(scoped, \.actualInstrumentTime),
            simulatedInstrumentTime: sum(scoped, \.simulatedInstrumentTime),
            dayLandings: scoped.reduce(0) { $0 + $1.dayLandings },
            nightLandings: scoped.reduce(0) { $0 + $1.nightLandings },
            airplaneSingleEngineLand: singleEngine,
            airplaneMultiEngineLand: multiEngine,
            rotorcraftHelicopter: helicopter,
            simulatorTime: sum(scoped, \.simulatorTime),
            instructorTime: sum(scoped, \.dualGiven) + sum(scoped, \.groundInstructionTime)
        )
    }

    // MARK: - Flight Log

    func flightLogRows(flights: [Flight], filter: ReportFilter) -> [FlightLogRow] {
        filteredFlights(flights, filter: filter).map { flight in
            FlightLogRow(
                id: flight.syncID,
                date: flight.flightDate,
                aircraft: flight.aircraftDisplay,
                route: flight.routeSummary,
                role: flight.role,
                totalTime: flight.totalTime,
                picTime: flight.picTime,
                sicTime: flight.sicTime,
                dualReceived: flight.dualReceived,
                dualGiven: flight.dualGiven,
                soloTime: flight.soloTime,
                nightTime: flight.nightTime,
                crossCountryTime: flight.crossCountryTime,
                actualInstrumentTime: flight.actualInstrumentTime,
                simulatedInstrumentTime: flight.simulatedInstrumentTime,
                groundInstructionTime: flight.groundInstructionTime,
                simulatorTime: flight.simulatorTime,
                dayLandings: flight.dayLandings,
                nightLandings: flight.nightLandings,
                fullStopDayLandings: flight.fullStopDayLandings,
                fullStopNightLandings: flight.fullStopNightLandings,
                holds: flight.holds,
                approachCount: flight.totalApproachCount,
                instructorName: flight.instructorName,
                remarks: flight.remarks
            )
        }
    }

    // MARK: - Airport Stats

    func airportStatistics(flights: [Flight], filter: ReportFilter = .allTime) -> [AirportStatistic] {
        let scoped = filteredFlights(flights, filter: filter)
        var stats: [String: (departures: Int, arrivals: Int, time: Double)] = [:]

        for flight in scoped {
            if !flight.departureICAO.isEmpty {
                var entry = stats[flight.departureICAO] ?? (0, 0, 0)
                entry.departures += 1
                entry.time += flight.totalTime
                stats[flight.departureICAO] = entry
            }
            if !flight.arrivalICAO.isEmpty {
                var entry = stats[flight.arrivalICAO] ?? (0, 0, 0)
                entry.arrivals += 1
                if flight.departureICAO != flight.arrivalICAO {
                    entry.time += flight.totalTime
                }
                stats[flight.arrivalICAO] = entry
            }
            for leg in flight.sortedLegs {
                if !leg.departureICAO.isEmpty {
                    var entry = stats[leg.departureICAO] ?? (0, 0, 0)
                    entry.departures += 1
                    entry.time += leg.legTime
                    stats[leg.departureICAO] = entry
                }
                if !leg.arrivalICAO.isEmpty {
                    var entry = stats[leg.arrivalICAO] ?? (0, 0, 0)
                    entry.arrivals += 1
                    stats[leg.arrivalICAO] = entry
                }
            }
        }

        return stats.map { icao, value in
            AirportStatistic(
                icao: icao,
                departures: value.departures,
                arrivals: value.arrivals,
                totalTime: value.time
            )
        }
        .sorted { $0.visitCount > $1.visitCount }
    }

    // MARK: - Aircraft Stats

    func aircraftStatistics(flights: [Flight], filter: ReportFilter = .allTime) -> [AircraftStatistic] {
        let scoped = filteredFlights(flights, filter: filter)
        var stats: [UUID: (aircraft: Aircraft, count: Int, time: Double)] = [:]

        for flight in scoped {
            guard let aircraft = flight.aircraft else { continue }
            let key = aircraft.syncID
            var entry = stats[key] ?? (aircraft, 0, 0)
            entry.count += 1
            entry.time += flight.totalTime
            stats[key] = entry
        }

        return stats.values.map { entry in
            AircraftStatistic(
                id: entry.aircraft.syncID,
                registration: entry.aircraft.registration,
                makeModel: "\(entry.aircraft.make) \(entry.aircraft.model)",
                flightCount: entry.count,
                totalTime: entry.time
            )
        }
        .sorted { $0.totalTime > $1.totalTime }
    }

    // MARK: - Student Progress

    func studentProgress(flights: [Flight], filter: ReportFilter, instructor: PilotProfile) -> StudentProgressReport {
        let scoped = filteredFlights(flights, filter: filter)
            .filter { $0.instructor?.persistentModelID == instructor.persistentModelID || $0.role == .dualGiven }

        var byStudent: [String: [Flight]] = [:]
        for flight in scoped {
            let name = flight.pilot?.fullName ?? "Unknown Student"
            byStudent[name, default: []].append(flight)
        }

        let entries = byStudent.map { name, studentFlights -> StudentProgressEntry in
            let sorted = studentFlights.sorted { $0.flightDate > $1.flightDate }
            let last = sorted.first
            return StudentProgressEntry(
                studentName: name,
                dualGivenTime: studentFlights.reduce(0) { $0 + $1.dualGiven },
                groundInstructionTime: studentFlights.reduce(0) { $0 + $1.groundInstructionTime },
                flightCount: studentFlights.count,
                lastLessonDate: last?.flightDate,
                lastLessonTitle: last?.lessonTitle
            )
        }
        .sorted { $0.studentName < $1.studentName }

        return StudentProgressReport(
            instructorName: instructor.fullName,
            generatedAt: .now,
            students: entries
        )
    }

    // MARK: - Monthly Breakdown

    func monthlyBreakdown(flights: [Flight]) -> [MonthlyTimeBucket] {
        let calendar = Calendar.current
        var buckets: [String: (year: Int, month: Int, count: Int, time: Double)] = [:]

        for flight in flights {
            let year = calendar.component(.year, from: flight.flightDate)
            let month = calendar.component(.month, from: flight.flightDate)
            let key = "\(year)-\(month)"
            var entry = buckets[key] ?? (year, month, 0, 0)
            entry.count += 1
            entry.time += flight.totalTime
            buckets[key] = entry
        }

        return buckets.values
            .map { MonthlyTimeBucket(year: $0.year, month: $0.month, flightCount: $0.count, totalTime: $0.time) }
            .sorted {
                if $0.year != $1.year { return $0.year < $1.year }
                return $0.month < $1.month
            }
    }

    private func sum(_ flights: [Flight], _ keyPath: KeyPath<Flight, Double>) -> Double {
        flights.reduce(0) { $0 + $1[keyPath: keyPath] }
    }
}