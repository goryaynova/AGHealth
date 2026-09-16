import SwiftUI

// MARK: - Exercises Directory
//
// Standalone «Упражнения» screen (Ещё → Упражнения). This is the ONE place
// where the global exercise catalog is managed: view, create, edit, and
// archive/delete (via `DELETE /api/v1/fitness/exercises/{id}`).
//
// This is deliberately separate from the exercise picker inside a strength
// workout — the picker is selection-only. Removing an exercise from a single
// workout is a different action (handled in WorkoutDetailView), and never
// touches the global catalog.

struct ExercisesView: View {
    private let apiConfiguration = APIConfiguration()

    @State private var exercises: [APIClient.Exercise] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var searchText = ""

    // Sheets
    @State private var showingCreateSheet = false
    @State private var exerciseBeingEdited: APIClient.Exercise?

    // Archive/delete
    @State private var exercisePendingDeletion: APIClient.Exercise?
    @State private var isMutating = false

    private var filteredExercises: [APIClient.Exercise] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let active = exercises
            .filter { !$0.isArchived }
            .sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        if query.isEmpty { return active }
        return active.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        ZStack {
            AGColors.background
                .ignoresSafeArea()

            content
        }
        .navigationTitle("Упражнения")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AGColors.blue)
                }
            }
        }
        .task {
            await loadExercises()
        }
        .sheet(isPresented: $showingCreateSheet) {
            ExerciseEditorView(
                mode: .create,
                onSave: { draft in
                    try await createExercise(draft)
                }
            )
        }
        .sheet(item: $exerciseBeingEdited) { exercise in
            ExerciseEditorView(
                mode: .edit(exercise),
                onSave: { draft in
                    try await updateExercise(exercise, draft: draft)
                }
            )
        }
        .confirmationDialog(
            exercisePendingDeletion.map { "Удалить «\($0.name)»?" } ?? "Удалить упражнение?",
            isPresented: Binding(
                get: { exercisePendingDeletion != nil },
                set: { isPresented in
                    if !isPresented { exercisePendingDeletion = nil }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Удалить", role: .destructive) {
                if let exercise = exercisePendingDeletion {
                    Task { await archiveExercise(exercise) }
                }
            }
            Button("Отмена", role: .cancel) {
                exercisePendingDeletion = nil
            }
        } message: {
            Text(
                "Упражнение уйдёт из справочника и перестанет предлагаться при добавлении подходов. Уже сохранённые тренировки и подходы не изменятся."
            )
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLoading && exercises.isEmpty {
            ProgressView()
                .tint(.white)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    searchField

                    if let errorMessage {
                        ErrorCard(message: errorMessage)
                    }

                    if filteredExercises.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 10) {
                            ForEach(filteredExercises) { exercise in
                                ExerciseDirectoryRow(
                                    exercise: exercise,
                                    isMutating: isMutating,
                                    onEdit: { exerciseBeingEdited = exercise },
                                    onDelete: {
                                        errorMessage = nil
                                        exercisePendingDeletion = exercise
                                    }
                                )
                            }
                        }
                    }

                    Color.clear.frame(height: 30)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AGColors.secondaryText)

            TextField(
                "",
                text: $searchText,
                prompt: Text("Найти упражнение")
                    .foregroundStyle(AGColors.secondaryText)
            )
            .textFieldStyle(.plain)
            .foregroundStyle(.white)
            .font(.system(size: 16))
            .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(AGColors.card)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AGColors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 38))
                .foregroundStyle(AGColors.secondaryText)

            Text(
                searchText.isEmpty
                ? "Справочник пуст"
                : "Ничего не найдено"
            )
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)

            Text(
                searchText.isEmpty
                ? "Добавьте первое упражнение кнопкой «＋» вверху."
                : "Попробуйте изменить запрос."
            )
            .font(.system(size: 14))
            .foregroundStyle(AGColors.secondaryText)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Data operations

    private func loadExercises() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let client = try apiConfiguration.makeAPIClient()
            let loaded = try await client.fetchExercises()
            await MainActor.run { exercises = loaded }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func createExercise(_ draft: ExerciseDraft) async throws {
        let client = try apiConfiguration.makeAPIClient()
        let created = try await client.createExercise(
            id: UUID().uuidString,
            name: draft.name,
            primary: draft.primaryInput,
            secondary: draft.secondaryInputs
        )
        await MainActor.run {
            exercises.removeAll { $0.id == created.id }
            exercises.append(created)
        }
    }

    private func updateExercise(
        _ exercise: APIClient.Exercise,
        draft: ExerciseDraft
    ) async throws {
        let client = try apiConfiguration.makeAPIClient()
        let updated = try await client.patchExercise(
            id: exercise.id,
            name: draft.name,
            primary: draft.primaryInput,
            secondary: draft.secondaryInputs
        )
        await MainActor.run {
            if let index = exercises.firstIndex(where: { $0.id == updated.id }) {
                exercises[index] = updated
            }
        }
    }

    private func archiveExercise(_ exercise: APIClient.Exercise) async {
        guard !isMutating else { return }
        isMutating = true
        errorMessage = nil
        defer {
            isMutating = false
            exercisePendingDeletion = nil
        }

        do {
            let client = try apiConfiguration.makeAPIClient()
            try await client.deleteExercise(id: exercise.id)
            await MainActor.run {
                exercises.removeAll { $0.id == exercise.id }
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }
}

// MARK: - Directory Row

struct ExerciseDirectoryRow: View {
    let exercise: APIClient.Exercise
    let isMutating: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AGColors.orange.opacity(0.12))

                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AGColors.orange)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)

                if let muscleGroup = exercise.muscleGroup, !muscleGroup.isEmpty {
                    Text(muscleGroup)
                        .font(.system(size: 13))
                        .foregroundStyle(AGColors.secondaryText)
                }
            }

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AGColors.blue)
                    .frame(width: 34, height: 34)
                    .background(AGColors.blue.opacity(0.10))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(isMutating)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AGColors.red.opacity(0.85))
                    .frame(width: 34, height: 34)
                    .background(AGColors.red.opacity(0.10))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(isMutating)
            .opacity(isMutating ? 0.5 : 1)
        }
        .padding(14)
        .background(AGColors.card)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AGColors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Editor draft

