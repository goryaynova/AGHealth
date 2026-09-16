import SwiftUI

// «Прогрессия веса» — weight-over-time for a single exercise (never mixed). First the user sees the
// list of exercises that have history; picking one shows its weight progression line + a table with
// weight/reps/volume per session. Drawn with SwiftUI Path (no third-party chart dependency), matching
// the app's existing no-dependency approach.

struct ExerciseProgressionView: View {
    private let apiConfiguration = APIConfiguration()

    @State private var exercises: [APIClient.ProgressionExercise] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            AGContentColors.background.ignoresSafeArea()

            if isLoading && exercises.isEmpty {
                ProgressView().tint(.white)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if let errorMessage {
                            ErrorCard(message: errorMessage)
                        }

                        if exercises.isEmpty {
                            emptyState
                        } else {
                            Text("Выберите упражнение, чтобы увидеть, как менялся рабочий вес.")
                                .font(.system(size: 13))
                                .foregroundStyle(AGContentColors.secondaryText)

                            ForEach(exercises) { exercise in
                                NavigationLink {
                                    ExerciseProgressionDetailView(
                                        exerciseId: exercise.id,
                                        exerciseName: exercise.name
                                    )
                                } label: {
                                    progressionRow(exercise)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Color.clear.frame(height: 24)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                }
            }
        }
        .navigationTitle("Прогрессия веса")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func progressionRow(_ exercise: APIClient.ProgressionExercise) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AGContentColors.accent.opacity(0.12))
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AGContentColors.accent)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Text("\(exercise.sessions) \(sessionsWord(exercise.sessions))")
                    .font(.system(size: 12))
                    .foregroundStyle(AGContentColors.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AGContentColors.tertiaryText)
        }
        .padding(14)
        .background(AGContentColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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

    private func sessionsWord(_ n: Int) -> String {
        let mod10 = n % 10, mod100 = n % 100
        if mod10 == 1 && mod100 != 11 { return "тренировка" }
        if (2...4).contains(mod10) && !(12...14).contains(mod100) { return "тренировки" }
        return "тренировок"
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
