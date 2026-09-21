import SwiftUI

struct HealthSectionView: View {
    var body: some View {
        NavigationStack {
            HealthTabsView()
                .background(
                    AGContentColors.background
                        .ignoresSafeArea()
                )
                .navigationBarHidden(true)
        }
    }
}

// MARK: - Health Tabs

struct HealthTabsView: View {
    @State private var selectedTab = 0

    private let tabs = [
        "Общее",
        "Сон",
        "Цикл",
        "Замеры",
        "Медицина",
        "Стоматология",
        "Косметология"
    ]

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Здоровье")
                    .font(
                        .system(
                            size: 30,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(.white)

                Text(
                    "Показатели, самочувствие и история здоровья"
                )
                .font(.system(size: 15))
                .foregroundStyle(
                    AGContentColors.secondaryText
                )
            }
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            ScrollView(
                .horizontal,
                showsIndicators: false
            ) {
                HStack(spacing: 8) {
                    ForEach(
                        Array(tabs.enumerated()),
                        id: \.offset
                    ) { index, title in
                        Button {
                            selectedTab = index
                        } label: {
                            Text(title)
                                .font(
                                    .system(
                                        size: 13,
                                        weight: .semibold
                                    )
                                )
                                .foregroundStyle(
                                    selectedTab == index
                                    ? .white
                                    : AGContentColors.secondaryText
                                )
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(
                                    selectedTab == index
                                    ? AGContentColors.accent
                                    : AGContentColors.cardSecondary
                                )
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 14)

            TabView(selection: $selectedTab) {
                HealthOverviewTab()
                    .tag(0)

                HealthSleepTab()
                    .tag(1)

                HealthCycleTab()
                    .tag(2)

                HealthMeasurementsTab()
                    .tag(3)

                HealthMedicineTab()
                    .tag(4)

                HealthDentalTab()
                    .tag(5)

                HealthCosmetologyTab()
                    .tag(6)
            }
            .tabViewStyle(
                .page(
                    indexDisplayMode: .never
                )
            )
        }
    }
}

// MARK: - Overview Tab

struct HealthOverviewTab: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HealthStateCard()

                HealthMetricsGrid()

                // Дашборд сна в обзоре Здоровья (ведёт на экран Сон с переключателем дат).
                HomeSleepCard()

                HealthTrendsCard()

                HealthCycleCard()

                HealthMeasurementsCard()
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 32)
        }
        .background(
            AGContentColors.background
                .ignoresSafeArea()
        )
    }
}

// MARK: - Sleep Tab (дубль раздела Сон с переключателем дат, как на главной/экране Сон).

struct HealthSleepTab: View {
    var body: some View {
        SleepSectionView(embedded: true)
    }
}

// MARK: - Cycle Tab

struct HealthCycleTab: View {
    var body: some View {
        HealthCycleView()
    }
}

// MARK: - Measurements Tab

struct HealthMeasurementsTab: View {
    var body: some View {
        HealthMeasurementsView()
    }
}

// MARK: - Medicine Tab

struct HealthMedicineTab: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HealthMedicalSection()
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 32)
        }
        .background(
            AGContentColors.background
                .ignoresSafeArea()
        )
    }
}

// MARK: - Dental Tab

struct HealthDentalTab: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HealthDentalSection()
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 32)
        }
        .background(
            AGContentColors.background
                .ignoresSafeArea()
        )
    }
}

// MARK: - Cosmetology Tab

struct HealthCosmetologyTab: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HealthCosmetologySection()
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 32)
        }
        .background(
            AGContentColors.background
                .ignoresSafeArea()
        )
    }
}

// MARK: - State

struct HealthStateCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("СОСТОЯНИЕ · \(healthTodayText())")
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

            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Всё стабильно")
                        .font(
                            .system(
                                size: 22,
                                weight: .bold
                            )
                        )
                        .foregroundStyle(.white)

                    Text(
                        "Основные показатели без выраженных изменений."
                    )
                    .font(.system(size: 13))
                    .foregroundStyle(
                        AGContentColors.secondaryText
                    )
                }

                Spacer()

                Image(systemName: "checkmark")
                    .font(
                        .system(
                            size: 18,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(
                        AGContentColors.green
                    )
                    .frame(width: 46, height: 46)
                    .background(
                        AGContentColors.green.opacity(0.12)
                    )
                    .clipShape(Circle())
            }
        }
        .padding(18)
        .background(AGContentColors.card)
        .clipShape(
            RoundedRectangle(cornerRadius: 22)
        )
    }
}

