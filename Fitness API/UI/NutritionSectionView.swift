import SwiftUI

struct NutritionSectionView: View {
    @State private var selectedDate = Date()
    @State private var selectedTab = NutritionTab.day
    @State private var showingImport = false

    enum NutritionTab: String, CaseIterable {
        case day = "День"
        case analytics = "Аналитика"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    NutritionHeader(
                        showingImport: $showingImport
                    )

                    NutritionDateSelector(
                        selectedDate: $selectedDate
                    )

                    Picker(
                        "Раздел",
                        selection: $selectedTab
                    ) {
                        ForEach(
                            NutritionTab.allCases,
                            id: \.self
                        ) { tab in
                            Text(tab.rawValue)
                                .tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)

                    if selectedTab == .day {
                        NutritionDayView(
                            selectedDate: selectedDate
                        )
                    } else {
                        NutritionAnalyticsView()
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
            .sheet(isPresented: $showingImport) {
                NutritionImportView()
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

struct NutritionHeader: View {
    @Binding var showingImport: Bool

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Питание")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)

                Text("Калории, КБЖУ и рацион")
                    .font(.system(size: 15))
                    .foregroundStyle(
                        AGContentColors.secondaryText
                    )
            }

            Spacer()

            Button {
                showingImport = true
            } label: {
                Image(systemName: "arrow.up.doc.fill")
                    .font(
                        .system(
                            size: 16,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(
                        AGContentColors.accent
                    )
                    .clipShape(Circle())
            }
            .accessibilityLabel("Загрузить питание")
        }
    }
}

struct NutritionDateSelector: View {
    @Binding var selectedDate: Date

    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                moveDay(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(
                        .system(
                            size: 13,
                            weight: .semibold
                        )
                    )
                    .frame(width: 34, height: 34)
                    .background(
                        AGContentColors.card
                    )
                    .clipShape(Circle())
            }

            Spacer()

            VStack(spacing: 3) {
                Text(
                    isToday
                    ? "Сегодня"
                    : formattedDate(selectedDate)
                )
                .font(
                    .system(
                        size: 15,
                        weight: .semibold
                    )
                )
                .foregroundStyle(.white)

                Text(formattedWeekday(selectedDate))
                    .font(.system(size: 12))
                    .foregroundStyle(
                        AGContentColors.secondaryText
                    )
            }

            Spacer()

            Button {
                guard !isToday else { return }
                moveDay(1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(
                        .system(
                            size: 13,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        isToday
                        ? AGContentColors.tertiaryText
                        : .white
                    )
                    .frame(width: 34, height: 34)
                    .background(
                        AGContentColors.card
                    )
                    .clipShape(Circle())
            }
            .disabled(isToday)
        }
    }

    private func moveDay(_ value: Int) {
        selectedDate = Calendar.current.date(
            byAdding: .day,
            value: value,
            to: selectedDate
        ) ?? selectedDate
    }
}

struct NutritionDayView: View {
    let selectedDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            NutritionCaloriesCard()
            NutritionMacroCard()
            NutritionMealsCard()
            NutritionWaterCard()
            NutritionStatusCard()
        }
    }
}

struct NutritionCaloriesCard: View {
    private let consumed = 1840.0
    private let target = 2100.0

