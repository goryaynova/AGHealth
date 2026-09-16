import SwiftUI

// «Прогрессия веса» — weight-over-time for a single exercise (never mixed). First the user sees the
// list of exercises that have history; picking one shows its weight progression line + a table with
// weight/reps/volume per session. Drawn with SwiftUI Path (no third-party chart dependency), matching
// the app's existing no-dependency approach.

// «Прогресс силовых» (CP5). Структура по промту:
//   1. Основной уровень — ГРУППА МЫШЦ (Грудь/Спина/…), внутри — упражнения с текущим
//      весом и его изменением («80 кг → +5 кг»).
//   2. ОДИН единый график (не по графику на каждое упражнение): выбор группы → выбор
//      упражнения → график меняет данные. Веса разных упражнений НЕ смешиваются в одну линию.
struct ExerciseProgressionView: View {
    private let apiConfiguration = APIConfiguration()

    @State private var exercises: [APIClient.ProgressionExercise] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    // Единый график: текущее выбранное упражнение.
    @State private var selectedExerciseId: String?

    // Упорядоченные группы мышц с упражнениями (группировка по каноническому muscleGroupKey).
    private var groups: [ProgressionGroup] {
        ProgressionGroup.build(from: exercises)
    }

    private var selectedExercise: APIClient.ProgressionExercise? {
        exercises.first { $0.id == selectedExerciseId } ?? exercises.first
    }

    var body: some View {
        ZStack {
            AGContentColors.background.ignoresSafeArea()

            if isLoading && exercises.isEmpty {
                ProgressView().tint(.white)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let errorMessage {
                            ErrorCard(message: errorMessage)
                        }

                        if exercises.isEmpty {
                            emptyState
                        } else {
                            // 2. Единый график (выбор упражнения → одна линия).
                            UnifiedProgressionChart(
                                exercises: exercises,
                                groups: groups,
                                selectedExerciseId: Binding(
                                    get: { selectedExercise?.id },
                                    set: { selectedExerciseId = $0 }
                                )
                            )

                            // 1. Группы мышц → упражнения с текущим весом и изменением.
                            ForEach(groups) { group in
                                ProgressionGroupSection(
                                    group: group,
                                    selectedExerciseId: selectedExercise?.id,
                                    onSelect: { selectedExerciseId = $0 }
                                )
                            }
                        }

                        Color.clear.frame(height: 24)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                }
            }
        }
        .navigationTitle("Прогресс силовых")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 34))
                .foregroundStyle(AGContentColors.tertiaryText)
            Text("Пока нет истории")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Text("Добавьте подходы с весом — и прогрессия появится здесь.")
                .font(.system(size: 13))
                .foregroundStyle(AGContentColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let client = try apiConfiguration.makeAPIClient()
            let loaded = try await client.fetchProgressionExercises()
            await MainActor.run { exercises = loaded }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }
}

// MARK: - Muscle-group grouping

// A muscle group with its exercises (CP5 grouping). Canonical `key` (muscleGroupKey) dedupes the
// inconsistent display labels; `label` is a single, capitalized Russian name.
struct ProgressionGroup: Identifiable {
    let key: String
    let label: String
    let exercises: [APIClient.ProgressionExercise]
    var id: String { key }

    // Canonical group order + labels, matching the muscle-load vocabulary.
    private static let order = ["back", "chest", "legs", "glutes", "shoulders", "arms", "core", "forearms"]
    private static let labels: [String: String] = [
        "back": "Спина", "chest": "Грудь", "legs": "Ноги", "glutes": "Ягодицы",
        "shoulders": "Плечи", "arms": "Руки", "core": "Пресс", "forearms": "Предплечья",
    ]

    static func build(from exercises: [APIClient.ProgressionExercise]) -> [ProgressionGroup] {
        var byKey: [String: [APIClient.ProgressionExercise]] = [:]
        for ex in exercises {
            let key = ex.muscleGroupKey ?? "other"
            byKey[key, default: []].append(ex)
        }
        // Ordered groups first, then any leftover keys alphabetically.
        let orderedKeys = order.filter { byKey[$0] != nil }
        let extraKeys = byKey.keys.filter { !order.contains($0) }.sorted()
        return (orderedKeys + extraKeys).map { key in
            let list = (byKey[key] ?? []).sorted { $0.name < $1.name }
            let label = labels[key] ?? (list.first?.muscleGroup?.capitalized ?? key)
            return ProgressionGroup(key: key, label: label, exercises: list)
        }
    }
}

// One muscle-group card: group title + its exercises, each with current weight and change.
private struct ProgressionGroupSection: View {
    let group: ProgressionGroup
    let selectedExerciseId: String?
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(group.label.uppercased())
                .font(.system(size: 12, weight: .bold))
                .tracking(1)
                .foregroundStyle(AGContentColors.secondaryText)

