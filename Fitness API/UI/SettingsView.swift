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
                // Сначала гарантируем наличие разрешений HealthKit.
                try await healthKitManager.requestAuthorization()

                // Фактическая отправка данных на сервер
                // подключается следующим этапом к существующему
                // HealthKitSyncService + APIClient.
                
                try await Task.sleep(
                    for: .milliseconds(500)
                )

                await MainActor.run {
                    isSyncing = false
                    syncMessage = "Синхронизация запущена."
                }
            } catch {
                await MainActor.run {
                    isSyncing = false
                    syncMessage = """
                    Не удалось начать синхронизацию: \(error.localizedDescription)
                    """
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
