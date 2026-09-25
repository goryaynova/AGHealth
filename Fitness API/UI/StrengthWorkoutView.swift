import SwiftUI

// MARK: - Strength Workout

struct StrengthWorkoutView: View {
    @Environment(\.dismiss) private var dismiss

    let workoutID: String

    private let apiConfiguration = APIConfiguration()

    @State private var exercises: [APIClient.Exercise] = []
    @State private var selectedExercises: [SelectedExercise] = []

    @State private var isLoadingExercises = false
    @State private var isSaving = false
    @State private var errorMessage = ""

    @State private var showingExercisePicker = false

    var body: some View {
        ZStack {
            AGColors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // MARK: Title

                    VStack(alignment: .leading, spacing: 6) {
                        Text("СИЛОВАЯ ТРЕНИРОВКА")
                            .font(.system(size: 12, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(AGColors.secondaryText)

                        Text("Добавление упражнений")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    // MARK: Selected exercises

                    if selectedExercises.isEmpty {
                        AGEmptyWorkoutCard {
                            showingExercisePicker = true
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("УПРАЖНЕНИЯ")
                                    .font(.system(size: 12, weight: .bold))
                                    .tracking(1.1)
                                    .foregroundStyle(AGColors.secondaryText)

                                Spacer()

                                Text("\(selectedExercises.count)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AGColors.blue)
                            }

                            ForEach($selectedExercises) { $exercise in
                                SelectedExerciseView(
                                    exercise: $exercise
                                )
                            }
                        }
                    }

                    // MARK: Add exercise
                    // Когда упражнений ещё нет, CTA уже есть в AGEmptyWorkoutCard выше —
                    // вторую одинаковую кнопку не показываем. Отдельная кнопка «Добавить
                    // упражнение» нужна только чтобы добавить второе/третье упражнение.
                    if !selectedExercises.isEmpty {
                        AGSecondaryButton(
                            title: "Добавить упражнение",
                            systemImage: "plus",
                            action: {
                                showingExercisePicker = true
                            }
                        )
                        // Не блокируем кнопку: если список ещё не загружен, пикер загрузит его сам.
                    }

                    // MARK: Error

                    if !errorMessage.isEmpty {
                        ErrorCard(message: errorMessage)
                    }

                    Color.clear
                        .frame(height: 100)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
            }

            // MARK: Save button

            VStack {
                Spacer()

                VStack(spacing: 10) {
                    Rectangle()
                        .fill(AGColors.border)
                        .frame(height: 1)

                    AGPrimaryButton(
                        title: "Сохранить тренировку",
                        isLoading: isSaving,
                        isDisabled:
                            isSaving ||
                            selectedExercises.isEmpty ||
                            !hasValidSets,
                        action: {
                            Task {
                                await saveExercises()
                            }
                        }
                    )
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(
                    AGColors.background.opacity(0.97)
                )
            }
        }
        .preferredColorScheme(.dark)
        .safeAreaInset(edge: .top) {
            AGWorkoutHeader {
                dismiss()
            }
        }
        .task {
            await loadExercises()
        }
        .fullScreenCover(
            isPresented: $showingExercisePicker
        ) {
            ExercisePickerView(
                exercises: exercises,
                selectedExerciseIDs: Set(
                    selectedExercises.map(\.exercise.id)
                ),
                onSelect: { exercise in
                    addExercise(exercise)
                }
            )
        }
    }

    // MARK: - Load exercises

    private func loadExercises() async {
        print("[EXERCISES][CALLER=PARENT][\(Date().timeIntervalSince1970)] loadExercises() entered, isLoadingExercises=\(isLoadingExercises)")
        guard !isLoadingExercises else {
            print("[EXERCISES][CALLER=PARENT] GUARD skipped (already loading)")
            return
        }

        isLoadingExercises = true
        errorMessage = ""

        defer {
            isLoadingExercises = false
        }

        do {
            let client = try apiConfiguration.makeAPIClient()

            let loadedExercises = try await client.fetchExercises()

            await MainActor.run {
                exercises = loadedExercises
                    .filter { !$0.isArchived }
                    .sorted {
                        $0.name.localizedCaseInsensitiveCompare($1.name)
                        == .orderedAscending
                    }
            }

            print(
                "AGHealth: loaded \(loadedExercises.count) exercises"
            )

        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }

            print(
                "AGHealth: exercise loading error = \(error)"
            )
        }
    }

    // MARK: - Add exercise

    private func addExercise(
        _ exercise: APIClient.Exercise
    ) {
        guard !selectedExercises.contains(where: {
            $0.exercise.id == exercise.id
        }) else {
            return
        }

        selectedExercises.append(
            SelectedExercise(
                exercise: exercise,
                sets: [
                    StrengthSetDraft(order: 1)
                ]
            )
        )

        print(
            "AGHealth: selected exercise = \(exercise.name)"
        )
    }

    // MARK: - Validation

    private var hasValidSets: Bool {
        guard !selectedExercises.isEmpty else {
            return false
        }

        return selectedExercises.allSatisfy { exercise in
            !exercise.sets.isEmpty &&
            exercise.sets.allSatisfy { set in
                set.reps > 0 &&
                set.weight >= 0
            }
        }
    }

    // MARK: - Save

    private func saveExercises() async {
        guard !isSaving else {
            return
        }

        guard hasValidSets else {
            errorMessage =
                "Проверьте вес и количество повторений."
            return
        }

        isSaving = true
        errorMessage = ""

        defer {
            isSaving = false
        }

        do {
            let client = try apiConfiguration.makeAPIClient()

            print("AGHealth: saving exercises")
            print(
                "AGHealth: existing HealthKit workout ID = \(workoutID)"
            )

            var globalOrder = 1

            for selectedExercise in selectedExercises {
                print(
                    "AGHealth: exercise = \(selectedExercise.exercise.name)"
                )

                for set in selectedExercise.sets {
                    print(
                        """
                        AGHealth: saving set
                        workoutID = \(workoutID)
                        exerciseID = \(selectedExercise.exercise.id)
                        order = \(globalOrder)
                        reps = \(set.reps)
                        weight = \(set.weight)
                        """
                    )

                    try await client.addStrengthSet(
                        workoutId: workoutID,
                        id: UUID().uuidString,
                        exerciseId: selectedExercise.exercise.id,
                        setOrder: globalOrder,
                        reps: set.reps,
                        weightKg: set.weight
                    )

                    globalOrder += 1
                }
            }

            print(
                "AGHealth: exercises saved to existing workout successfully"
            )

            dismiss()

        } catch {
            print(
                "AGHealth: save exercises error = \(error)"
            )

            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Selected Exercise

struct SelectedExercise: Identifiable {
    let id = UUID()

    let exercise: APIClient.Exercise

    var sets: [StrengthSetDraft]
}

// MARK: - Set Draft

struct StrengthSetDraft: Identifiable {
    let id = UUID()

    var order: Int
    var weight: Double = 0
    var reps: Int = 0
}

// MARK: - Selected Exercise Card

struct SelectedExerciseView: View {
    @Binding var exercise: SelectedExercise

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {

            // Header

            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(
                        cornerRadius: 12,
                        style: .continuous
                    )
                    .fill(
                        AGColors.orange.opacity(0.15)
                    )

                    Image(
                        systemName:
                            "figure.strengthtraining.traditional"
                    )
                    .font(
                        .system(
                            size: 20,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        AGColors.orange
                    )
                }
                .frame(
                    width: 44,
                    height: 44
                )

                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {
                    Text(exercise.exercise.name)
                        .font(
                            .system(
                                size: 17,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(.white)

                    if let muscleGroup =
                        exercise.exercise.muscleGroup,
                       !muscleGroup.isEmpty {

                        Text(muscleGroup)
                            .font(
                                .system(
                                    size: 13,
                                    weight: .regular
                                )
                            )
                            .foregroundStyle(
                                AGColors.secondaryText
                            )
                    }
                }

                Spacer()
            }

            // Column headers

            HStack(spacing: 10) {
                Text("#")
                    .frame(width: 26)

                Text("ВЕС")
                    .frame(maxWidth: .infinity)

                Text("ПОВТ.")
                    .frame(maxWidth: .infinity)

                Color.clear
                    .frame(width: 30)
            }
            .font(
                .system(
                    size: 10,
                    weight: .bold
                )
            )
            .tracking(0.8)
            .foregroundStyle(
                AGColors.secondaryText
            )

            // Sets

            ForEach($exercise.sets) { $set in
                HStack(spacing: 10) {

                    Text("\(set.order)")
                        .font(
                            .system(
                                size: 13,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(
                            AGColors.secondaryText
                        )
                        .frame(width: 26)

                    AGDoubleField(
                        value: $set.weight,
                        placeholder: "0",
                        suffix: "кг",
                        keyboard: .decimalPad
                    )

                    AGIntField(
                        value: $set.reps,
                        placeholder: "0",
                        suffix: "раз",
                        keyboard: .numberPad
                    )

                    Button {
                        removeSet(set.id)
                    } label: {
                        Image(
                            systemName:
                                "minus.circle.fill"
                        )
                        .font(.system(size: 21))
                        .foregroundStyle(
                            AGColors.red.opacity(0.85)
                        )
                    }
                    .buttonStyle(.plain)
                    .frame(width: 30)
                }
            }

            // Add set

            Button {
                addSet()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(
                            .system(
                                size: 13,
                                weight: .bold
                            )
                        )

                    Text("Добавить подход")
                        .font(
                            .system(
                                size: 14,
                                weight: .semibold
                            )
                        )
                }
                .foregroundStyle(
                    AGColors.blue
                )
                .frame(
                    maxWidth: .infinity,
                    minHeight: 44
                )
                .background(
                    AGColors.blue.opacity(0.10)
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 12,
                        style: .continuous
                    )
                )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            AGColors.card
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .stroke(
                AGColors.border,
                lineWidth: 1
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
    }

    private func addSet() {
        let nextOrder =
            exercise.sets.count + 1

        exercise.sets.append(
            StrengthSetDraft(
                order: nextOrder
            )
        )
    }

    private func removeSet(
        _ id: UUID
    ) {
        guard exercise.sets.count > 1 else {
            return
        }

        exercise.sets.removeAll {
            $0.id == id
        }

        for index in exercise.sets.indices {
            exercise.sets[index].order =
                index + 1
        }
    }
}

// MARK: - Exercise Picker

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss

    // Exercises passed in by the parent (already loaded). May be empty if the parent hasn't
    // finished loading yet — in that case the picker loads the catalog itself (see `load()`), so the
    // list is ALWAYS shown regardless of parent timing (fix: пропадал список при быстром открытии).
    let exercises: [APIClient.Exercise]
    let selectedExerciseIDs: Set<String>
    let onSelect: (APIClient.Exercise) -> Void

    private let apiConfiguration = APIConfiguration()

    @State private var searchText = ""
    // Self-loaded fallback catalog, used only when the parent passed an empty list.
    @State private var loadedExercises: [APIClient.Exercise] = []
    @State private var isLoading = false
    @State private var loadError = ""
    // ДИАГНОСТИКА на экране: накопленные этапы с таймингами (видно в UI, без консоли).
    @State private var diag: [String] = []
    private func diagAdd(_ s: String) {
        let ts = Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 100000)
        diag.append(String(format: "%.2f %@", ts, s))
    }

    // The effective source: prefer the parent's list, fall back to the self-loaded one.
    private var sourceExercises: [APIClient.Exercise] {
        exercises.isEmpty ? loadedExercises : exercises
    }

    private var filteredExercises: [APIClient.Exercise] {
        let query =
            searchText.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        if query.isEmpty {
            return sourceExercises
        }

        return sourceExercises.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    // Loads the catalog itself when the parent handed over an empty list (timing / failed parent
    // fetch). Filters archived + sorts, mirroring the parent's loadExercises().
    private func load() async {
        await MainActor.run { diagAdd("load() entered parent=\(exercises.count) loaded=\(loadedExercises.count) isLoading=\(isLoading)") }
        guard exercises.isEmpty, loadedExercises.isEmpty, !isLoading else {
            await MainActor.run { diagAdd("GUARD skipped (parent=\(exercises.count) isLoading=\(isLoading))") }
            return
        }
        await MainActor.run { isLoading = true; loadError = "" }
        defer { Task { @MainActor in isLoading = false; diagAdd("defer isLoading=false") } }
        do {
            let client = try apiConfiguration.makeAPIClient()
            await MainActor.run { diagAdd("calling fetchExercises()") }
            let loaded = try await client.fetchExercises()
            await MainActor.run {
                diagAdd("fetchExercises RETURNED \(loaded.count)")
                loadedExercises = loaded
                    .filter { !$0.isArchived }
                    .sorted {
                        $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                    }
                diagAdd("STATE UPDATED loaded=\(loadedExercises.count)")
            }
        } catch {
            await MainActor.run {
                loadError = "Ошибка: \(error.localizedDescription)"
                diagAdd("CATCH \(error)")
            }
        }
    }

    var body: some View {
        ZStack {
            AGColors.background
                .ignoresSafeArea()

            VStack(
                alignment: .leading,
                spacing: 18
            ) {

                // Header

                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(
                                .system(
                                    size: 15,
                                    weight: .bold
                                )
                            )
                            .foregroundStyle(.white)
                            .frame(
                                width: 40,
                                height: 40
                            )
                            .background(
                                AGColors.card
                            )
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("Упражнение")
                        .font(
                            .system(
                                size: 17,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(.white)

                    Spacer()

                    Color.clear
                        .frame(
                            width: 40,
                            height: 40
                        )
                }

                // Search

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(
                            AGColors.secondaryText
                        )

                    TextField(
                        "",
                        text: $searchText,
                        prompt: Text("Найти упражнение")
                            .foregroundStyle(
                                AGColors.secondaryText
                            )
                    )
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .font(
                        .system(
                            size: 16,
                            weight: .regular
                        )
                    )
                    .autocorrectionDisabled()
                }
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(
                    AGColors.card
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: 14,
                        style: .continuous
                    )
                    .stroke(
                        AGColors.border,
                        lineWidth: 1
                    )
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 14,
                        style: .continuous
                    )
                )

                // Results

                if isLoading && sourceExercises.isEmpty {
                    // Самозагрузка каталога (родитель ещё не передал список) — показываем спиннер.
                    Spacer()
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else if filteredExercises.isEmpty {
                    Spacer()

                    VStack(spacing: 12) {
                        Image(
                            systemName:
                                "figure.strengthtraining.traditional"
                        )
                        .font(.system(size: 38))
                        .foregroundStyle(
                            AGColors.secondaryText
                        )

                        // BUILD-маркер: если этот текст виден — сборка СВЕЖАЯ.
                        Text("⚙︎ build: diag-onscreen")
                            .font(.system(size: 11)).foregroundStyle(AGColors.blue)

                        // ДИАГНОСТИКА на экране: этапы загрузки с таймингами — сфотографируй этот блок.
                        if !diag.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(Array(diag.enumerated()), id: \.offset) { _, line in
                                    Text(line)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.85))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(8)
                            .background(Color.black.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(.horizontal, 12)
                        }

                        Text(
                            searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? "Упражнения не загружены"
                            : "Упражнение не найдено"
                        )
                            .font(
                                .system(
                                    size: 17,
                                    weight: .semibold
                                )
                            )
                            .foregroundStyle(.white)

                        Text(
                            !loadError.isEmpty
                            ? loadError
                            : (searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                               ? "Не удалось загрузить справочник."
                               : "Попробуйте изменить запрос.")
                        )
                        .font(
                            .system(
                                size: 14
                            )
                        )
                        .foregroundStyle(
                            AGColors.secondaryText
                        )
                        .multilineTextAlignment(.center)

                        // Повторная попытка, если каталог пуст (ошибка сети/тайминг).
                        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button {
                                Task {
                                    loadedExercises = []
                                    await load()
                                }
                            } label: {
                                Text("Обновить")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 20)
                                    .frame(height: 44)
                                    .background(AGColors.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)
                        }
                    }
                    .frame(
                        maxWidth: .infinity
                    )

                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(
                            spacing: 10
                        ) {
                            ForEach(
                                filteredExercises
                            ) { exercise in

                                ExercisePickerRow(
                                    exercise: exercise,
                                    isSelected:
                                        selectedExerciseIDs
                                        .contains(
                                            exercise.id
                                        ),
                                    action: {
                                        guard
                                            !selectedExerciseIDs
                                                .contains(
                                                    exercise.id
                                                )
                                        else {
                                            return
                                        }

                                        onSelect(exercise)
                                        dismiss()
                                    }
                                )
                            }
                        }
                        .padding(.bottom, 20)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
        }
        .preferredColorScheme(.dark)
        .task {
            await load()
        }
    }
}

// MARK: - Picker Row

struct ExercisePickerRow: View {
    let exercise: APIClient.Exercise
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {

                    ZStack {
                        RoundedRectangle(
                            cornerRadius: 12,
                            style: .continuous
                        )
                        .fill(
                            isSelected
                            ? AGColors.green.opacity(0.15)
                            : AGColors.orange.opacity(0.12)
                        )

                        Image(
                            systemName:
                                "figure.strengthtraining.traditional"
                        )
                        .font(
                            .system(
                                size: 19,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(
                            isSelected
                            ? AGColors.green
                            : AGColors.orange
                        )
                    }
                    .frame(
                        width: 46,
                        height: 46
                    )

                    VStack(
                        alignment: .leading,
                        spacing: 4
                    ) {
                        Text(exercise.name)
                            .font(
                                .system(
                                    size: 16,
                                    weight: .semibold
                                )
                            )
                            .foregroundStyle(.white)

                        if let muscleGroup =
                            exercise.muscleGroup,
                           !muscleGroup.isEmpty {

                            Text(muscleGroup)
                                .font(
                                    .system(
                                        size: 13
                                    )
                                )
                                .foregroundStyle(
                                    AGColors.secondaryText
                                )
                        }
                    }

                    Spacer()

                    Image(
                        systemName:
                            isSelected
                            ? "checkmark.circle.fill"
                            : "plus.circle.fill"
                    )
                    .font(.system(size: 23))
                    .foregroundStyle(
                        isSelected
                        ? AGColors.green
                        : AGColors.blue
                    )
            }
        }
        .buttonStyle(.plain)
        .padding(14)
        .background(
            AGColors.card
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .stroke(
                isSelected
                ? AGColors.green.opacity(0.35)
                : AGColors.border,
                lineWidth: 1
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
        )
    }
}

// MARK: - Empty Workout

struct AGEmptyWorkoutCard: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        AGColors.orange.opacity(0.14)
                    )

                Image(
                    systemName:
                        "figure.strengthtraining.traditional"
                )
                .font(.system(size: 34))
                .foregroundStyle(
                    AGColors.orange
                )
            }
            .frame(
                width: 72,
                height: 72
            )

            VStack(spacing: 6) {
                Text("Тренировка пока пустая")
                    .font(
                        .system(
                            size: 18,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.white)

                Text(
                    "Добавьте первое упражнение и начните записывать подходы."
                )
                .font(
                    .system(
                        size: 14
                    )
                )
                .foregroundStyle(
                    AGColors.secondaryText
                )
                .multilineTextAlignment(.center)
            }

            Button {
                action()
            } label: {
                Text("Добавить упражнение")
                    .font(
                        .system(
                            size: 15,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.white)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: 48
                    )
                    .background(
                        AGColors.blue
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 14,
                            style: .continuous
                        )
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            AGColors.card
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .stroke(
                AGColors.border,
                lineWidth: 1
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
    }
}

// MARK: - Double Field

struct AGDoubleField: View {
    @Binding var value: Double

    let placeholder: String
    let suffix: String
    let keyboard: UIKeyboardType

    var body: some View {
        HStack(spacing: 4) {
            TextField(
                placeholder,
                value: $value,
                format: .number
            )
            .keyboardType(keyboard)
            .textFieldStyle(.plain)
            .font(
                .system(
                    size: 16,
                    weight: .semibold
                )
            )
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)

            Text(suffix)
                .font(
                    .system(
                        size: 11,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    AGColors.secondaryText
                )
        }
        .padding(.horizontal, 10)
        .frame(
            maxWidth: .infinity,
            minHeight: 46
        )
        .background(
            AGColors.input
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 12,
                style: .continuous
            )
            .stroke(
                AGColors.border,
                lineWidth: 1
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 12,
                style: .continuous
            )
        )
    }
}

// MARK: - Int Field

struct AGIntField: View {
    @Binding var value: Int

    let placeholder: String
    let suffix: String
    let keyboard: UIKeyboardType

    var body: some View {
        HStack(spacing: 4) {
            TextField(
                placeholder,
                value: $value,
                format: .number
            )
            .keyboardType(keyboard)
            .textFieldStyle(.plain)
            .font(
                .system(
                    size: 16,
                    weight: .semibold
                )
            )
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)

            Text(suffix)
                .font(
                    .system(
                        size: 11,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    AGColors.secondaryText
                )
        }
        .padding(.horizontal, 10)
        .frame(
            maxWidth: .infinity,
            minHeight: 46
        )
        .background(
            AGColors.input
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 12,
                style: .continuous
            )
            .stroke(
                AGColors.border,
                lineWidth: 1
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 12,
                style: .continuous
            )
        )
    }
}

// MARK: - Header

struct AGWorkoutHeader: View {
    let onClose: () -> Void

    var body: some View {
        HStack {
            Button {
                onClose()
            } label: {
                Image(
                    systemName: "chevron.left"
                )
                .font(
                    .system(
                        size: 17,
                        weight: .semibold
                    )
                )
                .foregroundStyle(.white)
                .frame(
                    width: 40,
                    height: 40
                )
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Тренировка")
                .font(
                    .system(
                        size: 17,
                        weight: .semibold
                    )
                )
                .foregroundStyle(.white)

            Spacer()

            Color.clear
                .frame(
                    width: 40,
                    height: 40
                )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            AGColors.background.opacity(0.97)
        )
    }
}

// MARK: - Primary Button

struct AGPrimaryButton: View {
    let title: String
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(title)
                        .font(
                            .system(
                                size: 16,
                                weight: .semibold
                            )
                        )
                }
            }
            .foregroundStyle(.white)
            .frame(
                maxWidth: .infinity,
                minHeight: 54
            )
            .background(
                isDisabled
                ? AGColors.disabled
                : AGColors.blue
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

// MARK: - Secondary Button

struct AGSecondaryButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(
                    systemName: systemImage
                )
                .font(
                    .system(
                        size: 14,
                        weight: .bold
                    )
                )

                Text(title)
                    .font(
                        .system(
                            size: 15,
                            weight: .semibold
                        )
                    )
            }
            .foregroundStyle(
                AGColors.blue
            )
            .frame(
                maxWidth: .infinity,
                minHeight: 50
            )
            .background(
                AGColors.blue.opacity(0.10)
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 15,
                    style: .continuous
                )
                .stroke(
                    AGColors.blue.opacity(0.25),
                    lineWidth: 1
                )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 15,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Error Card

struct ErrorCard: View {
    let message: String

    var body: some View {
        HStack(
            alignment: .top,
            spacing: 10
        ) {
            Image(
                systemName:
                    "exclamationmark.circle.fill"
            )
            .foregroundStyle(
                AGColors.red
            )

            Text(message)
                .font(
                    .system(
                        size: 14
                    )
                )
                .foregroundStyle(.white)

            Spacer()
        }
        .padding(14)
        .background(
            AGColors.red.opacity(0.10)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
            .stroke(
                AGColors.red.opacity(0.25),
                lineWidth: 1
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
        )
    }
}

// MARK: - Colors

enum AGColors {
    static let background =
        Color(
            red: 0.035,
            green: 0.035,
            blue: 0.045
        )

    static let card =
        Color(
            red: 0.075,
            green: 0.075,
            blue: 0.09
        )

    static let input =
        Color(
            red: 0.055,
            green: 0.055,
            blue: 0.07
        )

    static let border =
        Color.white.opacity(0.09)

    static let secondaryText =
        Color.white.opacity(0.52)

    static let blue =
        Color(
            red: 0.18,
            green: 0.48,
            blue: 1.0
        )

    static let orange =
        Color(
            red: 1.0,
            green: 0.56,
            blue: 0.18
        )

    static let green =
        Color(
            red: 0.30,
            green: 0.82,
            blue: 0.52
        )

    static let red =
        Color(
            red: 1.0,
            green: 0.28,
            blue: 0.30
        )

    static let disabled =
        Color.white.opacity(0.12)
}