    private var progress: Double {
        min(consumed / target, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("КАЛОРИИ")
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

                    HStack(
                        alignment: .bottom,
                        spacing: 6
                    ) {
                        Text("1 840")
                            .font(
                                .system(
                                    size: 34,
                                    weight: .bold
                                )
                            )
                            .foregroundStyle(.white)

                        Text("ккал")
                            .font(.system(size: 14))
                            .foregroundStyle(
                                AGContentColors.secondaryText
                            )
                            .padding(.bottom, 5)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Цель")
                        .font(.system(size: 12))
                        .foregroundStyle(
                            AGContentColors.secondaryText
                        )

                    Text("2 100 ккал")
                        .font(
                            .system(
                                size: 14,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(.white)
                }
            }

            ProgressBar(
                progress: progress,
                color: AGContentColors.green
            )

            HStack {
                Text("88% от дневной цели")
                    .font(.system(size: 13))
                    .foregroundStyle(
                        AGContentColors.secondaryText
                    )

                Spacer()

                Text("260 ккал осталось")
                    .font(
                        .system(
                            size: 13,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        AGContentColors.green
                    )
            }
        }
        .padding(18)
        .background(AGContentColors.card)
        .clipShape(
            RoundedRectangle(cornerRadius: 22)
        )
    }
}

struct NutritionMacroCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("КБЖУ")
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

            HStack(spacing: 10) {
                MacroProgressCard(
                    title: "Белки",
                    value: 118,
                    target: 130,
                    unit: "г",
                    color: AGContentColors.accent
                )

                MacroProgressCard(
                    title: "Жиры",
                    value: 62,
                    target: 70,
                    unit: "г",
                    color: AGContentColors.orange
                )

                MacroProgressCard(
                    title: "Углеводы",
                    value: 184,
                    target: 220,
                    unit: "г",
                    color: AGContentColors.purple
                )
            }
        }
    }
}

struct MacroProgressCard: View {
    let title: String
    let value: Double
    let target: Double
    let unit: String
    let color: Color

    private var progress: Double {
        min(value / target, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(
                    AGContentColors.secondaryText
                )

            Text("\(Int(value)) \(unit)")
                .font(
                    .system(
                        size: 17,
                        weight: .bold
                    )
                )
                .foregroundStyle(.white)

            ProgressBar(
                progress: progress,
                color: color,
                height: 5
            )

            Text("из \(Int(target)) \(unit)")
                .font(.system(size: 10))
                .foregroundStyle(
                    AGContentColors.tertiaryText
                )
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding(13)
        .background(AGContentColors.card)
        .clipShape(
            RoundedRectangle(cornerRadius: 16)
        )
    }
}

struct NutritionMealsCard: View {
    private let meals: [NutritionMeal] = [
        NutritionMeal(
            type: "Завтрак",
            time: "08:10",
            calories: 420,
            icon: "sun.max.fill"
        ),
        NutritionMeal(
            type: "Обед",
            time: "13:20",
            calories: 680,
            icon: "fork.knife"
        ),
        NutritionMeal(
            type: "Перекус",
            time: "17:05",
            calories: 210,
            icon: "applelogo"
        ),
        NutritionMeal(
            type: "Ужин",
            time: "20:10",
            calories: 530,
            icon: "moon.fill"
        )
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ПРИЁМЫ ПИЩИ")
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

            VStack(spacing: 0) {
                ForEach(meals) { meal in
                    NutritionMealRow(meal: meal)

                    if meal.id != meals.last?.id {
                        Divider()
                            .overlay(
                                AGContentColors.separator
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(AGContentColors.card)
            .clipShape(
                RoundedRectangle(cornerRadius: 20)
            )
        }
    }
}

struct NutritionMeal: Identifiable {
    let id = UUID()
    let type: String
    let time: String
    let calories: Int
    let icon: String
}

struct NutritionMealRow: View {
    let meal: NutritionMeal

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: meal.icon)
                .font(
                    .system(
                        size: 14,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    AGContentColors.green
                )
                .frame(width: 34, height: 34)
                .background(
                    AGContentColors.green.opacity(0.12)
                )
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(meal.type)
                    .font(
                        .system(
                            size: 15,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(.white)

                Text(meal.time)
                    .font(.system(size: 12))
                    .foregroundStyle(
                        AGContentColors.secondaryText
                    )
            }

            Spacer()

            Text("\(meal.calories) ккал")
                .font(
                    .system(
                        size: 13,
                        weight: .medium
                    )
                )
                .foregroundStyle(.white)
        }
        .padding(.vertical, 14)
    }
}

struct NutritionWaterCard: View {
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        AGContentColors.accent.opacity(0.13)
                    )
                    .frame(width: 46, height: 46)

                Image(systemName: "drop.fill")
                    .foregroundStyle(
                        AGContentColors.accent
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Вода")
                    .font(
                        .system(
                            size: 15,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.white)

                Text("1,6 л из 2,0 л")
                    .font(.system(size: 13))
                    .foregroundStyle(
                        AGContentColors.secondaryText
                    )
            }

            Spacer()

            Text("80%")
                .font(
                    .system(
                        size: 15,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    AGContentColors.accent
                )
        }
        .padding(18)
        .background(AGContentColors.card)
        .clipShape(
            RoundedRectangle(cornerRadius: 20)
        )
    }
}

struct NutritionStatusCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Рацион в пределах цели")
                .font(
                    .system(
                        size: 15,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    AGContentColors.green
                )

            Text(
                "Белка достаточно, калории и остальные макронутриенты находятся в пределах дневных ориентиров."
            )
            .font(.system(size: 13))
            .foregroundStyle(
                AGContentColors.secondaryText
            )
            .fixedSize(
                horizontal: false,
                vertical: true
            )
        }
        .padding(18)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background(
            AGContentColors.green.opacity(0.08)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: 20)
        )
    }
}