/// The user-facing draft for creating/editing an exercise: one primary muscle
/// (body part + specific muscle) and any number of secondary muscles. The UI
/// only shows the role («Основная»/«Дополнительная»); contribution coefficients
/// live in the backend model.
struct ExerciseDraft {
    var name: String
    var primaryPartKey: String?
    var primaryMuscle: String?
    var secondaries: [SecondaryDraft]

    struct SecondaryDraft: Identifiable, Hashable {
        let id = UUID()
        var partKey: String?
        var muscle: String?
    }

    var primaryInput: APIClient.MuscleInput? {
        guard let key = primaryPartKey else { return nil }
        return APIClient.MuscleInput(bodyPart: key, muscle: primaryMuscle, contribution: nil)
    }

    var secondaryInputs: [APIClient.MuscleInput] {
        secondaries.compactMap { s in
            guard let key = s.partKey else { return nil }
            return APIClient.MuscleInput(bodyPart: key, muscle: s.muscle, contribution: nil)
        }
    }
}

// MARK: - Editor (create / edit)

struct ExerciseEditorView: View {
    enum Mode {
        case create
        case edit(APIClient.Exercise)

        var title: String {
            switch self {
            case .create: return "Новое упражнение"
            case .edit: return "Редактировать"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    let onSave: (ExerciseDraft) async throws -> Void

    @State private var name: String = ""
    @State private var primaryPartKey: String?
    @State private var primaryMuscle: String?
    @State private var secondaries: [ExerciseDraft.SecondaryDraft] = []
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && primaryPartKey != nil
        && !isSaving
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AGColors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        fieldLabel("НАЗВАНИЕ")
                        textField("Например: Жим лёжа", text: $name)

                        // Primary influence: body part → specific muscle.
                        fieldLabel("ОСНОВНОЕ ВЛИЯНИЕ")
                        MusclePickerRow(
                            partKey: $primaryPartKey,
                            muscle: $primaryMuscle
                        )
                        Text("Обязательно: часть тела, затем конкретная мышца.")
                            .font(.system(size: 12))
                            .foregroundStyle(AGColors.secondaryText)

                        // Secondary influence: any number of assisting muscles.
                        HStack {
                            fieldLabel("ДОПОЛНИТЕЛЬНОЕ ВЛИЯНИЕ")
                            Spacer()
                        }

                        ForEach($secondaries) { $secondary in
                            HStack(alignment: .top, spacing: 8) {
                                MusclePickerRow(
                                    partKey: $secondary.partKey,
                                    muscle: $secondary.muscle
                                )
                                Button {
                                    secondaries.removeAll { $0.id == secondary.id }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(AGColors.red.opacity(0.85))
                                        .padding(.top, 6)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Button {
                            secondaries.append(ExerciseDraft.SecondaryDraft())
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle")
                                Text("Добавить дополнительную мышцу")
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AGColors.blue)
                        }
                        .buttonStyle(.plain)

                        if let errorMessage {
                            ErrorCard(message: errorMessage)
                        }

                        Color.clear.frame(height: 80)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                }

                VStack {
                    Spacer()
                    AGPrimaryButton(
                        title: "Сохранить",
                        isLoading: isSaving,
                        isDisabled: !canSave,
                        action: { Task { await save() } }
                    )
                    .padding(.horizontal, 18)
                    .padding(.bottom, 10)
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                        .foregroundStyle(AGColors.blue)
                }
            }
            .preferredColorScheme(.dark)
            .onAppear(perform: prefill)
        }
    }

