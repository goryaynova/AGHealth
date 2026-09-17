import Foundation
import SwiftUI

// Centralised HealthKit → backend sync, shared by the Home top button, Settings, and app launch.
//
// Incremental by design (Anna's requirement): the manager remembers which HealthKit objects it has
// already pushed (by their stable HealthKit UUID / deterministic sleep id) in UserDefaults, and only
// uploads objects it hasn't seen before. Re-running sync therefore uploads ONLY new data, not the
// whole window again. The backend upserts are still idempotent, so this is a safe optimisation, not
// the sole guard. The sync period is user-configurable (default: last 7 days).
@MainActor
final class SyncManager: ObservableObject {
    static let shared = SyncManager()

    // Persisted settings / state.
    private let defaults = UserDefaults.standard
    private let periodKey = "aghealth.sync.periodDays"
    private let syncedWorkoutsKey = "aghealth.sync.syncedWorkoutIDs"
    private let syncedSleepKey = "aghealth.sync.syncedSleepIDs"
    private let lastSyncKey = "aghealth.sync.lastSyncAt"

    @Published var isSyncing = false
    @Published var lastMessage: String?
    @Published var lastSyncedAt: Date?

    private let healthKitManager = HealthKitManager()
    private let syncService = HealthKitSyncService()
    private let sleepService = HealthKitSleepService()
    private let apiConfiguration = APIConfiguration()

    private init() {
        if defaults.object(forKey: periodKey) == nil {
            defaults.set(7, forKey: periodKey) // default: last week
        }
        lastSyncedAt = defaults.object(forKey: lastSyncKey) as? Date
    }

    // User-configurable sync period in days (default 7).
    var periodDays: Int {
        get { max(1, defaults.integer(forKey: periodKey)) }
        set { defaults.set(max(1, newValue), forKey: periodKey) }
    }

    private var syncedWorkoutIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: syncedWorkoutsKey) ?? []) }
        set { defaults.set(Array(newValue), forKey: syncedWorkoutsKey) }
    }
    private var syncedSleepIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: syncedSleepKey) ?? []) }
        set { defaults.set(Array(newValue), forKey: syncedSleepKey) }
    }

    /// Sync on app launch — only if it hasn't run in the last 30 minutes (avoid hammering on every
    /// foreground). Uses the configured period. Fire-and-forget; never blocks the UI.
    func syncOnLaunchIfNeeded() {
        if let last = lastSyncedAt, Date().timeIntervalSince(last) < 30 * 60 {
            return
        }
        Task { await sync() }
    }

    /// Full sync over the configured period, uploading only NEW HealthKit objects.
    @discardableResult
    func sync(days: Int? = nil) async -> String {
        if isSyncing { return lastMessage ?? "Синхронизация уже идёт" }
        isSyncing = true
        defer { isSyncing = false }

        let window = days ?? periodDays
        do {
            try await healthKitManager.requestAuthorization()

            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -window, to: endDate) ?? endDate
            let client = try apiConfiguration.makeAPIClient()

            var newWorkouts = 0
            var newSleep = 0

            // --- Workouts (upload only unseen HealthKit UUIDs) ---
            let workouts = try await syncService.fetchWorkouts(from: startDate, to: endDate)
            var seenWorkouts = syncedWorkoutIDs
            for workout in workouts where !seenWorkouts.contains(workout.id) {
                do {
                    let swimSegments: [APIClient.SwimmingSegmentInput]? =
                        workout.swimmingSegments.isEmpty
                        ? nil
                        : workout.swimmingSegments.map {
                            APIClient.SwimmingSegmentInput(
                                style: $0.style, distanceM: $0.distanceM, durationSec: $0.durationSec
                            )
                        }
                    try await client.createWorkout(
                        id: workout.id,
                        workoutType: workout.workoutType,
                        startedAt: workout.startedAt,
                        durationSec: workout.durationSec,
                        source: "healthkit",
                        distance: workout.distance,
                        energyBurned: workout.energyBurned,
                        swimmingSegments: swimSegments
                    )
                    seenWorkouts.insert(workout.id)
                    newWorkouts += 1
                } catch {
                    print("AGHealth SYNC: failed workout \(workout.id): \(error)")
                }
            }
            syncedWorkoutIDs = seenWorkouts

            // --- Sleep (upload only unseen night ids) ---
            // NOTE: the most recent night can gain more samples later; always re-send the LATEST
            // night even if seen, so an in-progress/updated night stays fresh (idempotent upsert).
            let sessions = try await sleepService.fetchSessions(from: startDate, to: endDate)
            let latestNightId = sessions.max(by: { $0.nightDate < $1.nightDate })?.id
            var seenSleep = syncedSleepIDs
            for s in sessions where !seenSleep.contains(s.id) || s.id == latestNightId {
                do {
                    try await client.createSleepSession(
                        id: s.id,
                        nightDate: s.nightDate,
                        startedAt: s.startedAt,
                        endedAt: s.endedAt,
                        inBedSec: s.inBedSec,
                        asleepSec: s.asleepSec,
                        deepSec: s.deepSec,
                        coreSec: s.coreSec,
                        remSec: s.remSec,
                        awakeSec: s.awakeSec,
                        segments: s.segments.map {
                            APIClient.SleepSegmentInput(stage: $0.stage, startedAt: $0.startedAt, endedAt: $0.endedAt)
                        }
                    )
                    if !seenSleep.contains(s.id) { newSleep += 1 }
                    seenSleep.insert(s.id)
                } catch {
                    print("AGHealth SYNC: failed sleep \(s.nightDate): \(error)")
                }
            }
            syncedSleepIDs = seenSleep

            let now = Date()
            lastSyncedAt = now
            defaults.set(now, forKey: lastSyncKey)

            let msg: String
            if newWorkouts == 0 && newSleep == 0 {
                msg = "Всё актуально — новых данных нет"
            } else {
                msg = "Новое — тренировки: \(newWorkouts) · сон: \(newSleep) ночей"
            }
            lastMessage = msg
            return msg
        } catch {
            let msg = "Ошибка синхронизации: \(error.localizedDescription)"
            lastMessage = msg
            return msg
        }
    }
}
