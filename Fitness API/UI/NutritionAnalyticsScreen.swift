import SwiftUI

// Недельная аналитика питания (промт §11, §13). Основная визуализация — по дню недели два столбика:
// вверх «съедено», вниз «потрачено» (разные цвета). Плюс средние КБЖУ, цель и дни выполнения/превышения.
// «Потрачено» берётся из существующих данных AGHealth (energy burned из workouts) — не второй механизм.

struct NutritionAnalyticsScreen: View {
    let anchorDate: Date
    @ObservedObject var store: NutritionStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let msg = store.errorMessage {
                ErrorCard(message: msg)
            }
            if store.isLoadingWeek && store.week == nil {
                NutritionLoadingCard()
            } else if let week = store.week {
                NutritionWeekChartCard(week: week)
                NutritionWeekAveragesCard(week: week)
                NutritionWeekAdherenceCard(week: week)
            } else {
                NutritionLoadingCard()
            }
        }
    }
}

// График «съедено вверх / потрачено вниз» по дням недели (промт §11).
struct NutritionWeekChartCard: View {
    let week: APIClient.NutritionWeek

    private var maxValue: Double {
        let m = week.days.flatMap { [$0.eatenKcal, $0.burnedKcal] }.max() ?? 0
        return m > 0 ? m : 1
    }

    @State private var selected: APIClient.NutritionWeekDay?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("СЪЕДЕНО / ПОТРАЧЕНО")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(AGContentColors.secondaryText)
                Spacer()
                legendDot(AGContentColors.green, "съедено")
                legendDot(AGContentColors.accent, "потрачено")
            }

            HStack(alignment: .center, spacing: 8) {
                ForEach(week.days) { day in
                    DayUpDownBar(
                        day: day,
                        maxValue: maxValue,
                        isSelected: selected?.id == day.id
                    )
                    .onTapGesture { selected = (selected?.id == day.id) ? nil : day }
                }
            }
            .frame(height: 180)

            if let sel = selected {
                DayDetailRow(day: sel)
            } else {
                Text("Нажмите на день для деталей.")
                    .font(.system(size: 12))
                    .foregroundStyle(AGContentColors.tertiaryText)
            }
        }
        .padding(18)
        .background(AGContentColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).font(.system(size: 11)).foregroundStyle(AGContentColors.secondaryText)
        }
    }
}

// Один день: столбик вверх (съедено) и столбик вниз (потрачено) от общей средней линии.
struct DayUpDownBar: View {
    let day: APIClient.NutritionWeekDay
    let maxValue: Double
    let isSelected: Bool

    private var eatenFrac: Double { min(day.eatenKcal / maxValue, 1) }
    private var burnedFrac: Double { min(day.burnedKcal / maxValue, 1) }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let half = geo.size.height / 2
                VStack(spacing: 0) {
                    // Верх: съедено.
                    VStack {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AGContentColors.green.opacity(isSelected ? 1 : 0.8))
                            .frame(height: max(2, half * eatenFrac))
                    }
                    .frame(height: half)

                    // Ось.
                    Rectangle().fill(AGContentColors.separator).frame(height: 1)

                    // Низ: потрачено.
                    VStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AGContentColors.accent.opacity(isSelected ? 1 : 0.8))
                            .frame(height: max(2, half * burnedFrac))
                        Spacer(minLength: 0)
                    }
                    .frame(height: half)
                }
            }
            Text(weekdayShort(day.date))
                .font(.system(size: 10, weight: isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? .white : AGContentColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private func weekdayShort(_ iso: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: iso) else { return "" }
        let out = DateFormatter()
        out.locale = Locale(identifier: "ru_RU")
        out.dateFormat = "EE"
        return out.string(from: date)
    }
}

struct DayDetailRow: View {
    let day: APIClient.NutritionWeekDay

    private var readableDate: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: day.date) else { return day.date }
        let out = DateFormatter(); out.locale = Locale(identifier: "ru_RU"); out.dateFormat = "d MMMM"
        return out.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(readableDate)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
            HStack {
                metric("Съедено", "\(NutritionDateFormat.kcal(day.eatenKcal)) ккал", AGContentColors.green)
                metric("Потрачено", "\(NutritionDateFormat.kcal(day.burnedKcal)) ккал", AGContentColors.accent)
                metric("Разница", "\(day.diffKcal >= 0 ? "+" : "")\(NutritionDateFormat.kcal(day.diffKcal))", AGContentColors.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AGContentColors.cardSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func metric(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 11)).foregroundStyle(AGContentColors.secondaryText)
            Text(value).font(.system(size: 14, weight: .semibold)).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// Средние КБЖУ за неделю (промт §13).
struct NutritionWeekAveragesCard: View {
    let week: APIClient.NutritionWeek

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("СРЕДНЕЕ ЗА ДЕНЬ")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1)
                .foregroundStyle(AGContentColors.secondaryText)

            HStack(alignment: .bottom, spacing: 7) {
                Text(NutritionDateFormat.kcal(week.averages.kcal))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                Text("ккал / день")
                    .font(.system(size: 13))
                    .foregroundStyle(AGContentColors.secondaryText)
                    .padding(.bottom, 4)
            }

            HStack(spacing: 10) {
                avgChip("Белки", week.averages.protein, AGContentColors.accent)
                avgChip("Жиры", week.averages.fat, AGContentColors.orange)
                avgChip("Углев", week.averages.carbs, AGContentColors.purple)
            }

            if let goal = week.goal {
                Text("Цель: \(NutritionDateFormat.kcal(goal.kcal)) ккал · Б \(NutritionDateFormat.grams(goal.protein)) Ж \(NutritionDateFormat.grams(goal.fat)) У \(NutritionDateFormat.grams(goal.carbs))")
                    .font(.system(size: 12))
                    .foregroundStyle(AGContentColors.tertiaryText)
            }
        }
        .padding(18)
        .background(AGContentColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private func avgChip(_ title: String, _ value: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 12)).foregroundStyle(AGContentColors.secondaryText)
            Text("\(NutritionDateFormat.grams(value)) г")
                .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AGContentColors.cardSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// Выполнение цели: дни в цели / дни с превышением (промт §13).
struct NutritionWeekAdherenceCard: View {
    let week: APIClient.NutritionWeek

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ВЫПОЛНЕНИЕ ЦЕЛИ")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1)
                .foregroundStyle(AGContentColors.secondaryText)

            if week.goal == nil {
                Text("Задайте дневную цель в Настройках, чтобы видеть выполнение.")
                    .font(.system(size: 13))
                    .foregroundStyle(AGContentColors.secondaryText)
            } else {
                HStack(spacing: 10) {
                    adherenceTile("Дней с едой", week.daysWithFood, AGContentColors.secondaryText)
                    adherenceTile("В цели", week.daysGoalMet, AGContentColors.green)
                    adherenceTile("Превышено", week.daysOver, AGContentColors.orange)
                }
            }
        }
        .padding(18)
        .background(AGContentColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private func adherenceTile(_ title: String, _ value: Int, _ color: Color) -> some View {
        VStack(spacing: 6) {
            Text("\(value)").font(.system(size: 26, weight: .bold)).foregroundStyle(color)
            Text(title).font(.system(size: 11)).foregroundStyle(AGContentColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(AGContentColors.cardSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