            VStack(spacing: 8) {
                ForEach(group.exercises) { ex in
                    Button {
                        onSelect(ex.id)
                    } label: {
                        ProgressionExerciseRow(exercise: ex, isSelected: ex.id == selectedExerciseId)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// One exercise line: name + current weight + change (+N/−N кг). Tapping selects it for the chart.
private struct ProgressionExerciseRow: View {
    let exercise: APIClient.ProgressionExercise
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(exercise.sessions) \(ProgressionFormat.sessionsWord(exercise.sessions))")
                    .font(.system(size: 11))
                    .foregroundStyle(AGContentColors.tertiaryText)
            }
            Spacer()

            // Current weight.
            if let w = exercise.currentWeightKg {
                Text(ProgressionFormat.weight(w))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }

            // Change vs previous session.
            if let c = exercise.changeKg, c != 0 {
                HStack(spacing: 2) {
                    Image(systemName: c > 0 ? "arrow.up" : "arrow.down")
                        .font(.system(size: 9, weight: .bold))
                    Text(ProgressionFormat.weight(abs(c)))
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(c > 0 ? AGContentColors.green : AGContentColors.accent)
                .frame(width: 66, alignment: .trailing)
            } else {
                Text("—")
                    .font(.system(size: 12))
                    .foregroundStyle(AGContentColors.tertiaryText)
                    .frame(width: 66, alignment: .trailing)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AGContentColors.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isSelected ? AGContentColors.accent : Color.clear, lineWidth: 1.5)
                )
        )
    }
}

// MARK: - Unified chart (one graph, exercise selectable)

// ONE graphic block for the whole analytics (task §5 «единый график»). The user picks a group,
// then an exercise within it; the same chart re-plots that exercise's weight series. Different
// exercises are never merged into one line (their absolute kg are not comparable) — the chart shows
// exactly one exercise at a time.
private struct UnifiedProgressionChart: View {
    let exercises: [APIClient.ProgressionExercise]
    let groups: [ProgressionGroup]
    @Binding var selectedExerciseId: String?

    private let apiConfiguration = APIConfiguration()

    @State private var series: [APIClient.ProgressionPoint] = []
    @State private var isLoading = false
    @State private var loadedForId: String?

    private var selected: APIClient.ProgressionExercise? {
        exercises.first { $0.id == selectedExerciseId } ?? exercises.first
    }

