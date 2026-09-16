import SwiftUI

struct MoreSectionView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("МОИ ДАННЫЕ") {
                    NavigationLink {
                        ExercisesView()
                    } label: {
                        Label(
                            "Упражнения",
                            systemImage: "figure.strengthtraining.traditional"
                        )
                    }

                    NavigationLink {
                        ExerciseProgressionView()
                    } label: {
                        Label(
                            "Прогрессия веса",
                            systemImage: "chart.line.uptrend.xyaxis"
                        )
                    }

                    NavigationLink {
                        SwimmingProgressView()
                    } label: {
                        Label(
                            "Прогресс плавания",
                            systemImage: "figure.pool.swim"
                        )
                    }

                    NavigationLink {
                        PetView()
                    } label: {
                        Label(
                            "Питомец",
                            systemImage: "pawprint.fill"
                        )
                    }
                }

                Section("СИСТЕМА") {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label(
                            "Настройки",
                            systemImage: "gearshape.fill"
                        )
                    }

                    NavigationLink {
                        AppleHealthSettingsView()
                    } label: {
                        Label(
                            "Apple Health",
                            systemImage: "heart.text.square"
                        )
                    }

                    NavigationLink {
                        SyncSettingsView()
                    } label: {
                        Label(
                            "Синхронизация",
                            systemImage: "arrow.triangle.2.circlepath"
                        )
                    }

                    NavigationLink {
                        SyncHistoryView()
                    } label: {
                        Label(
                            "История синхронизации",
                            systemImage: "clock.arrow.circlepath"
                        )
                    }

                    NavigationLink {
                        SystemStatusView()
                    } label: {
                        Label(
                            "Состояние системы",
                            systemImage: "server.rack"
                        )
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(
                AGContentColors.background
            )
            .navigationTitle("Ещё")
        }
    }
}
