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
            
            HKObjectType.quantityType(
                forIdentifier: .bodyMass
            )!,
            
            HKObjectType.quantityType(
                forIdentifier: .height
            )!,
            
            HKObjectType.categoryType(
                forIdentifier: .menstrualFlow
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