// MARK: - Metrics

struct HealthMetricsGrid: View {
    private let apiConfiguration = APIConfiguration()
    private let vitalsService = HealthKitVitalsService()

    @State private var weightKg: Double?
    @State private var sleepText: String?
    @State private var restingHR: Double?
    @State private var hrv: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("ПОКАЗАТЕЛИ")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(AGContentColors.secondaryText)
                Text("Актуальные данные · \(healthTodayText())")
                    .font(.system(size: 11)).foregroundStyle(AGContentColors.tertiaryText)
            }

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 12
            ) {
                HealthMetricCard(
                    title: "Сон",
                    value: sleepText ?? "—",
                    unit: "",
                    icon: "bed.double.fill",
                    color: AGContentColors.purple
                )

                NavigationLink {
                    WeightDetailView()
                } label: {
                    HealthMetricCard(
                        title: "Вес",
                        value: weightKg.map { fmt($0) } ?? "—",
                        unit: weightKg == nil ? "" : "кг",
                        icon: "figure.stand",
                        color: AGContentColors.accent
                    )
                }
                .buttonStyle(.plain)

                HealthMetricCard(
                    title: "Пульс покоя",
                    value: restingHR.map { "\(Int($0.rounded()))" } ?? "—",
                    unit: restingHR == nil ? "" : "уд/мин",
                    icon: "heart.fill",
                    color: AGContentColors.red
                )

                HealthMetricCard(
                    title: "HRV",
                    value: hrv.map { "\(Int($0.rounded()))" } ?? "—",
                    unit: hrv == nil ? "" : "мс",
                    icon: "waveform.path.ecg",
                    color: AGContentColors.green
                )
            }
        }
        .task { await load() }
    }

    private func load() async {
        // Вес и сон — с бэкенда; пульс покоя и HRV — напрямую из Apple Health.
        if let client = try? apiConfiguration.makeAPIClient() {
            if let ms = try? await client.fetchMeasurements() {
                await MainActor.run { weightKg = ms.latest.weightKg?.value }
            }
            if let day = try? await client.fetchSleepDay(), day.hasData, let s = day.session {
                await MainActor.run { sleepText = sleepShortDuration(s.asleepSec) }
            }
        }
        let vitals = await vitalsService.fetchLatest()
        await MainActor.run {
            restingHR = vitals.restingHeartRate
            hrv = vitals.hrvSDNN
        }
    }

    private func fmt(_ v: Double) -> String {
        String(format: "%g", v).replacingOccurrences(of: ".", with: ",")
    }
}

// Дата «сегодня» для подписей дашбордов Здоровья.
func healthTodayText() -> String {
    let f = DateFormatter(); f.locale = Locale(identifier: "ru_RU"); f.dateFormat = "d MMMM, EEEE"
    return f.string(from: Date())
}

struct HealthMetricCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Image(systemName: icon)
                .foregroundStyle(color)

            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(
                    AGContentColors.secondaryText
                )

            HStack(
                alignment: .bottom,
                spacing: 4
            ) {
                Text(value)
                    .font(
                        .system(
                            size: 23,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(.white)

                Text(unit)
                    .font(.system(size: 11))
                    .foregroundStyle(
                        AGContentColors.secondaryText
                    )
                    .padding(.bottom, 3)
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding(16)
        .background(AGContentColors.card)
        .clipShape(
            RoundedRectangle(cornerRadius: 20)
        )
    }
}

// MARK: - Trends

struct HealthTrendsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("ДИНАМИКА · за 7 дней")
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

            HealthTrendRow(
                title: "Вес",
                value: "−0,4 кг",
                positive: true
            )

            HealthTrendRow(
                title: "Пульс покоя",
                value: "стабильно",
                positive: true
            )

            HealthTrendRow(
                title: "HRV",
                value: "+8%",
                positive: true
            )

            HealthTrendRow(
                title: "Сон",
                value: "+32 мин",
                positive: true
            )
        }
        .padding(18)
        .background(AGContentColors.card)
        .clipShape(
            RoundedRectangle(cornerRadius: 22)
        )
    }
}

struct HealthTrendRow: View {
    let title: String
    let value: String
    let positive: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(.white)

