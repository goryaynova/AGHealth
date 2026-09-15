import SwiftUI

struct WorkoutsSectionView: View {
    @State private var selectedFilter = "Все"

    @State private var workouts: [APIClient.Workout] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let apiConfiguration = APIConfiguration()

    private let filters = [
        "Все",
        "Силовые",
        "Бег",
        "Плавание",
        "Велосипед"
    ]

    // Соответствие названий фильтров и backend workoutType.
    private func backendType(for filter: String) -> String? {
        switch filter {
        case "Силовые": return "strength"
        case "Бег": return "running"
        case "Плавание": return "swimming"
        case "Велосипед": return "cycling"
        default: return nil
        }
    }

    private var filteredWorkouts: [APIClient.Workout] {
        guard let type = backendType(for: selectedFilter) else {
            return workouts
        }
        return workouts.filter { $0.workoutType == type }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Тренировки")
                            .font(
                                .system(
                                    size: 30,
                                    weight: .bold
                                )
                            )
                            .foregroundStyle(.white)

                        Text(
                            "Активность и история тренировок"
                        )
                        .font(.system(size: 15))
                        .foregroundStyle(
                            AGContentColors.secondaryText
                        )
                    }

                    // Additive block: weekly worked-muscles summary + body muscle map.
                    // Self-contained; does not alter the workout list/detail below.
                    WeeklyMuscleSummaryView()

                    ScrollView(
                        .horizontal,
                        showsIndicators: false
                    ) {
                        HStack(spacing: 8) {
                            ForEach(
                                filters,
                                id: \.self
                            ) { filter in
                                Button {
                                    selectedFilter = filter
                                } label: {
                                    Text(filter)
                                        .font(
                                            .system(
                                                size: 13,
                                                weight: .medium
                                            )
                                        )
                                        .foregroundStyle(
                                            selectedFilter == filter
                                            ? .white
                                            : AGContentColors.secondaryText
                                        )
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 9)
                                        .background(
                                            selectedFilter == filter
                                            ? AGContentColors.accent
                                            : AGContentColors.card
                                        )
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                                .tint(.white)
                                .padding(.vertical, 40)
                            Spacer()
                        }
                    } else if let errorMessage {
                        VStack(spacing: 8) {
                            Text("Не удалось загрузить тренировки")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                            Text(errorMessage)
                                .font(.system(size: 13))
                                .foregroundStyle(AGContentColors.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else if filteredWorkouts.isEmpty {
                        Text("Тренировки не найдены")
                            .font(.system(size: 15))
                            .foregroundStyle(AGContentColors.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else {
                        ForEach(filteredWorkouts) { workout in
                            NavigationLink {
                                WorkoutDetailView(workoutID: workout.id)
                            } label: {
                                WorkoutListCard(
                                    title: workoutTitle(workout.workoutType),
                                    subtitle: workoutSubtitle(workout),
                                    calories: workoutCalories(workout),
                                    icon: workoutIcon(workout.workoutType),
                                    color: workoutColor(workout.workoutType)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
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
            .task {
                await loadWorkouts()
            }
            .refreshable {
                await loadWorkouts()
            }
        }
    }

    // MARK: - Load

    private func loadWorkouts() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let client = try apiConfiguration.makeAPIClient()
            let loaded = try await client.listWorkouts(limit: 50)
            await MainActor.run {
                // Сортировка по дате начала, свежие сверху.
                workouts = loaded.sorted { $0.startedAt > $1.startedAt }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Presentation helpers

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

    private func workoutIcon(_ type: String) -> String {
        switch type {
        case "strength": return "figure.strengthtraining.traditional"
        case "running": return "figure.run"
        case "swimming": return "figure.pool.swim"
        case "cycling": return "figure.outdoor.cycle"
        case "walking": return "figure.walk"
        case "tennis": return "figure.tennis"
        default: return "figure.mixed.cardio"
        }
    }

    private func workoutColor(_ type: String) -> Color {
        switch type {
        case "running", "walking": return AGContentColors.green
        default: return AGContentColors.accent
        }
    }

    private func workoutSubtitle(_ workout: APIClient.Workout) -> String {
        let dateText = formatStartedAt(workout.startedAt)
        let minutes = max(1, workout.durationSec / 60)
        var parts = [dateText, "\(minutes) мин"]
        if let distance = workout.distance, distance > 0 {
            let km = distance / 1000
            parts.append(String(format: "%.1f км", km))
        }
        return parts.joined(separator: " • ")
    }

    private func workoutCalories(_ workout: APIClient.Workout) -> String {
        guard let energy = workout.energyBurned, energy > 0 else {
            return ""
        }
        return "\(Int(energy.rounded())) ккал"
    }

    private func formatStartedAt(_ iso: String) -> String {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = parser.date(from: iso)
        if date == nil {
            let fallback = ISO8601DateFormatter()
            fallback.formatOptions = [.withInternetDateTime]
            date = fallback.date(from: iso)
        }
        guard let date else { return iso }

        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Сегодня"
        }
        if calendar.isDateInYesterday(date) {
            return "Вчера"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: date)
    }
}

struct WorkoutListCard: View {
    let title: String
    let subtitle: String
    let calories: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 19))
                .foregroundStyle(color)
                .frame(width: 46, height: 46)
                .background(
                    color.opacity(0.12)
                )
                .clipShape(
                    RoundedRectangle(cornerRadius: 14)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(
                        .system(
                            size: 15,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(
                        AGContentColors.secondaryText
                    )
            }

            Spacer()

            Text(calories)
                .font(
                    .system(
                        size: 12,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    AGContentColors.secondaryText
                )
        }
        .padding(16)
        .background(
            AGContentColors.card
        )
        .clipShape(
            RoundedRectangle(cornerRadius: 19)
        )
    }
}
