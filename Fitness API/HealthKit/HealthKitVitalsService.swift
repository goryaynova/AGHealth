import Foundation
import HealthKit

// Читает последние значения показателей, которые пока не хранятся в бэкенде: пульс покоя и HRV.
// Только чтение из Apple Health; если данных нет — возвращает nil (ничего не выдумываем).
struct HealthVitals {
    let restingHeartRate: Double?   // уд/мин
    let hrvSDNN: Double?            // мс
}

final class HealthKitVitalsService {
    private let healthStore = HKHealthStore()

    func fetchLatest() async -> HealthVitals {
        async let rhr = latestQuantity(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()))
        async let hrv = latestQuantity(.heartRateVariabilitySDNN, unit: HKUnit.secondUnit(with: .milli))
        return HealthVitals(restingHeartRate: await rhr, hrvSDNN: await hrv)
    }

    // Последний сэмпл заданного количественного типа за последние 30 дней.
    private func latestQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        let start = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        return await withCheckedContinuation { continuation in
            let q = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            healthStore.execute(q)
        }
    }
}
