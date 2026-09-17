import SwiftUI
import HealthKit

// MARK: - Settings

struct SettingsView: View {
    var body: some View {
        List {
            Section("Сервер") {
                HStack {
                    Text("Адрес")

                    Spacer()

                    Text("100.123.202.44:8791")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Подключение")

                    Spacer()

                    Text("Настроено")
                        .foregroundStyle(.green)
                }
            }
        }
        .navigationTitle("Настройки")
    }
}

// MARK: - Apple Health

struct AppleHealthSettingsView: View {
    @State private var isRequestingAccess = false
    @State private var accessMessage: String?
    
    private let healthKitManager = HealthKitManager()
    
    var body: some View {
        List {
            Section {
                HStack {
                    Label(
                        "Apple Health",
                        systemImage: "heart.fill"
                    )

                    Spacer()

                    Text("Подключено")
                        .foregroundStyle(.green)
                }
            }

            Section("Данные") {
                HealthDataRow(
                    title: "Тренировки",
                    icon: "figure.run"
                )

                HealthDataRow(
                    title: "Пульс",
                    icon: "heart.fill"
                )

                HealthDataRow(
                    title: "HRV",
                    icon: "waveform.path.ecg"
                )

                HealthDataRow(
                    title: "Сон",
                    icon: "bed.double.fill"
                )

                HealthDataRow(
                    title: "Вес",
                    icon: "scalemass.fill"
                )

                HealthDataRow(
                    title: "Активная энергия",
                    icon: "flame.fill"
                )

                HealthDataRow(
                    title: "Цикл",
                    icon: "calendar"
                )
            }

            Section("Доступ к данным") {
                Button {
                    requestHealthAccess()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.shield")
                            .foregroundStyle(.blue)

                        Text("Разрешить доступ к данным")
                    }
                }
                .disabled(isRequestingAccess)

                if let accessMessage {
                    Text(accessMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Apple Health")
    }

    private func requestHealthAccess() {
        isRequestingAccess = true
        accessMessage = nil

        Task {
            do {
                try await healthKitManager.requestAuthorization()

                await MainActor.run {
                    isRequestingAccess = false
                    accessMessage = """
                    Запрос доступа выполнен. Если система показала окно разрешений, проверь доступ к данным цикла в Apple Health.
                    """
                }
            } catch {
                await MainActor.run {
                    isRequestingAccess = false
                    accessMessage = "Не удалось запросить доступ: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Health data row

struct HealthDataRow: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 22)
                .foregroundStyle(.secondary)

            Text(title)

            Spacer()
        }
    }
}

// MARK: - Sync Settings

struct SyncSettingsView: View {
    @State private var isSyncing = false
    @State private var syncMessage: String?

    private let healthKitManager = HealthKitManager()
    private let syncService = HealthKitSyncService()
    private let sleepService = HealthKitSleepService()
    private let apiConfiguration = APIConfiguration()

    var body: some View {
        List {
            Section("Синхронизация") {
                HStack {
                    Text("Автоматическая")

                    Spacer()

                    Text("Вкл.")
                        .foregroundStyle(.green)
                }

                HStack {
                    Text("Период")

                    Spacer()

                    Text("Последние 7 дней")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Ручная синхронизация") {
                Button {
                    startManualSync()
                } label: {
                    HStack {
                        Image(
                            systemName: isSyncing
                            ? "arrow.triangle.2.circlepath"
                            : "arrow.down.circle"
                        )

                        Text(
                            isSyncing
                            ? "Синхронизация..."
                            : "Синхронизировать сейчас"
                        )
                    }
                }
                .disabled(isSyncing)

                if let syncMessage {
                    Text(syncMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Синхронизация")
    }

    private func startManualSync() {
        isSyncing = true
        syncMessage = nil

        Task {
            do {
                // 1. Гарантируем наличие разрешений HealthKit.
                try await healthKitManager.requestAuthorization()

                // 2. Получаем тренировки за последние 30 дней.
                let endDate = Date()
                let startDate = Calendar.current.date(
                    byAdding: .day,
                    value: -30,
                    to: endDate
                ) ?? endDate

                let workouts = try await syncService.fetchWorkouts(
                    from: startDate,
                    to: endDate
                )

                print("AGHealth SYNC: fetched \(workouts.count) workouts from HealthKit")

                // 3. Отправляем каждую тренировку на backend.
                //    HealthKit UUID сохраняется как ID тренировки.
                //    Backend идемпотентен по client-generated id:
                //    повторная отправка не считается ошибкой.
                let client = try apiConfiguration.makeAPIClient()

                var syncedCount = 0
                var failedCount = 0

                for workout in workouts {
                    do {
                        // Forward the swimming stroke-style breakdown when HealthKit provided one.
                        let swimSegments: [APIClient.SwimmingSegmentInput]? =
                            workout.swimmingSegments.isEmpty
                            ? nil
                            : workout.swimmingSegments.map {
                                APIClient.SwimmingSegmentInput(
                                    style: $0.style,
                                    distanceM: $0.distanceM,
                                    durationSec: $0.durationSec
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
                        syncedCount += 1
                    } catch {
                        // Одна упавшая тренировка не должна ронять весь sync.
                        failedCount += 1
                        print("AGHealth SYNC: failed workout \(workout.id): \(error)")
                    }
                }

                // 4. Синхронизируем сон (Apple Health `.sleepAnalysis`) за тот же период.
                //    Каждая ночь — идемпотентный upsert по детерминированному id.
                var sleepSynced = 0
                var sleepFailed = 0
                do {
                    let sessions = try await sleepService.fetchSessions(from: startDate, to: endDate)
                    print("AGHealth SYNC: fetched \(sessions.count) sleep sessions from HealthKit")
                    for s in sessions {
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
                                    APIClient.SleepSegmentInput(
                                        stage: $0.stage,
                                        startedAt: $0.startedAt,
                                        endedAt: $0.endedAt
                                    )
                                }
                            )
                            sleepSynced += 1
                        } catch {
                            sleepFailed += 1
                            print("AGHealth SYNC: failed sleep \(s.nightDate): \(error)")
                        }
                    }
                } catch {
                    print("AGHealth SYNC: sleep fetch error = \(error)")
                }

                await MainActor.run {
                    isSyncing = false
                    let base: String
                    if failedCount == 0 {
                        base = "Синхронизировано: \(syncedCount) тренировок"
                    } else {
                        base = "Синхронизировано: \(syncedCount), с ошибками: \(failedCount)"
                    }
                    let sleepPart = sleepFailed == 0
                        ? " · сон: \(sleepSynced) ночей"
                        : " · сон: \(sleepSynced), ошибок: \(sleepFailed)"
                    syncMessage = base + sleepPart
                }
            } catch {
                await MainActor.run {
                    isSyncing = false
                    syncMessage = "Ошибка синхронизации: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Sync History

struct SyncHistoryView: View {
    var body: some View {
        List {
            HStack {
                VStack(alignment: .leading) {
                    Text("Сегодня, 10:32")

                    Text("Тренировки: 3 • измерения: 128")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .navigationTitle("История")
    }
}

// MARK: - System Status

struct SystemStatusView: View {
    var body: some View {
        List {
            HStack {
                Text("Сервер")

                Spacer()

                Text("Доступен")
                    .foregroundStyle(.green)
            }

            HStack {
                Text("Apple Health")

                Spacer()

                Text("Доступен")
                    .foregroundStyle(.green)
            }
        }
        .navigationTitle("Состояние системы")
    }
}
