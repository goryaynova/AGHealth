import HealthKit

final class HealthKitManager {
    private let healthStore = HKHealthStore()
    
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        
        let readTypes: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            
            HKObjectType.quantityType(
                forIdentifier: .heartRate
            )!,
            
            HKObjectType.quantityType(
                forIdentifier: .stepCount
            )!,
            
            HKObjectType.quantityType(
                forIdentifier: .activeEnergyBurned
            )!,
            
            HKObjectType.quantityType(
                forIdentifier: .distanceWalkingRunning
            )!,
            
            HKObjectType.quantityType(
                forIdentifier: .distanceCycling
            )!,

            // Per-lap swimming distance — carries the stroke-style metadata
            // (HKMetadataKeySwimmingStrokeStyle). Required to read swimming styles.
            HKObjectType.quantityType(
                forIdentifier: .distanceSwimming
            )!,

            HKObjectType.quantityType(
                forIdentifier: .bodyMass
            )!,
            
            HKObjectType.quantityType(
                forIdentifier: .height
            )!,
            
            HKObjectType.categoryType(
                forIdentifier: .menstrualFlow
            )!,

            // Sleep analysis — for the Sleep dashboards + deterministic recovery score.
            HKObjectType.categoryType(
                forIdentifier: .sleepAnalysis
            )!,

            // Пульс покоя и HRV — для дашбордов «Здоровье → Общее».
            HKObjectType.quantityType(
                forIdentifier: .restingHeartRate
            )!,

            HKObjectType.quantityType(
                forIdentifier: .heartRateVariabilitySDNN
            )!
        ]
        
        try await healthStore.requestAuthorization(
            toShare: [],
            read: readTypes
        )
    }
}

enum HealthKitError: Error {
    case notAvailable
}
