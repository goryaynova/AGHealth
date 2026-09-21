import Foundation
import HealthKit

struct MenstrualCycleRecord: Identifiable {
    let id: String
    let startDate: Date
    let endDate: Date
    let durationDays: Int
}

struct CycleAnalytics {
    let periods: [MenstrualCycleRecord]
    let cycleLengths: [Int]
    
    let averageCycleLength: Double?
    let shortestCycle: Int?
    let longestCycle: Int?
    let cycleVariation: Double?
    
    let averagePeriodLength: Double?
    
    let latestPeriodStart: Date?
    let currentCycleDay: Int?
    
    let predictedNextPeriod: Date?
    let predictedPMSStart: Date?
    let predictedPMSEnd: Date?
    
    let currentPhase: CyclePhase
}

enum CyclePhase {
    case menstruation
    case follicular
    case ovulation
    case luteal
    case unknown
    
    var title: String {
        switch self {
        case .menstruation:
            return "Менструация"
        case .follicular:
            return "Фолликулярная фаза"
        case .ovulation:
            return "Овуляция"
        case .luteal:
            return "Лютеиновая фаза"
        case .unknown:
            return "Недостаточно данных"
        }
    }
}

final class HealthKitCycleService {
    private let healthStore = HKHealthStore()

    // Запрашивает разрешение НА ЗАПИСЬ menstrualFlow (для кнопки «Отметить месячные»).
    func requestWriteAuthorization() async throws {
        guard let type = HKObjectType.categoryType(forIdentifier: .menstrualFlow) else { return }
        try await healthStore.requestAuthorization(toShare: [type], read: [type])
    }

