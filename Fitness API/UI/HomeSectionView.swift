import SwiftUI

struct HomeSectionView: View {
    @State private var selectedDate = Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HomeHeader()

                    HomeDateSelector(
                        selectedDate: $selectedDate
                    )

                    RecoveryCard()

                    HomeNutritionCard()

                    HomeWorkoutCard()

                    HomeCycleCard()

                    HomeHealthCard()
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
            .background(
                AGContentColors.background
                    .ignoresSafeArea()
            )
            .navigationBarHidden(true)
        }
    }
}

struct HomeHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Здоровье и жизнь Анны")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(AGContentColors.primaryText)

            Text("Здоровье, активность и самочувствие — в одном месте.")
                .font(.system(size: 15))
                .foregroundStyle(AGContentColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct HomeDateSelector: View {
    @Binding var selectedDate: Date

    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                selectedDate = Calendar.current.date(
                    byAdding: .day,
                    value: -1,
                    to: selectedDate
                ) ?? selectedDate
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(AGContentColors.card)
                    .clipShape(Circle())
            }

            Spacer()

            VStack(spacing: 2) {
                Text(
                    isToday
                    ? "Сегодня"
                    : formattedDate(selectedDate)
                )
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

                if !isToday {
                    Text(formattedWeekday(selectedDate))
                        .font(.system(size: 12))
                        .foregroundStyle(
                            AGContentColors.secondaryText
                        )
                }
            }

            Spacer()

            Button {
                guard !isToday else { return }

                selectedDate = Calendar.current.date(
                    byAdding: .day,
                    value: 1,
                    to: selectedDate
                ) ?? selectedDate
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(
                        isToday
                        ? AGContentColors.tertiaryText
                        : .white
                    )
                    .frame(width: 36, height: 36)
                    .background(AGContentColors.card)
                    .clipShape(Circle())
            }
            .disabled(isToday)
        }
    }
}

struct HomeNutritionCard: View {
    var body: some View {
        NavigationLink {
            NutritionSectionView()
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label(
                        "Питание сегодня",
                        systemImage: "fork.knife"
                    )
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(
                            AGContentColors.secondaryText
                        )
                }

                HStack(alignment: .bottom, spacing: 6) {
                    Text("1 840")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)

                    Text("/ 2 100 ккал")
                        .font(.system(size: 14))
                        .foregroundStyle(
                            AGContentColors.secondaryText
                        )
                        .padding(.bottom, 4)
                }

                ProgressBar(
                    progress: 1840.0 / 2100.0,
                    color: AGContentColors.green
                )

                HStack(spacing: 0) {
                    HomeMacroValue(
                        title: "Белки",
                        value: "118 г",
                        target: "130 г"
                    )

                    Spacer()

                    HomeMacroValue(
                        title: "Жиры",
                        value: "62 г",
                        target: "70 г"
                    )

                    Spacer()

                    HomeMacroValue(
                        title: "Углеводы",
                        value: "184 г",
                        target: "220 г"
                    )
                }

                Text("Рацион в пределах цели")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AGContentColors.green)
            }
            .padding(18)
            .background(AGContentColors.card)
            .clipShape(
                RoundedRectangle(cornerRadius: 22)
            )
        }
        .buttonStyle(.plain)
    }
}

struct HomeMacroValue: View {
    let title: String
    let value: String
    let target: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(
                    AGContentColors.secondaryText
                )

            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            Text("из \(target)")
                .font(.system(size: 11))
                .foregroundStyle(
                    AGContentColors.tertiaryText
                )
        }
    }
}

struct HomeWorkoutCard: View {
    private let apiConfiguration = APIConfiguration()

    @State private var latest: APIClient.Workout?

    var body: some View {
        Group {
            if let latest {
                NavigationLink {
                    WorkoutDetailView(workoutID: latest.id)
                } label: {
                    cardBody(for: latest)
                }
                .buttonStyle(.plain)
            } else {
                cardBody(for: nil)
            }
        }
        .task {
            await loadLatest()
        }
    }