    private var weightPoints: [APIClient.ProgressionPoint] {
        series.filter { $0.topWeightKg != nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ГРАФИК РАБОЧЕГО ВЕСА")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1)
                .foregroundStyle(AGContentColors.secondaryText)

            // Exercise selector (grouped) — one chart, data changes with the selection.
            Menu {
                ForEach(groups) { group in
                    Section(group.label) {
                        ForEach(group.exercises) { ex in
                            Button(ex.name) { selectedExerciseId = ex.id }
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(selected?.name ?? "Выберите упражнение")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AGContentColors.secondaryText)
                    Spacer()
                }
                .padding(12)
                .background(AGContentColors.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Group {
                if isLoading {
                    HStack { Spacer(); ProgressView().tint(.white).padding(.vertical, 60); Spacer() }
                } else if weightPoints.count >= 1 {
                    WeightLineChart(points: weightPoints)
                        .frame(height: 190)
                        .padding(14)
                        .background(AGContentColors.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    Text("Для этого упражнения пока недостаточно данных с весом.")
                        .font(.system(size: 13))
                        .foregroundStyle(AGContentColors.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 20)
                }
            }
        }
        .task(id: selected?.id) { await loadSeries() }
    }

    private func loadSeries() async {
        guard let id = selected?.id, id != loadedForId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let client = try apiConfiguration.makeAPIClient()
            let prog = try await client.fetchExerciseProgression(exerciseId: id)
            await MainActor.run {
                series = prog.points
                loadedForId = id
            }
        } catch {
            await MainActor.run { series = [] }
        }
    }
}

// Shared small formatters for the progression screens.
enum ProgressionFormat {
    static func weight(_ w: Double) -> String {
        if w == w.rounded() { return "\(Int(w)) кг" }
        return String(format: "%.1f кг", w)
    }
    static func sessionsWord(_ n: Int) -> String {
        let mod10 = n % 10, mod100 = n % 100
        if mod10 == 1 && mod100 != 11 { return "тренировка" }
        if (2...4).contains(mod10) && !(12...14).contains(mod100) { return "тренировки" }
        return "тренировок"
    }
}

// MARK: - Detail: one exercise's weight line + table

struct ExerciseProgressionDetailView: View {
    let exerciseId: String
    let exerciseName: String

    private let apiConfiguration = APIConfiguration()

    @State private var progression: APIClient.ExerciseProgression?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var points: [APIClient.ProgressionPoint] {
        (progression?.points ?? []).filter { $0.topWeightKg != nil }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if isLoading && progression == nil {
                    HStack { Spacer(); ProgressView().tint(.white).padding(.vertical, 60); Spacer() }
                } else if let errorMessage, progression == nil {
                    ErrorCard(message: errorMessage)
                } else if points.count < 1 {
                    emptyState
                } else {
                    summaryHeader

                    WeightLineChart(points: points)
                        .frame(height: 200)
                        .padding(14)
                        .background(AGContentColors.card)
                        .clipShape(RoundedRectangle(cornerRadius: 20))

                    tableSection
                }
            }
            .padding(18)
        }
        .background(AGContentColors.background.ignoresSafeArea())
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var summaryHeader: some View {
        let weights = points.compactMap { $0.topWeightKg }
        let first = weights.first ?? 0
        let last = weights.last ?? 0
        let delta = last - first
        return HStack(spacing: 10) {
            WorkoutStat(title: "Текущий", value: weightText(last))
            WorkoutStat(title: "Максимум", value: weightText(weights.max() ?? 0))
            WorkoutStat(
                title: "Изменение",
                value: (delta >= 0 ? "+" : "") + weightText(delta)
            )
        }
    }

    private var tableSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ИСТОРИЯ")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1)
                .foregroundStyle(AGContentColors.secondaryText)

            ForEach(points.reversed()) { point in
                HStack(spacing: 12) {
                    Text(dateText(point.date))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 96, alignment: .leading)

                    Text(weightText(point.topWeightKg ?? 0))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AGContentColors.accent)
                        .frame(width: 70, alignment: .leading)

                    if let reps = point.topReps {
                        Text("× \(reps)")
                            .font(.system(size: 13))
                            .foregroundStyle(AGContentColors.secondaryText)
                    }
                    Spacer()
                    Text(volumeText(point.volume))
                        .font(.system(size: 12))
                        .foregroundStyle(AGContentColors.tertiaryText)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(AGContentColors.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("Недостаточно данных")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Text("Для прогрессии нужны подходы с указанным весом.")
                .font(.system(size: 13))
                .foregroundStyle(AGContentColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let client = try apiConfiguration.makeAPIClient()
            let loaded = try await client.fetchExerciseProgression(exerciseId: exerciseId)
            await MainActor.run { progression = loaded }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func weightText(_ w: Double) -> String {
        if w == w.rounded() { return "\(Int(w)) кг" }
        return String(format: "%.1f кг", w)
    }

    private func volumeText(_ v: Int) -> String {
        if v >= 1000 {
            return String(format: "%.1f т", Double(v) / 1000).replacingOccurrences(of: ".", with: ",")
        }
        return "\(v) кг"
    }

    private func dateText(_ iso: String) -> String {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = parser.date(from: iso)
        if date == nil {
            let fb = ISO8601DateFormatter()
            fb.formatOptions = [.withInternetDateTime]
            date = fb.date(from: iso)
        }
        guard let date else { return iso }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMM"
        return f.string(from: date)
    }
}

// MARK: - Line chart (weight over date), SwiftUI Path

private struct WeightLineChart: View {
    let points: [APIClient.ProgressionPoint]

    var body: some View {
        GeometryReader { geo in
            let weights = points.compactMap { $0.topWeightKg }
            let minW = (weights.min() ?? 0)
            let maxW = (weights.max() ?? 1)
            let range = max(maxW - minW, 1)
            let w = geo.size.width
            let h = geo.size.height
            let padY: CGFloat = 16
            let usableH = h - padY * 2

            let step = points.count > 1 ? w / CGFloat(points.count - 1) : 0

            let pos: (Int) -> CGPoint = { i in
                let value = points[i].topWeightKg ?? minW
                let x = points.count > 1 ? CGFloat(i) * step : w / 2
                let norm = (value - minW) / range
                let y = padY + usableH * (1 - CGFloat(norm))
                return CGPoint(x: x, y: y)
            }

            ZStack(alignment: .topLeading) {
                // Baseline grid.
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h - padY))
                    p.addLine(to: CGPoint(x: w, y: h - padY))
                }
                .stroke(Color.white.opacity(0.08), lineWidth: 1)

                // Filled area.
                Path { p in
                    guard points.count > 0 else { return }
                    p.move(to: CGPoint(x: pos(0).x, y: h - padY))
                    for i in points.indices { p.addLine(to: pos(i)) }
                    p.addLine(to: CGPoint(x: pos(points.count - 1).x, y: h - padY))
                    p.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [AGContentColors.accent.opacity(0.25), AGContentColors.accent.opacity(0.02)],
                        startPoint: .top, endPoint: .bottom
                    )
                )

                // Line.
                Path { p in
                    guard points.count > 0 else { return }
                    p.move(to: pos(0))
                    for i in points.indices { p.addLine(to: pos(i)) }
                }
                .stroke(AGContentColors.accent, style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))

                // Points.
                ForEach(points.indices, id: \.self) { i in
                    Circle()
                        .fill(AGContentColors.accent)
                        .frame(width: 7, height: 7)
                        .position(pos(i))
                }

                // Min/max labels.
                Text("\(Int(maxW)) кг")
                    .font(.system(size: 10))
                    .foregroundStyle(AGContentColors.tertiaryText)
                    .position(x: 24, y: padY)
                Text("\(Int(minW)) кг")
                    .font(.system(size: 10))
                    .foregroundStyle(AGContentColors.tertiaryText)
                    .position(x: 24, y: h - padY - 6)
            }
        }
    }
}
