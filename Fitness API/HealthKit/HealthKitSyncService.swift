import Foundation
import HealthKit

struct HealthKitWorkout {
    let id: String
    let workoutType: String
    let startedAt: Date
    let durationSec: Int
    let distance: Double?
    let energyBurned: Double?
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

        return try await withCheckedThrowingContinuation { continuation in

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

                let workouts = (samples as? [HKWorkout] ?? []).map { workout in
                    let distance = workout.totalDistance?.doubleValue(
                        for: HKUnit.meter()
                    )

                    let energyBurned = workout.totalEnergyBurned?.doubleValue(
                        for: HKUnit.kilocalorie()
                    )

                    return HealthKitWorkout(
                        id: workout.uuid.uuidString,
                        workoutType: workout.workoutActivityType.aghealthName,
                        startedAt: workout.startDate,
                        durationSec: Int(workout.duration.rounded()),
                        distance: distance,
                        energyBurned: energyBurned
                    )
                }

                continuation.resume(returning: workouts)
            }

            healthStore.execute(query)
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
