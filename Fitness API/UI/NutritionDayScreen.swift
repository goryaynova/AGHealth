import SwiftUI

// Дневной экран питания (промт §7, §10): итоги дня (цель/съедено/осталось/превышение),
// 5 приёмов пищи с продуктами и итогами, кнопка «Добавить еду» → поиск каталога/ручной ввод.

struct NutritionDayScreen: View {
    let date: Date
    @ObservedObject var store: NutritionStore

    @State private var addingMeal: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let msg = store.errorMessage {
                ErrorCard(message: msg)
            }

            if store.isLoadingDay && store.day == nil {
                NutritionLoadingCard()
            } else if let day = store.day {
                NutritionDaySummaryCard(day: day)

                ForEach(day.meals) { meal in
                    NutritionMealCard(
                        meal: meal,
                        onAdd: { addingMeal = meal.mealType },
                        onDelete: { entry in
                            Task { await store.deleteEntry(id: entry.id, date: date) }
                        }
                    )
                }
            } else {
                NutritionLoadingCard()
            }
        }
        .sheet(item: Binding(
            get: { addingMeal.map { MealSelection(mealType: $0) } },
            set: { addingMeal = $0?.mealType }
        )) { selection in
            AddFoodFlowView(date: date, mealType: selection.mealType, store: store)
        }
    }
}

private struct MealSelection: Identifiable {
    let mealType: String
    var id: String { mealType }
}

// Итоги дня: цель / съедено / осталось (или превышение) по КБЖУ (промт §7).
struct NutritionDaySummaryCard: View {
    let day: APIClient.NutritionDay

    private var overKcal: Double { day.over?.kcal ?? 0 }
    private var isOver: Bool { overKcal > 0 }

    private var kcalProgress: Double {
        guard let goal = day.goal, goal.kcal > 0 else { return 0 }
        return min(day.consumed.kcal / goal.kcal, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("КАЛОРИИ")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(AGContentColors.secondaryText)
                    HStack(alignment: .bottom, spacing: 6) {
                        Text(NutritionDateFormat.kcal(day.consumed.kcal))
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white)
                        Text("ккал")
                            .font(.system(size: 14))
                            .foregroundStyle(AGContentColors.secondaryText)
                            .padding(.bottom, 5)
                    }
                }
                Spacer()
                if let goal = day.goal {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Цель").font(.system(size: 12))
                            .foregroundStyle(AGContentColors.secondaryText)
                        Text("\(NutritionDateFormat.kcal(goal.kcal)) ккал")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }

