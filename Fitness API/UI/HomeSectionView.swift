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

                    // Сон — отдельный раздел с заголовком (дашборд день/неделя).
                    HomeSectionTitle("Сон")
                    HomeSleepCard()

                    // Месячные — отдельный раздел с заголовком (два дашборда: Месячные через / ПМС).
                    HomeSectionTitle("Месячные")
                    HomeCycleDashboards()

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

// MARK: - Sleep (Home dashboard: last night + week glance)

struct HomeSleepCard: View {
    private let apiConfiguration = APIConfiguration()
    @State private var day: APIClient.SleepDay?
    @State private var week: APIClient.SleepWeek?
    @State private var loaded = false

    var body: some View {
        NavigationLink {
            SleepSectionView()
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Сон", systemImage: "bed.double.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AGContentColors.secondaryText)
                }

                if let day, day.hasData, let session = day.session {
                    HStack(alignment: .bottom, spacing: 8) {
                        Text(sleepDuration(session.asleepSec))
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)
                        Text("прошлой ночью")
                            .font(.system(size: 13))
                            .foregroundStyle(AGContentColors.secondaryText)
                            .padding(.bottom, 4)
                        Spacer()
                        if let rating = day.rating {
                            Text(rating.label)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(sleepRatingColor(rating.key))
                        }
                    }
                    if let segments = session.segments, !segments.isEmpty {
                        HypnogramView(segments: segments).frame(height: 72)
                    }
                    if let week, week.hasData, !week.nights.isEmpty, let avg = week.averages {
                        Text("За неделю в среднем \(sleepShortDuration(avg.asleepSec))")
                            .font(.system(size: 12))
                            .foregroundStyle(AGContentColors.tertiaryText)
                    }
                } else if loaded {
                    Text("Нет данных о сне. Синхронизируйте Apple Health.")
                        .font(.system(size: 13))
                        .foregroundStyle(AGContentColors.secondaryText)
                } else {
                    HStack { Spacer(); ProgressView().tint(.white); Spacer() }.frame(height: 40)
                }
            }
            .padding(18)
            .background(AGContentColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain)
        .task {
            do {
                let client = try apiConfiguration.makeAPIClient()
                async let d = client.fetchSleepDay()
                async let w = client.fetchSleepWeek(days: 7)
                let (dr, wr) = try await (d, w)
                await MainActor.run { day = dr; week = wr; loaded = true }
            } catch {
                print("AGHealth: HomeSleepCard load error = \(error)")
                await MainActor.run { loaded = true }
            }
        }
    }
}

// MARK: - Cycle (Home dashboards: Месячные через X / ПМС). Two separate dashboards, from HealthKit.

struct HomeCycleDashboards: View {
    @State private var analytics: CycleAnalytics?
    @State private var loaded = false

    private let service = HealthKitCycleService()

    var body: some View {
        NavigationLink {
            HealthCycleView()
        } label: {
            VStack(spacing: 12) {
                if let analytics, analytics.predictedNextPeriod != nil {
                    HStack(spacing: 12) {
                        CycleDashboardTile(
                            icon: "drop.fill",
                            tint: AGContentColors.red,
                            title: "Месячные",
                            value: periodValue(analytics),
                            caption: periodCaption(analytics)
                        )
                        CycleDashboardTile(
                            icon: "waveform.path.ecg",
                            tint: AGContentColors.purple,
                            title: "ПМС",
                            value: pmsValue(analytics),
                            caption: pmsCaption(analytics)
                        )
                    }
                } else if loaded {
                    Text("Нет данных цикла. Добавьте месячные в Apple Health.")
                        .font(.system(size: 13))
                        .foregroundStyle(AGContentColors.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                        .background(AGContentColors.card)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                } else {
                    HStack { Spacer(); ProgressView().tint(.white); Spacer() }
                        .frame(height: 60)
                        .background(AGContentColors.card)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                }
            }
        }
        .buttonStyle(.plain)
        .task {
            do {
                let a = try await service.fetchAnalytics()
                await MainActor.run { analytics = a; loaded = true }
            } catch {
                print("AGHealth: HomeCycleDashboards load error = \(error)")
                await MainActor.run { loaded = true }
            }
        }
    }

    // «Месячные через X»
    private func daysUntil(_ date: Date?) -> Int? {
        guard let date else { return nil }
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: date)).day
    }

    private func periodValue(_ a: CycleAnalytics) -> String {
        if a.currentPhase == .menstruation { return "Идут" }
        guard let d = daysUntil(a.predictedNextPeriod) else { return "—" }
        if d <= 0 { return "Сегодня" }
        return "через \(d) \(pluralDays(d))"
    }
    private func periodCaption(_ a: CycleAnalytics) -> String {
        if a.currentPhase == .menstruation { return "Сейчас менструация" }
        if let d = a.currentCycleDay { return "\(d)-й день цикла" }
        return a.currentPhase.title
    }

    // «ПМС идёт / будет через X»
    private func pmsValue(_ a: CycleAnalytics) -> String {
        guard let start = a.predictedPMSStart, let end = a.predictedPMSEnd else { return "—" }
        let today = Calendar.current.startOfDay(for: Date())
        if today >= Calendar.current.startOfDay(for: start) && today <= Calendar.current.startOfDay(for: end) {
            return "Идёт"
        }
        guard let d = daysUntil(start) else { return "—" }
        if d <= 0 { return "Скоро" }
        return "через \(d) \(pluralDays(d))"
    }
    private func pmsCaption(_ a: CycleAnalytics) -> String {
        guard let start = a.predictedPMSStart, let end = a.predictedPMSEnd else { return "Нет прогноза" }
        let today = Calendar.current.startOfDay(for: Date())
        if today >= Calendar.current.startOfDay(for: start) && today <= Calendar.current.startOfDay(for: end) {
            return "Предменструальный период"
        }
        return "Около 5 дней до месячных"
    }

    private func pluralDays(_ n: Int) -> String {
        let a = abs(n) % 100
        let b = a % 10
        if a > 10 && a < 20 { return "дней" }
        if b == 1 { return "день" }
        if b >= 2 && b <= 4 { return "дня" }
        return "дней"
    }
}

