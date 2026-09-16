import Foundation
import HealthKit

struct HealthKitSwimSegment {
    let style: String          // freestyle | backstroke | breaststroke | butterfly | mixed | unknown
    let distanceM: Double?
    let durationSec: Double?
}

struct HealthKitWorkout {
    let id: String
    let workoutType: String
    let startedAt: Date
    let durationSec: Int
    let distance: Double?
    let energyBurned: Double?
    // Per-style swimming breakdown, only populated for swimming workouts where Apple Health
    // actually reported stroke styles. Empty otherwise (never invented).
    let swimmingSegments: [HealthKitSwimSegment]
}

final class HealthKitSyncService {
    private let healthStore = HKHealthStore()

    func fetchWorkouts(
        from startDate: Date,
        to endDate: Date
    ) async throws -> [HealthKitWorkout] {

        let workoutType = HKObjectType.workoutType()

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: true
        )

        let rawWorkouts: [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: samples as? [HKWorkout] ?? [])
            }
            healthStore.execute(query)
        }

        var result: [HealthKitWorkout] = []
        for workout in rawWorkouts {
            let distance = workout.totalDistance?.doubleValue(for: HKUnit.meter())
            let energyBurned = workout.totalEnergyBurned?.doubleValue(for: HKUnit.kilocalorie())
            let typeName = workout.workoutActivityType.aghealthName

            var segments: [HealthKitSwimSegment] = []
            if typeName == "swimming" {
                segments = await swimmingSegments(for: workout)
            }

            result.append(
                HealthKitWorkout(
                    id: workout.uuid.uuidString,
                    workoutType: typeName,
                    startedAt: workout.startDate,
                    durationSec: Int(workout.duration.rounded()),
                    distance: distance,
                    energyBurned: energyBurned,
                    swimmingSegments: segments
                )
            )
        }
        return result
    }

    // MARK: - Swimming stroke styles

    /// Extracts per-style distance + time for a swimming workout.
    ///
    /// IMPORTANT (fix): Apple stores the stroke style PER LAP, not per segment. `HKMetadataKey​
    /// SwimmingStrokeStyle` is documented as «the predominant stroke style for a lap of swimming» and
    /// is attached to each `distanceSwimming` sample (one per lap), and also to `.lap` workout
    /// events. The previous implementation only looked at `.segment` events — which pool swims
    /// usually don't have — so it returned no styles even though Apple Health shows them.
    ///
    /// New approach (primary): read the per-lap `distanceSwimming` samples for this workout and
    /// aggregate distance + duration by their stroke-style metadata. Falls back to `.lap`/`.segment`
    /// event metadata when samples carry no style. Never fabricates a style.
    private func swimmingSegments(for workout: HKWorkout) async -> [HealthKitSwimSegment] {
        var distanceByStyle: [String: Double] = [:]
        var durationByStyle: [String: Double] = [:]
        var sawAnyStyle = false

        // PRIMARY: per-lap distanceSwimming samples, each with its stroke-style metadata.
        let lapSamples = await swimDistanceSamples(for: workout)
        for sample in lapSamples {
            guard let styleRaw = sample.metadata?[HKMetadataKeySwimmingStrokeStyle] as? Int else { continue }
            sawAnyStyle = true
            let style = Self.styleName(fromRawValue: styleRaw)
            distanceByStyle[style, default: 0] += sample.quantity.doubleValue(for: HKUnit.meter())
            durationByStyle[style, default: 0] += sample.endDate.timeIntervalSince(sample.startDate)
        }

        // FALLBACK: lap / segment events carrying the style, when samples had none.
        if !sawAnyStyle, let events = workout.workoutEvents {
            let styleEvents = events.filter { $0.type == .lap || $0.type == .segment }
            for event in styleEvents {
                guard let styleRaw = event.metadata?[HKMetadataKeySwimmingStrokeStyle] as? Int else { continue }
                sawAnyStyle = true
                let style = Self.styleName(fromRawValue: styleRaw)
                let interval = event.dateInterval
                durationByStyle[style, default: 0] += interval.duration
                if let dist = await swimDistance(in: interval) {
                    distanceByStyle[style, default: 0] += dist
                }
            }
        }

        // No stroke style anywhere → don't invent one.
        guard sawAnyStyle else { return [] }

        let styles = Set(distanceByStyle.keys).union(durationByStyle.keys)
        return styles.map { style in
            HealthKitSwimSegment(
                style: style,
                distanceM: distanceByStyle[style].map { ($0 * 10).rounded() / 10 },
                durationSec: durationByStyle[style].map { $0.rounded() }
            )
        }
    }

    /// Fetches the per-lap `distanceSwimming` samples for a workout (each lap sample carries the
    /// stroke-style metadata). Uses `predicateForObjects(from:)` so only this workout's laps return.
    private func swimDistanceSamples(for workout: HKWorkout) async -> [HKQuantitySample] {
        guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceSwimming) else {
            return []
        }
        let predicate = HKQuery.predicateForObjects(from: workout)
        return await withCheckedContinuation { continuation in
            let q = HKSampleQuery(
                sampleType: distanceType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            healthStore.execute(q)
        }
    }

    /// Sums `distanceSwimming` (meters) over a time interval (fallback path for event-based styles).
    private func swimDistance(in interval: DateInterval) async -> Double? {
        guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceSwimming) else {
            return nil
        }
        let predicate = HKQuery.predicateForSamples(
            withStart: interval.start,
            end: interval.end,
            options: .strictStartDate
        )
        return await withCheckedContinuation { continuation in
            let q = HKStatisticsQuery(
                quantityType: distanceType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, _ in
                let meters = stats?.sumQuantity()?.doubleValue(for: HKUnit.meter())
                continuation.resume(returning: meters)
            }
            healthStore.execute(q)
        }
    }

    /// Maps an `HKSwimmingStrokeStyle` raw value to our backend style vocabulary.
    static func styleName(fromRawValue raw: Int?) -> String {
        guard let raw, let style = HKSwimmingStrokeStyle(rawValue: raw) else { return "unknown" }
        switch style {
        case .freestyle: return "freestyle"
        case .backstroke: return "backstroke"
        case .breaststroke: return "breaststroke"
        case .butterfly: return "butterfly"
        case .mixed: return "mixed"
        case .unknown: return "unknown"
        @unknown default: return "unknown"
        }
    }
}

private extension HKWorkoutActivityType {

    var aghealthName: String {
        switch self {
        case .running:
            return "running"

        case .walking:
            return "walking"

        case .cycling:
            return "cycling"

        case .swimming:
            return "swimming"

        case .traditionalStrengthTraining:
            return "strength"

        case .functionalStrengthTraining:
            return "strength"

        case .tennis:
            return "tennis"

        default:
            return "other"
        }
    }
}