            if day.goal != nil {
                ProgressBar(progress: kcalProgress, color: isOver ? AGContentColors.orange : AGContentColors.green)
                HStack {
                    if isOver {
                        Text("Превышение цели")
                            .font(.system(size: 13))
                            .foregroundStyle(AGContentColors.orange)
                        Spacer()
                        Text("+\(NutritionDateFormat.kcal(overKcal)) ккал")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AGContentColors.orange)
                    } else if let remaining = day.remaining {
                        Text("Осталось на день")
                            .font(.system(size: 13))
                            .foregroundStyle(AGContentColors.secondaryText)
                        Spacer()
                        Text("\(NutritionDateFormat.kcal(remaining.kcal)) ккал")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AGContentColors.green)
                    }
                }
            } else {
                Text("Цель не задана — можно указать в Настройках.")
                    .font(.system(size: 13))
                    .foregroundStyle(AGContentColors.tertiaryText)
            }

            Divider().overlay(AGContentColors.separator)

            HStack(spacing: 10) {
                MacroPill(title: "Белки", value: day.consumed.protein,
                          goal: day.goal?.protein, over: day.over?.protein ?? 0, color: AGContentColors.accent)
                MacroPill(title: "Жиры", value: day.consumed.fat,
                          goal: day.goal?.fat, over: day.over?.fat ?? 0, color: AGContentColors.orange)
                MacroPill(title: "Углеводы", value: day.consumed.carbs,
                          goal: day.goal?.carbs, over: day.over?.carbs ?? 0, color: AGContentColors.purple)
            }
        }
        .padding(18)
        .background(AGContentColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

struct MacroPill: View {
    let title: String
    let value: Double
    let goal: Double?
    let over: Double
    let color: Color

    private var progress: Double {
        guard let goal, goal > 0 else { return 0 }
        return min(value / goal, 1)
    }
    private var isOver: Bool { over > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.system(size: 12))
                .foregroundStyle(AGContentColors.secondaryText)
            Text("\(NutritionDateFormat.grams(value)) г")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
            ProgressBar(progress: progress, color: isOver ? AGContentColors.orange : color, height: 5)
            if let goal {
                Text(isOver ? "+\(NutritionDateFormat.grams(over)) г свыше" : "из \(NutritionDateFormat.grams(goal)) г")
                    .font(.system(size: 10))
                    .foregroundStyle(isOver ? AGContentColors.orange : AGContentColors.tertiaryText)
            } else {
                Text("нет цели").font(.system(size: 10))
                    .foregroundStyle(AGContentColors.tertiaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(AGContentColors.cardSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// Карточка приёма пищи (промт §3): название + продукты + итог + «Добавить еду».
struct NutritionMealCard: View {
    let meal: APIClient.NutritionMeal
    let onAdd: () -> Void
    let onDelete: (APIClient.FoodEntry) -> Void

    private let icons: [String: String] = [
        "breakfast": "sun.max.fill", "snack": "applelogo", "lunch": "fork.knife",
        "afternoon": "cup.and.saucer.fill", "dinner": "moon.fill",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(meal.label, systemImage: icons[meal.mealType] ?? "fork.knife")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(NutritionDateFormat.kcal(meal.total.kcal)) ккал")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(meal.entries.isEmpty ? AGContentColors.tertiaryText : .white)
            }

            if meal.entries.isEmpty {
                Text("Пока пусто")
                    .font(.system(size: 13))
                    .foregroundStyle(AGContentColors.tertiaryText)
            } else {
                VStack(spacing: 0) {
                    ForEach(meal.entries) { entry in
                        NutritionEntryRow(entry: entry, onDelete: { onDelete(entry) })
                        if entry.id != meal.entries.last?.id {
                            Divider().overlay(AGContentColors.separator)
                        }
                    }
                }
                HStack {
                    Text("Б \(NutritionDateFormat.grams(meal.total.protein)) · Ж \(NutritionDateFormat.grams(meal.total.fat)) · У \(NutritionDateFormat.grams(meal.total.carbs))")
                        .font(.system(size: 11))
                        .foregroundStyle(AGContentColors.secondaryText)
                    Spacer()
                }
            }

            Button(action: onAdd) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill").font(.system(size: 14, weight: .semibold))
                    Text("Добавить еду").font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(AGContentColors.accent)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(AGContentColors.accent.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(16)
        .background(AGContentColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct NutritionEntryRow: View {
    let entry: APIClient.FoodEntry
    let onDelete: () -> Void

    private var portion: String {
        if let desc = entry.servingDescription, let qty = entry.servingQty {
            return "\(NutritionDateFormat.grams(qty)) × \(desc) · \(NutritionDateFormat.grams(entry.grams)) г"
        }
        return "\(NutritionDateFormat.grams(entry.grams)) г"
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.food?.name ?? "Продукт")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(portion)
                    .font(.system(size: 12))
                    .foregroundStyle(AGContentColors.secondaryText)
            }
            Spacer()
            Text("\(NutritionDateFormat.kcal(entry.kcal)) ккал")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(AGContentColors.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
    }
}

struct NutritionLoadingCard: View {
    var body: some View {
        HStack {
            Spacer()
            ProgressView().tint(.white)
            Spacer()
        }
        .padding(40)
        .background(AGContentColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}