struct CycleDashboardTile: View {
    let icon: String
    let tint: Color
    let title: String
    let value: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
            }
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(caption)
                .font(.system(size: 12))
                .foregroundStyle(AGContentColors.secondaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AGContentColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 22))
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
                        "Показатели, анализы и самочувствие"
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

// Small section title for the Home screen, so «Сон» and «Месячные» are visually separate blocks.
struct HomeSectionTitle: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title)
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(AGContentColors.primaryText)
            .padding(.top, 4)
    }
}

// Deterministic recovery score from the backend (sleep + training load). Honest empty state when
// there's no sleep data yet — never shows a fabricated number.
struct RecoveryCard: View {
    private let apiConfiguration = APIConfiguration()
    @State private var recovery: APIClient.Recovery?
    @State private var loaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("ВОССТАНОВЛЕНИЕ")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(AGContentColors.secondaryText)
                Spacer()
            }

            if let recovery, recovery.hasData, let score = recovery.score {
                let color = recoveryColor(recovery.band ?? "")
                HStack(alignment: .bottom) {
                    Text("\(score)")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(.white)
                    Text("/ 100")
                        .font(.system(size: 14))
                        .foregroundStyle(AGContentColors.secondaryText)
                        .padding(.bottom, 7)
                    Spacer()
                    Text(recovery.bandLabel ?? "")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(color)
                }
                ProgressBar(progress: Double(score) / 100.0, color: color)
                Text(recovery.verdict ?? "")
                    .font(.system(size: 13))
                    .foregroundStyle(AGContentColors.secondaryText)
                if let f = recovery.factors {
                    RecoveryFactorsRow(factors: f)
                }
            } else if loaded {
                Text(recovery?.message ?? "Нет данных для расчёта восстановления. Синхронизируйте Apple Health.")
                    .font(.system(size: 14))
                    .foregroundStyle(AGContentColors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack { Spacer(); ProgressView().tint(.white); Spacer() }
                    .frame(height: 60)
            }
        }
        .padding(18)
        .background(AGContentColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .task {
            do {
                let client = try apiConfiguration.makeAPIClient()
                let r = try await client.fetchRecovery()
                await MainActor.run { recovery = r; loaded = true }
            } catch {
                print("AGHealth: RecoveryCard load error = \(error)")
                await MainActor.run { loaded = true }
            }
        }
    }

    private func recoveryColor(_ band: String) -> Color {
        switch band {
        case "excellent": return AGContentColors.green
        case "good": return Color(red: 0.5, green: 0.82, blue: 0.45)
        case "fair": return AGContentColors.orange
        case "low": return AGContentColors.orange
        default: return AGContentColors.red
        }
    }
}

// One-line explanation of what fed the recovery score (transparency: deterministic inputs).
struct RecoveryFactorsRow: View {
    let factors: APIClient.Recovery.Factors
    var body: some View {
        HStack(spacing: 14) {
            if let s = factors.sleep {
                factorChip(icon: "bed.double.fill", text: "Сон \(sleepShortDuration(s.asleepSec))")
            }
            if let l = factors.trainingLoad {
                factorChip(icon: "figure.strengthtraining.traditional",
                           text: l.workouts > 0 ? "Нагрузка 72ч: \(l.workouts)" : "Без нагрузки")
            }
        }
        .padding(.top, 2)
    }
    private func factorChip(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11))
            Text(text).font(.system(size: 12))
        }
        .foregroundStyle(AGContentColors.tertiaryText)
    }
}