            Spacer()

            Text(value)
                .font(
                    .system(
                        size: 14,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    positive
                    ? AGContentColors.green
                    : AGContentColors.secondaryText
                )
        }
    }
}

// MARK: - Cycle

struct HealthCycleCard: View {
    var body: some View {
        NavigationLink {
            HealthCycleView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "calendar")
                    .font(.system(size: 19))
                    .foregroundStyle(
                        AGContentColors.purple
                    )
                    .frame(width: 46, height: 46)
                    .background(
                        AGContentColors.purple.opacity(0.12)
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: 14)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Цикл")
                        .font(
                            .system(
                                size: 16,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(.white)

                    Text(
                        "14 день • фолликулярная фаза"
                    )
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
            .padding(18)
            .background(AGContentColors.card)
            .clipShape(
                RoundedRectangle(cornerRadius: 20)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Measurements

struct HealthMeasurementsCard: View {
    var body: some View {
        NavigationLink {
            HealthMeasurementsView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "ruler")
                    .font(.system(size: 19))
                    .foregroundStyle(
                        AGContentColors.orange
                    )
                    .frame(width: 46, height: 46)
                    .background(
                        AGContentColors.orange.opacity(0.12)
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: 14)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Замеры")
                        .font(
                            .system(
                                size: 16,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(.white)

                    Text(
                        "Вес, талия, бёдра и другие параметры"
                    )
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
            .padding(18)
            .background(AGContentColors.card)
            .clipShape(
                RoundedRectangle(cornerRadius: 20)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Medicine

struct HealthMedicalSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("МЕДИЦИНА")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1)
                .foregroundStyle(AGContentColors.secondaryText)

            NavigationLink { MedicationsView() } label: {
                MedicalActionCard(title: "Лекарства",
                                  subtitle: "График приёма, накопление, добавление",
                                  icon: "pills.fill")
            }.buttonStyle(.plain)

            NavigationLink { AnamnesisView() } label: {
                MedicalActionCard(title: "Анамнез",
                                  subtitle: "Моя медицинская карта",
                                  icon: "person.text.rectangle.fill")
            }.buttonStyle(.plain)

            NavigationLink { VisionView() } label: {
                MedicalActionCard(title: "Зрение",
                                  subtitle: "Значения по глазам и история",
                                  icon: "eye.fill")
            }.buttonStyle(.plain)

            NavigationLink { DoctorVisitsView() } label: {
                MedicalActionCard(title: "Приёмы врачей",
                                  subtitle: "История и план, PDF-вложения",
                                  icon: "stethoscope")
            }.buttonStyle(.plain)
        }
    }
}

struct MedicalActionCard: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17))
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
        .padding(15)
        .background(AGContentColors.card)
        .clipShape(
            RoundedRectangle(cornerRadius: 18)
        )
    }
}

// MARK: - Dental

struct HealthDentalSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("СТОМАТОЛОГИЯ")
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

            NavigationLink {
                DentalView()
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "mouth.fill")
                        .font(.system(size: 17))
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

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Зубы")
                            .font(
                                .system(
                                    size: 15,
                                    weight: .semibold
                                )
                            )
                            .foregroundStyle(.white)

                        Text(
                            "Состояние, лечение и посещения"
                        )
                        .font(.system(size: 12))
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
                .padding(15)
                .background(AGContentColors.card)
                .clipShape(
                    RoundedRectangle(cornerRadius: 18)
                )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Cosmetology

struct HealthCosmetologySection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("КОСМЕТОЛОГИЯ")
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

            NavigationLink {
                CosmetologyView()
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 17))
                        .foregroundStyle(
                            AGContentColors.purple
                        )
                        .frame(width: 42, height: 42)
                        .background(
                            AGContentColors.purple.opacity(0.12)
                        )
                        .clipShape(
                            RoundedRectangle(cornerRadius: 12)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Косметология")
                            .font(
                                .system(
                                    size: 15,
                                    weight: .semibold
                                )
                            )
                            .foregroundStyle(.white)

                        Text(
                            "Процедуры, специалисты и история"
                        )
                        .font(.system(size: 12))
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
                .padding(15)
                .background(AGContentColors.card)
                .clipShape(
                    RoundedRectangle(cornerRadius: 18)
                )
            }
            .buttonStyle(.plain)
        }
    }
}
