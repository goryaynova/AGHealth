import Foundation
import HealthKit

// Reads Apple Health `.sleepAnalysis` samples and groups them into per-night sessions with a stage
// breakdown (deep/core/rem/awake) and raw segments for the Apple-style hypnogram. Only real
// HealthKit data is used — stages that iOS didn't provide stay nil and are never invented.

struct HealthKitSleepSegment {
    let stage: String        // awake | rem | core | deep | asleep | inbed
    let startedAt: Date
    let endedAt: Date
}

struct HealthKitSleepSession {
    let id: String           // deterministic per-night id (stable across re-syncs)
    let nightDate: String    // YYYY-MM-DD (local calendar date of the session end / wake-up)
    let startedAt: Date
    let endedAt: Date
    let inBedSec: Int?
    let asleepSec: Int
    let deepSec: Int?
    let coreSec: Int?
    let remSec: Int?
    let awakeSec: Int?
    let segments: [HealthKitSleepSegment]
}

final class HealthKitSleepService {
    private let healthStore = HKHealthStore()

    func fetchSessions(from startDate: Date, to endDate: Date) async throws -> [HealthKitSleepSession] {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return []
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: samples as? [HKCategorySample] ?? [])
            }
            healthStore.execute(query)
        }

        return buildSessions(from: samples)
    }

    // MARK: - Grouping

    /// Groups raw sleep samples into sessions. A gap longer than `sessionGap` (4h) between samples
    /// starts a new session, so daytime naps and the main night sleep stay separate.
    private func buildSessions(from samples: [HKCategorySample]) -> [HealthKitSleepSession] {
        guard !samples.isEmpty else { return [] }
        let sessionGap: TimeInterval = 4 * 3600

        let sorted = samples.sorted { $0.startDate < $1.startDate }
        var groups: [[HKCategorySample]] = []
        var current: [HKCategorySample] = []

        for sample in sorted {
            if let last = current.last {
                if sample.startDate.timeIntervalSince(last.endDate) > sessionGap {
                    groups.append(current)
                    current = [sample]
                } else {
                    current.append(sample)
                }
            } else {
                current = [sample]
            }
        }
        if !current.isEmpty { groups.append(current) }

        // Keep only real sleep sessions: at least 30 min of asleep time (drops stray in-bed noise).
        return groups.compactMap { session(from: $0) }.filter { $0.asleepSec >= 1800 }
    }

    private func session(from group: [HKCategorySample]) -> HealthKitSleepSession? {
        guard let first = group.first, let last = group.max(by: { $0.endDate < $1.endDate }) else {
            return nil
        }

        var deep = 0.0, core = 0.0, rem = 0.0, awake = 0.0, inBed = 0.0, genericAsleep = 0.0
        var sawStages = false
        var sawInBed = false
        var segments: [HealthKitSleepSegment] = []

        for sample in group {
            let duration = sample.endDate.timeIntervalSince(sample.startDate)
            let stage = Self.stageName(for: sample.value)
            switch stage {
            case "deep": deep += duration; sawStages = true
            case "core": core += duration; sawStages = true
            case "rem": rem += duration; sawStages = true
            case "awake": awake += duration
            case "inbed": inBed += duration; sawInBed = true
            default: genericAsleep += duration
            }
            segments.append(
                HealthKitSleepSegment(stage: stage, startedAt: sample.startDate, endedAt: sample.endDate)
            )
        }

        // Total asleep = staged sleep if available, else the generic `.asleep` value (older iOS).
        let asleep = sawStages ? (deep + core + rem) : genericAsleep
        guard asleep > 0 else { return nil }

        // In-bed total: prefer explicit `.inBed` samples; else fall back to wall-clock span.
        let span = last.endDate.timeIntervalSince(first.startDate)
        let inBedTotal: Double? = sawInBed ? max(inBed, asleep + awake) : (span > 0 ? span : nil)

        let calendar = Calendar.current
        let nightDate = Self.isoDate(from: last.endDate, calendar: calendar)

        return HealthKitSleepSession(
            id: Self.deterministicID(nightDate: nightDate),
            nightDate: nightDate,
            startedAt: first.startDate,
            endedAt: last.endDate,
            inBedSec: inBedTotal.map { Int($0.rounded()) },
            asleepSec: Int(asleep.rounded()),
            deepSec: sawStages ? Int(deep.rounded()) : nil,
            coreSec: sawStages ? Int(core.rounded()) : nil,
            remSec: sawStages ? Int(rem.rounded()) : nil,
            awakeSec: (sawStages || awake > 0) ? Int(awake.rounded()) : nil,
            segments: segments
        )
    }

    // MARK: - Mapping

    private static func stageName(for value: Int) -> String {
        guard let cat = HKCategoryValueSleepAnalysis(rawValue: value) else { return "asleep" }
        switch cat {
        case .inBed: return "inbed"
        case .awake: return "awake"
        case .asleepREM: return "rem"
        case .asleepDeep: return "deep"
        case .asleepCore: return "core"
        case .asleepUnspecified: return "asleep"
        @unknown default: return "asleep"
        }
    }

    private static func isoDate(from date: Date, calendar: Calendar) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }

    /// Stable id per night so re-syncing the same night idempotently upserts one backend row (the
    /// backend id must be a UUID — derive a deterministic UUIDv5-style value from the night date).
    private static func deterministicID(nightDate: String) -> String {
        // Build a deterministic UUID from the night date string (namespaced), so the same night
        // always maps to the same backend session id across syncs.
        let seed = "aghealth-sleep-\(nightDate)"
        var hash = [UInt8](repeating: 0, count: 16)
        for (i, byte) in Array(seed.utf8).enumerated() {
            hash[i % 16] = hash[i % 16] &+ byte &+ UInt8((i * 31) & 0xFF)
        }
        // Set version (4) and variant bits for a well-formed UUID string.
        hash[6] = (hash[6] & 0x0F) | 0x40
        hash[8] = (hash[8] & 0x3F) | 0x80
        let hex = hash.map { String(format: "%02x", $0) }.joined()
        let idx = hex.index(hex.startIndex, offsetBy:)
        return "\(hex[hex.startIndex..<idx(8)])-\(hex[idx(8)..<idx(12)])-\(hex[idx(12)..<idx(16)])-\(hex[idx(16)..<idx(20)])-\(hex[idx(20)..<idx(32)])"
    }
}