    private func prefill() {
        guard case let .edit(exercise) = mode else { return }
        name = exercise.name
        if let primary = exercise.primaryMuscle {
            primaryPartKey = primary.groupKey
            primaryMuscle = primary.muscle
        } else if let key = exercise.muscleGroupKey {
            primaryPartKey = key
            primaryMuscle = exercise.muscle
        }
        secondaries = exercise.secondaryMuscles.map {
            ExerciseDraft.SecondaryDraft(partKey: $0.groupKey, muscle: $0.muscle)
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .tracking(1.1)
            .foregroundStyle(AGColors.secondaryText)
    }

    private func textField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(
            "",
            text: text,
            prompt: Text(placeholder).foregroundStyle(AGColors.secondaryText)
        )
        .textFieldStyle(.plain)
        .foregroundStyle(.white)
        .font(.system(size: 16))
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(AGColors.input)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AGColors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func save() async {
        guard canSave else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let draft = ExerciseDraft(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            primaryPartKey: primaryPartKey,
            primaryMuscle: primaryMuscle,
            secondaries: secondaries.filter { $0.partKey != nil }
        )

        do {
            try await onSave(draft)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Muscle picker (body part → muscle)

/// Two chained menus: pick a body part, then a specific muscle of that part.
/// Changing the body part resets the muscle. Muscle is optional (a part-only
/// choice is allowed and sends no specific muscle).
struct MusclePickerRow: View {
    @Binding var partKey: String?
    @Binding var muscle: String?

    private var partLabel: String {
        partKey.map { MuscleCatalog.label(forKey: $0) } ?? "Часть тела"
    }

    private var muscleLabel: String {
        muscle ?? "Мышца"
    }

    private var muscleOptions: [String] {
        partKey.map { MuscleCatalog.muscles(forKey: $0) } ?? []
    }

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(MuscleCatalog.parts) { part in
                    Button(part.label) {
                        if partKey != part.key {
                            partKey = part.key
                            muscle = nil
                        }
                    }
                }
            } label: {
                pickerLabel(partLabel, active: partKey != nil)
            }

            Menu {
                if muscleOptions.isEmpty {
                    Button("— сначала выберите часть тела —") {}.disabled(true)
                } else {
                    ForEach(muscleOptions, id: \.self) { m in
                        Button(m) { muscle = m }
                    }
                }
            } label: {
                pickerLabel(muscleLabel, active: muscle != nil)
            }
            .disabled(partKey == nil)
        }
    }

    private func pickerLabel(_ text: String, active: Bool) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(active ? .white : AGColors.secondaryText)
                .lineLimit(1)
            Spacer(minLength: 0)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 11))
                .foregroundStyle(AGColors.secondaryText)
        }
        .padding(.horizontal, 12)
        .frame(height: 46)
        .frame(maxWidth: .infinity)
        .background(AGColors.input)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AGColors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