struct NutritionAnalyticsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            NutritionAnalyticsCaloriesCard()
            NutritionAnalyticsMacrosCard()
            NutritionAnalyticsInsightCard()
            NutritionAnalyticsHistoryCard()
        }
    }
}

struct NutritionAnalyticsCaloriesCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("СРЕДНИЕ КАЛОРИИ")
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

                HStack(
                    alignment: .bottom,
                    spacing: 7
                ) {
                    Text("2 040")
                        .font(
                            .system(
                                size: 32,
                                weight: .bold
                            )
                        )
                        .foregroundStyle(.white)

                    Text("ккал / день")
                        .font(.system(size: 13))
                        .foregroundStyle(
                            AGContentColors.secondaryText
                        )
                        .padding(.bottom, 4)
                }
            }

            SimpleBarChart(
                values: [
                    0.78,
                    0.92,
                    0.84,
                    0.96,
                    0.88,
                    0.73,
                    0.87
                ],
                labels: [
                    "Пн",
                    "Вт",
                    "Ср",
                    "Чт",
                    "Пт",
                    "Сб",
                    "Вс"
                ]
            )
        }
        .padding(18)
        .background(AGContentColors.card)
        .clipShape(
            RoundedRectangle(cornerRadius: 22)
        )
    }
}

struct NutritionAnalyticsMacrosCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("СРЕДНИЕ КБЖУ")
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

            AnalyticsValueRow(
                title: "Белки",
                value: "124 г",
                subtitle: "95% цели",
                color: AGContentColors.accent
            )

            AnalyticsValueRow(
                title: "Жиры",
                value: "68 г",
                subtitle: "97% цели",
                color: AGContentColors.orange
            )

            AnalyticsValueRow(
                title: "Углеводы",
                value: "201 г",
                subtitle: "91% цели",
                color: AGContentColors.purple
            )
        }
        .padding(18)
        .background(AGContentColors.card)
        .clipShape(
            RoundedRectangle(cornerRadius: 22)
        )
    }
}

struct AnalyticsValueRow: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(.white)

            Spacer()

            Text(value)
                .font(
                    .system(
                        size: 14,
                        weight: .semibold
                    )
                )
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(
                    AGContentColors.secondaryText
                )
                .frame(
                    width: 70,
                    alignment: .trailing
                )
        }
    }
}

struct NutritionAnalyticsInsightCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ДИНАМИКА")
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

            Text("Питание достаточно стабильное")
                .font(
                    .system(
                        size: 17,
                        weight: .semibold
                    )
                )
                .foregroundStyle(.white)

            Text(
                "Средняя калорийность близка к цели, а белок большую часть недели находится на нужном уровне."
            )
            .font(.system(size: 13))
            .foregroundStyle(
                AGContentColors.secondaryText
            )
            .fixedSize(
                horizontal: false,
                vertical: true
            )
        }
        .padding(18)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background(AGContentColors.card)
        .clipShape(
            RoundedRectangle(cornerRadius: 22)
        )
    }
}

struct NutritionAnalyticsHistoryCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ПОСЛЕДНИЕ ДНИ")
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

            AnalyticsHistoryRow(
                day: "Сегодня",
                calories: "1 840",
                target: "2 100"
            )

            AnalyticsHistoryRow(
                day: "Вчера",
                calories: "2 080",
                target: "2 100"
            )

            AnalyticsHistoryRow(
                day: "11 сентября",
                calories: "1 970",
                target: "2 100"
            )

            AnalyticsHistoryRow(
                day: "10 сентября",
                calories: "2 130",
                target: "2 100"
            )
        }
        .padding(18)
        .background(AGContentColors.card)
        .clipShape(
            RoundedRectangle(cornerRadius: 22)
        )
    }
}

struct AnalyticsHistoryRow: View {
    let day: String
    let calories: String
    let target: String

    var body: some View {
        HStack {
            Text(day)
                .font(.system(size: 14))
                .foregroundStyle(.white)

            Spacer()

            Text("\(calories) / \(target)")
                .font(
                    .system(
                        size: 13,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    AGContentColors.secondaryText
                )
        }
    }
}

struct SimpleBarChart: View {
    let values: [Double]
    let labels: [String]

    var body: some View {
        HStack(
            alignment: .bottom,
            spacing: 10
        ) {
            ForEach(
                0..<values.count,
                id: \.self
            ) { index in
                let value = values[index]

                VStack(spacing: 7) {
                    GeometryReader { geometry in
                        VStack {
                            Spacer()

                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    index == values.count - 1
                                    ? AGContentColors.accent
                                    : AGContentColors.accent.opacity(0.35)
                                )
                                .frame(
                                    height: geometry.size.height * value
                                )
                        }
                    }
                    .frame(height: 90)

                    Text(labels[index])
                        .font(.system(size: 10))
                        .foregroundStyle(
                            AGContentColors.secondaryText
                        )
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

struct NutritionImportView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Загрузить питание")
                        .font(
                            .system(
                                size: 27,
                                weight: .bold
                            )
                        )
                        .foregroundStyle(.white)

                    Text(
                        "Позже здесь будет импорт данных из Excel или CSV."
                    )
                    .font(.system(size: 15))
                    .foregroundStyle(
                        AGContentColors.secondaryText
                    )
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
                }

                ImportPlaceholderRow(
                    icon: "tablecells",
                    title: "Excel",
                    subtitle: "Импорт .xlsx"
                )

                ImportPlaceholderRow(
                    icon: "doc.text",
                    title: "CSV",
                    subtitle: "Импорт .csv"
                )

                Spacer()
            }
            .padding(20)
            .background(
                AGContentColors.background
                    .ignoresSafeArea()
            )
            .toolbar {
                ToolbarItem(
                    placement: .topBarTrailing
                ) {
                    Button("Закрыть") {
                        dismiss()
                    }
                    .foregroundStyle(
                        AGContentColors.accent
                    )
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct ImportPlaceholderRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(
                    .system(
                        size: 18,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    AGContentColors.accent
                )
                .frame(width: 42, height: 42)
                .background(
                    AGContentColors.accent.opacity(0.12)
                )
                .clipShape(
                    RoundedRectangle(cornerRadius: 12)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(
                        .system(
                            size: 15,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.white)

                Text(subtitle)
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
                    AGContentColors.tertiaryText
                )
        }
        .padding(16)
        .background(AGContentColors.card)
        .clipShape(
            RoundedRectangle(cornerRadius: 18)
        )
    }
}
