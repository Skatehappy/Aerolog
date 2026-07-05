import Foundation

/// Pure W&B math for worksheets and validation.
enum WeightBalanceCalculator {
    struct Result: Sendable, Equatable {
        let totalWeight: Double
        let centerOfGravity: Double
        let totalMoment: Double
        let isWithinLimits: Bool
    }

    static func calculate(
        emptyWeight: Double,
        emptyArm: Double,
        stations: [WeightBalanceStation],
        forwardLimit: Double?,
        aftLimit: Double?
    ) -> Result {
        let emptyMoment = emptyWeight * emptyArm
        let stationMoment = stations.reduce(0) { $0 + $1.moment }
        let stationWeight = stations.reduce(0) { $0 + $1.weight }
        let totalWeight = emptyWeight + stationWeight
        let totalMoment = emptyMoment + stationMoment
        let cg = totalWeight > 0 ? totalMoment / totalWeight : emptyArm

        let withinForward = forwardLimit.map { cg >= $0 } ?? true
        let withinAft = aftLimit.map { cg <= $0 } ?? true

        return Result(
            totalWeight: totalWeight,
            centerOfGravity: cg,
            totalMoment: totalMoment,
            isWithinLimits: withinForward && withinAft
        )
    }

    static func apply(to log: WeightBalanceLog) {
        let result = calculate(
            emptyWeight: log.emptyWeight,
            emptyArm: log.emptyArm,
            stations: log.stationEntries,
            forwardLimit: log.forwardCGLimit,
            aftLimit: log.aftCGLimit
        )
        log.rampWeight = result.totalWeight
        log.rampCG = result.centerOfGravity
    }
}