    @ViewBuilder
    private func cardBody(for workout: APIClient.Workout?) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(
                    "Последняя тренировка",
                    systemImage:
                        "figure.strengthtraining.traditional"
                )
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(
                        AGContentColors.secondaryText
                    )
            }

            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(workout.map { workoutTitle($0.workoutType) } ?? "Нет данных")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(workout.map { subtitle(for: $0) } ?? "Синхронизируйте тренировки")
                        .font(.system(size: 13))
                        .foregroundStyle(
                            AGContentColors.secondaryText
                        )
                }

                Spacer()

                if let energy = workout?.energyBurned, energy > 0 {
                    VStack(alignment: .trailing, spacing: 5) {
                        Text("\(Int(energy.rounded()))")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)

                        Text("ккал")
                            .font(.system(size: 12))
                            .foregroundStyle(
                                AGContentColors.secondaryText
                            )
                    }
                }
            }
        }
        .padding(18)
        .background(AGContentColors.card)
        .clipShape(
            RoundedRectangle(cornerRadius: 22)
        )
    }

    private func loadLatest() async {
        do {
            let client = try apiConfiguration.makeAPIClient()
            let loaded = try await client.listWorkouts(limit: 20)
            await MainActor.run {
                latest = loaded.max { $0.startedAt < $1.startedAt }
            }
        } catch {
            print("AGHealth: HomeWorkoutCard load error = \(error)")
        }
    }

    private func workoutTitle(_ type: String) -> String {
        switch type {
        case "strength": return "Силовая тренировка"
        case "running": return "Бег"
        case "swimming": return "Плавание"
        case "cycling": return "Велосипед"
        case "walking": return "Ходьба"
        case "tennis": return "Теннис"
        default: return type.capitalized
        }
    }

    private func subtitle(for workout: APIClient.Workout) -> String {
        let minutes = max(1, workout.durationSec / 60)
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = parser.date(from: workout.startedAt)
        if date == nil {
            let fallback = ISO8601DateFormatter()
            fallback.formatOptions = [.withInternetDateTime]
            date = fallback.date(from: workout.startedAt)
        }

        let dateText: String
        if let date {
            let calendar = Calendar.current
            if calendar.isDateInToday(date) {
                dateText = "Сегодня"
            } else if calendar.isDateInYesterday(date) {
                dateText = "Вчера"
            } else {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "ru_RU")
                formatter.dateFormat = "d MMMM"
                dateText = formatter.string(from: date)
            }
        } else {
            dateText = ""
        }

        return dateText.isEmpty ? "\(minutes) мин" : "\(dateText) • \(minutes) мин"
    }
}

// MARK: - Cycle

struct HomeCycleCard: View {
    var body: some View {
        NavigationLink {
            HealthCycleView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "calendar")
                    .font(.system(size: 19))
                    .foregroundStyle(
                        AGContentColors.purple
                    )
                    .frame(width: 46, height: 46)
                    .background(
                        AGContentColors.purple.opacity(0.12)
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: 14)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Цикл")
                        .font(
                            .system(
                                size: 16,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(.white)

                    Text(
                        "14 день • фолликулярная фаза"
                    )
                    .font(.system(size: 13))
                    .foregroundStyle(
                        AGContentColors.secondaryText
                    )
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(
                        .system(
                            size: 12,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        AGContentColors.secondaryText
                    )
            }
            .padding(18)
            .background(AGContentColors.card)
            .clipShape(
                RoundedRectangle(cornerRadius: 22)
            )
        }
        .buttonStyle(.plain)
    }
}

struct HomeHealthCard: View {
    var body: some View {
        NavigationLink {
            HealthSectionView()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            AGContentColors.green.opacity(0.14)
                        )
                        .frame(width: 46, height: 46)

                    Image(systemName: "heart.fill")
                        .foregroundStyle(
                            AGContentColors.green
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Здоровье")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(
                        "Сон 7 ч 42 мин • пульс покоя 58"
                    )
                    .font(.system(size: 13))
                    .foregroundStyle(
                        AGContentColors.secondaryText
                    )
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(
                        AGContentColors.secondaryText
                    )
            }
            .padding(18)
            .background(AGContentColors.card)
            .clipShape(
                RoundedRectangle(cornerRadius: 22)
            )
        }
        .buttonStyle(.plain)
    }
}

struct RecoveryCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("ВОССТАНОВЛЕНИЕ")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(
                        AGContentColors.secondaryText
                    )

                Spacer()

                Text("МОК")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(
                        AGContentColors.tertiaryText
                    )
            }

            HStack(alignment: .bottom) {
                Text("78")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(.white)

                Text("/ 100")
                    .font(.system(size: 14))
                    .foregroundStyle(
                        AGContentColors.secondaryText
                    )
                    .padding(.bottom, 7)

                Spacer()

                Text("Хорошее")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(
                        AGContentColors.green
                    )
            }

            ProgressBar(
                progress: 0.78,
                color: AGContentColors.green
            )

            Text(
                "Можно тренироваться. Показатель пока демонстрационный."
            )
            .font(.system(size: 13))
            .foregroundStyle(
                AGContentColors.secondaryText
            )
        }
        .padding(18)
        .background(AGContentColors.card)
        .clipShape(
            RoundedRectangle(cornerRadius: 22)
        )
    }
}
