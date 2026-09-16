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

    /// Extracts per-style distance + time for a swimming workout from HealthKit's segment events.
    /// Each `.segment` workout event carries a `HKMetadataKeySwimmingStrokeStyle` value; per-segment
    /// distance is summed from `distanceSwimming` samples within the segment's time interval.
    /// Returns an aggregated [style → distance/time]; empty if Apple Health reported no styles.
    private func swimmingSegments(for workout: HKWorkout) async -> [HealthKitSwimSegment] {
        guard let events = workout.workoutEvents else { return [] }
        let segmentEvents = events.filter { $0.type == .segment }
        guard !segmentEvents.isEmpty else { return [] }

        // Aggregate distance + duration by style.
        var distanceByStyle: [String: Double] = [:]
        var durationByStyle: [String: Double] = [:]
        var sawAnyStyle = false

        for event in segmentEvents {
            let styleRaw = event.metadata?[HKMetadataKeySwimmingStrokeStyle] as? Int
            let style = Self.styleName(fromRawValue: styleRaw)
            if styleRaw != nil { sawAnyStyle = true }

            let interval = event.dateInterval
            durationByStyle[style, default: 0] += interval.duration

            let dist = await swimDistance(in: interval)
            if let dist { distanceByStyle[style, default: 0] += dist }
        }

        // If Apple Health provided segments but no stroke style at all, don't fabricate styles.
        guard sawAnyStyle else { return [] }

        let styles = Set(distanceByStyle.keys).union(durationByStyle.keys)
        return styles.map { style in
            HealthKitSwimSegment(
                style: style,
                distanceM: distanceByStyle[style],
                durationSec: durationByStyle[style]
            )
        }
    }

    /// Sums `distanceSwimming` (meters) over a time interval.
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