    // Отмечает менструацию за указанный день (по умолчанию — сегодня). Идемпотентно:
    // если за этот день уже есть запись — не дублируем.
    func logMenstrualFlow(for date: Date = Date()) async throws {
        guard let type = HKObjectType.categoryType(forIdentifier: .menstrualFlow) else { return }
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: date)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)?.addingTimeInterval(-1) ?? date

        // Проверяем, нет ли уже записи за этот день.
        let existing = try await fetchMenstrualSamples(from: dayStart, to: dayEnd)
        if !existing.isEmpty { return }

        let value = HKCategoryValueMenstrualFlow.medium.rawValue
        var metadata: [String: Any] = [:]
        metadata[HKMetadataKeyMenstrualCycleStart] = false
        let sample = HKCategorySample(
            type: type,
            value: value,
            start: dayStart,
            end: dayEnd,
            metadata: metadata
        )
        try await healthStore.save(sample)
    }
    
    func fetchAnalytics(
        for year: Int = Calendar.current.component(
            .year,
            from: Date()
        )
    ) async throws -> CycleAnalytics {
        
        let calendar = Calendar.current
        
        guard
            let startDate = calendar.date(
                from: DateComponents(
                    year: year,
                    month: 1,
                    day: 1
                )
            ),
            let endDate = calendar.date(
                from: DateComponents(
                    year: year + 1,
                    month: 1,
                    day: 1
                )
            )
        else {
            return emptyAnalytics()
        }
        
        let samples = try await fetchMenstrualSamples(
            from: startDate,
            to: endDate
        )
        
        let periods = buildPeriods(
            from: samples,
            calendar: calendar
        )
        
        return calculateAnalytics(
            periods: periods,
            today: Date(),
            calendar: calendar
        )
    }
    
    // MARK: - HealthKit
    
    private func fetchMenstrualSamples(
        from startDate: Date,
        to endDate: Date
    ) async throws -> [HKCategorySample] {
        
        guard let menstrualType = HKObjectType.categoryType(
            forIdentifier: .menstrualFlow
        ) else {
            return []
        }
        
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
                sampleType: menstrualType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                
                if let error {
                    continuation.resume(
                        throwing: error
                    )
                    return
                }
                
                continuation.resume(
                    returning: samples as? [HKCategorySample] ?? []
                )
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Period detection
    
    private func buildPeriods(
        from samples: [HKCategorySample],
        calendar: Calendar
    ) -> [MenstrualCycleRecord] {
        
        guard !samples.isEmpty else {
            return []
        }
        
        let sortedSamples = samples.sorted {
            $0.startDate < $1.startDate
        }
        
        var groups: [[HKCategorySample]] = []
        var currentGroup: [HKCategorySample] = []
        
        for sample in sortedSamples {
            
            if currentGroup.isEmpty {
                currentGroup = [sample]
                continue
            }
            
            let previous = currentGroup[currentGroup.count - 1]
            
            let daysBetween = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(
                    for: previous.startDate
                ),
                to: calendar.startOfDay(
                    for: sample.startDate
                )
            ).day ?? 0
            
            if daysBetween <= 1 {
                currentGroup.append(sample)
            } else {
                groups.append(currentGroup)
                currentGroup = [sample]
            }
        }
        
        if !currentGroup.isEmpty {
            groups.append(currentGroup)
        }
        
        return groups.compactMap { group in
            
            guard
                let first = group.first,
                let last = group.last
            else {
                return nil
            }
            
            let startDate = calendar.startOfDay(
                for: first.startDate
            )
            
            let endDate = calendar.startOfDay(
                for: last.startDate
            )
            
            let duration = (
                calendar.dateComponents(
                    [.day],
                    from: startDate,
                    to: endDate
                ).day ?? 0
            ) + 1
            
            return MenstrualCycleRecord(
                id: first.uuid.uuidString,
                startDate: startDate,
                endDate: endDate,
                durationDays: duration
            )
        }
    }
    
    // MARK: - Analytics
    
    private func calculateAnalytics(
        periods: [MenstrualCycleRecord],
        today: Date,
        calendar: Calendar
    ) -> CycleAnalytics {
        
        guard !periods.isEmpty else {
            return emptyAnalytics()
        }
        
        let sortedPeriods = periods.sorted {
            $0.startDate < $1.startDate
        }
        
        var cycleLengths: [Int] = []
        
        if sortedPeriods.count >= 2 {
            for index in 1..<sortedPeriods.count {
                let previous = sortedPeriods[index - 1]
                let current = sortedPeriods[index]
                
                let days = calendar.dateComponents(
                    [.day],
                    from: previous.startDate,
                    to: current.startDate
                ).day
                
                if let days, days > 0, days < 100 {
                    cycleLengths.append(days)
                }
            }
        }
        
        let averageCycleLength: Double?
        
        if !cycleLengths.isEmpty {
            averageCycleLength =
                Double(cycleLengths.reduce(0, +))
                / Double(cycleLengths.count)
        } else {
            averageCycleLength = nil
        }
        
        let shortestCycle = cycleLengths.min()
        let longestCycle = cycleLengths.max()
        
        let cycleVariation: Double?
        
        if let shortestCycle, let longestCycle {
            cycleVariation = Double(
                longestCycle - shortestCycle
            )
        } else {
            cycleVariation = nil
        }
        
        let periodLengths = sortedPeriods.map {
            $0.durationDays
        }
        
        let averagePeriodLength: Double?
        
        if !periodLengths.isEmpty {
            averagePeriodLength =
                Double(periodLengths.reduce(0, +))
                / Double(periodLengths.count)
        } else {
            averagePeriodLength = nil
        }
        
        let latestPeriod = sortedPeriods.last
        
        let currentCycleDay: Int?
        
        if let latestPeriod {
            currentCycleDay = (
                calendar.dateComponents(
                    [.day],
                    from: latestPeriod.startDate,
                    to: calendar.startOfDay(for: today)
                ).day ?? 0
            ) + 1
        } else {
            currentCycleDay = nil
        }
        
        var predictedNextPeriod: Date?
        
        if
            let latestPeriod,
            let averageCycleLength
        {
            predictedNextPeriod = calendar.date(
                byAdding: .day,
                value: Int(averageCycleLength.rounded()),
                to: latestPeriod.startDate
            )
        }
        
        var predictedPMSStart: Date?
        var predictedPMSEnd: Date?
        
        if let predictedNextPeriod {
            predictedPMSStart = calendar.date(
                byAdding: .day,
                value: -5,
                to: predictedNextPeriod
            )
            
            predictedPMSEnd = calendar.date(
                byAdding: .day,
                value: -1,
                to: predictedNextPeriod
            )
        }
        
        let currentPhase = calculatePhase(
            currentCycleDay: currentCycleDay,
            periodLength: averagePeriodLength,
            cycleLength: averageCycleLength
        )
        
        return CycleAnalytics(
            periods: sortedPeriods,
            cycleLengths: cycleLengths,
            averageCycleLength: averageCycleLength,
            shortestCycle: shortestCycle,
            longestCycle: longestCycle,
            cycleVariation: cycleVariation,
            averagePeriodLength: averagePeriodLength,
            latestPeriodStart: latestPeriod?.startDate,
            currentCycleDay: currentCycleDay,
            predictedNextPeriod: predictedNextPeriod,
            predictedPMSStart: predictedPMSStart,
            predictedPMSEnd: predictedPMSEnd,
            currentPhase: currentPhase
        )
    }
    
    private func calculatePhase(
        currentCycleDay: Int?,
        periodLength: Double?,
        cycleLength: Double?
    ) -> CyclePhase {
        
        guard
            let day = currentCycleDay,
            let periodLength,
            let cycleLength
        else {
            return .unknown
        }
        
        let periodEnd = Int(
            periodLength.rounded()
        )
        
        if day <= periodEnd {
            return .menstruation
        }
        
        // Овуляция оценивается приблизительно
        // за 14 дней до следующей менструации.
        let ovulationDay = Int(
            cycleLength.rounded()
        ) - 14
        
        if abs(day - ovulationDay) <= 1 {
            return .ovulation
        }
        
        if day < ovulationDay {
            return .follicular
        }
        
        return .luteal
    }
    
    private func emptyAnalytics() -> CycleAnalytics {
        CycleAnalytics(
            periods: [],
            cycleLengths: [],
            averageCycleLength: nil,
            shortestCycle: nil,
            longestCycle: nil,
            cycleVariation: nil,
            averagePeriodLength: nil,
            latestPeriodStart: nil,
            currentCycleDay: nil,
            predictedNextPeriod: nil,
            predictedPMSStart: nil,
            predictedPMSEnd: nil,
            currentPhase: .unknown
        )
    }
}//
//  HealthKitCycleService.swift
//  Fitness API
//
//  Created by Анна Горяйнова on 13.09.2026.
//

