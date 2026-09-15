import SwiftUI

struct WorkoutDetailView: View {
    let workoutID: String

    private let apiConfiguration = APIConfiguration()

    @State private var detail: APIClient.WorkoutDetail?
    @State private var isLoading = false
    @State private var errorMessage: String?

    // Per-workout exercise removal (swipe-left on an exercise group).
    @State private var exercisePendingDeletion: ExerciseGroup?
    @State private var isDeletingExercise = false
    @State private var deleteErrorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isLoading && detail == nil {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(.white)
                            .padding(.vertical, 60)
                        Spacer()
                    }
                } else if let errorMessage, detail == nil {
                    VStack(spacing: 8) {
                        Text("Не удалось загрузить тренировку")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(AGContentColors.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else if let detail {
                    header(for: detail)

                    statsRow(for: detail)

                    if let deleteErrorMessage {
                        ErrorCard(message: deleteErrorMessage)
                    }

                    exercisesSection(for: detail)
                }

                NavigationLink {
                    StrengthWorkoutView(workoutID: workoutID)
                } label: {
                    HStack {
                        Image(systemName: "plus")

                        Text("Добавить упражнение")
                    }
                    .font(
                        .system(
                            size: 15,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        AGContentColors.accent
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: 16)
                    )
                }
            }
            .padding(20)
        }
        .background(
            AGContentColors.background
                .ignoresSafeArea()
        )
        .navigationTitle("Тренировка")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            exercisePendingDeletion.map {
                "Удалить «\($0.exerciseName)» из этой тренировки?"
            } ?? "Удалить упражнение из тренировки?",
            isPresented: Binding(
                get: { exercisePendingDeletion != nil },
                set: { isPresented in
                    if !isPresented { exercisePendingDeletion = nil }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Удалить", role: .destructive) {
                if let group = exercisePendingDeletion {
                    Task { await deleteExerciseFromWorkout(group) }
                }
            }
            Button("Отмена", role: .cancel) {
                exercisePendingDeletion = nil
            }
        } message: {
            Text(
                "Удалится только это упражнение и его подходы из этой тренировки. Само упражнение и другие тренировки не изменятся."
            )
        }
        .task {
            await loadDetail()
        }
        // После возвращения из StrengthWorkoutView через dismiss
        // экран снова появляется — перезагружаем sets.
        .onAppear {
            if detail != nil {
                Task { await loadDetail() }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func header(for detail: APIClient.WorkoutDetail) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(workoutTitle(detail.workoutType))
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)

            Text(subtitle(for: detail))
                .font(.system(size: 14))
                .foregroundStyle(
                    AGContentColors.secondaryText
                )
        }
    }

    @ViewBuilder
    private func statsRow(for detail: APIClient.WorkoutDetail) -> some View {
        let exerciseCount = Set(detail.sets.map(\.exerciseId)).count
        let setsCount = detail.sets.count
        let volume = detail.sets.reduce(0.0) { $0 + $1.weightKg * Double($1.reps) }

        HStack(spacing: 10) {
            WorkoutStat(
                title: "Упражнения",
                value: "\(exerciseCount)"
            )

            WorkoutStat(
                title: "Подходы",
                value: "\(setsCount)"
            )

            WorkoutStat(
                title: "Объём",
                value: volumeText(volume)
            )
        }
    }

    @ViewBuilder
    private func exercisesSection(for detail: APIClient.WorkoutDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("УПРАЖНЕНИЯ")
                .font(
                    .system(
                        size: 11,
                        weight: .semibold
                    )
                )
                .tracking(1)
                .foregroundStyle(
                    AGContentColors.secondaryText
                )

            if detail.sets.isEmpty {
                Text("Упражнения не добавлены")
                    .font(.system(size: 14))
                    .foregroundStyle(AGContentColors.secondaryText)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AGContentColors.card)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            } else {
                ForEach(groupedExercises(detail.sets), id: \.exerciseId) { group in
                    ExerciseGroupCard(
                        group: group,
                        isDeleting: isDeletingExercise,
                        onDeleteRequested: {
                            deleteErrorMessage = nil
                            exercisePendingDeletion = group
                        }
                    )
                }
            }
        }
    }

    // MARK: - Grouping

    struct ExerciseGroup {
        let exerciseId: String
        let exerciseName: String
        let muscleGroup: String?
        let sets: [APIClient.StrengthSetDetail]
    }

    private func groupedExercises(_ sets: [APIClient.StrengthSetDetail]) -> [ExerciseGroup] {
        // Сохраняем порядок по orderInWorkout (sets уже отсортированы backend).
        var order: [String] = []
        var map: [String: [APIClient.StrengthSetDetail]] = [:]

        for set in sets.sorted(by: { $0.orderInWorkout < $1.orderInWorkout }) {
            if map[set.exerciseId] == nil {
                order.append(set.exerciseId)
                map[set.exerciseId] = []
            }
            map[set.exerciseId]?.append(set)
        }

        return order.compactMap { exerciseId in
            guard let groupSets = map[exerciseId], let first = groupSets.first else {
                return nil
            }
            return ExerciseGroup(
                exerciseId: exerciseId,
                exerciseName: first.exerciseName,
                muscleGroup: first.muscleGroup,
                sets: groupSets
            )
        }
    }

    // MARK: - Load

    private func loadDetail() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let client = try apiConfiguration.makeAPIClient()
            let loaded = try await client.getWorkout(id: workoutID)
            await MainActor.run {
                detail = loaded
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Delete exercise from this workout

    /// Removes one exercise (and all its sets) from THIS workout only, via
    /// `DELETE /api/v1/fitness/workouts/{id}/exercises/{exerciseId}`.
    /// The global exercise record and every other workout stay untouched.
    /// On success the detail is reloaded so the card disappears; on failure
    /// nothing is removed locally and an inline error is shown.
    private func deleteExerciseFromWorkout(_ group: ExerciseGroup) async {
        guard !isDeletingExercise else { return }
        isDeletingExercise = true
        deleteErrorMessage = nil
        defer {
            isDeletingExercise = false
            exercisePendingDeletion = nil
        }

        do {
            let client = try apiConfiguration.makeAPIClient()
            try await client.deleteWorkoutExercise(
                workoutId: workoutID,
                exerciseId: group.exerciseId
            )
            await loadDetail()
        } catch {
            await MainActor.run {
                deleteErrorMessage = error.localizedDescription
            }
            print("AGHealth: delete workout exercise error = \(error)")
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

    private func subtitle(for detail: APIClient.WorkoutDetail) -> String {
        let dateText = formatStartedAt(detail.startedAt)
        let minutes = max(1, detail.durationSec / 60)
        var parts = [dateText, "\(minutes) мин"]
        if let energy = detail.energyBurned, energy > 0 {
            parts.append("\(Int(energy.rounded())) ккал")
        }
        if let distance = detail.distance, distance > 0 {
            parts.append(String(format: "%.1f км", distance / 1000))
        }
        return parts.joined(separator: " • ")
    }

    private func volumeText(_ volume: Double) -> String {
        if volume >= 1000 {
            let tonnes = volume / 1000
            return String(format: "%.1f т", tonnes).replacingOccurrences(of: ".", with: ",")
        }
        return "\(Int(volume.rounded())) кг"
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

// MARK: - Exercise Group Card

struct ExerciseGroupCard: View {
    let group: WorkoutDetailView.ExerciseGroup
    let isDeleting: Bool
    let onDeleteRequested: () -> Void

    // Custom swipe-left: this card is not inside a List, so native
    // `.swipeActions` are unavailable. A horizontal drag reveals a delete
    // button; releasing past the threshold triggers the confirmation.
    @State private var dragOffset: CGFloat = 0
    @State private var isOpen = false

    private let actionWidth: CGFloat = 88
    private let triggerThreshold: CGFloat = 64

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete action revealed behind the card.
            Button(action: onDeleteRequested) {
                VStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Удалить")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(width: actionWidth)
                .frame(maxHeight: .infinity)
            }
            .buttonStyle(.plain)
            .background(AGColors.red)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .disabled(isDeleting)
            .opacity(min(1, abs(dragOffset) / triggerThreshold))

            cardContent
                .offset(x: dragOffset)
                .gesture(dragGesture)
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(group.exerciseName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)

                if let muscleGroup = group.muscleGroup, !muscleGroup.isEmpty {
                    Text(muscleGroup)
                        .font(.system(size: 12))
                        .foregroundStyle(AGContentColors.secondaryText)
                }
            }

            ForEach(group.sets) { set in
                HStack {
                    Text("\(set.orderInWorkout)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AGContentColors.secondaryText)
                        .frame(width: 24, alignment: .leading)

                    Text(weightText(set.weightKg) + " × " + "\(set.reps)")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)

                    Spacer()
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AGContentColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                // Only react to horizontal left swipes; keep vertical scroll intact.
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let base = isOpen ? -actionWidth : 0
                let proposed = base + value.translation.width
                dragOffset = min(0, max(-actionWidth, proposed))
            }
            .onEnded { value in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if -dragOffset >= triggerThreshold {
                        dragOffset = -actionWidth
                        isOpen = true
                    } else {
                        dragOffset = 0
                        isOpen = false
                    }
                }
            }
    }

    private func weightText(_ weight: Double) -> String {
        if weight == weight.rounded() {
            return "\(Int(weight)) кг"
        }
        return String(format: "%.1f кг", weight)
    }
}

struct WorkoutStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(
                    .system(
                        size: 20,
                        weight: .bold
                    )
                )
                .foregroundStyle(.white)

            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(
                    AGContentColors.secondaryText
                )
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding(14)
        .background(
            AGContentColors.card
        )
        .clipShape(
            RoundedRectangle(cornerRadius: 16)
        )
    }
}
