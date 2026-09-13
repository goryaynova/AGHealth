import SwiftUI
import HealthKit

struct HealthCycleView: View {
    @State private var analytics: CycleAnalytics?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    private let service = HealthKitCycleService()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                
                if isLoading {
                    ProgressView()
                        .tint(AGContentColors.purple)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 50)
                    
                } else if let errorMessage {
                    CycleErrorCard(
                        message: errorMessage
                    )
                    
                } else if let analytics {
                    CycleContent(
                        analytics: analytics
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(
            AGContentColors.background
                .ignoresSafeArea()
        )
        .navigationTitle("Цикл")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadCycle()
        }
    }
    
    private func loadCycle() async {
        isLoading = true
        errorMessage = nil
        
        do {
            analytics = try await service.fetchAnalytics()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

// MARK: - Content

struct CycleContent: View {
    let analytics: CycleAnalytics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            CycleOverviewCard(
                analytics: analytics
            )
            
            CycleForecastCard(
                analytics: analytics
            )
            
            CycleAnalyticsCard(
                analytics: analytics
            )
            
            CyclePhasesCard(
                analytics: analytics
            )
            
            CyclePhaseDescriptionCard(
                phase: analytics.currentPhase
            )
            
            CycleHistoryCard(
                analytics: analytics
            )
        }
    }
}

// MARK: - Overview

struct CycleOverviewCard: View {
    let analytics: CycleAnalytics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ТЕКУЩИЙ ЦИКЛ")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(
                            AGContentColors.secondaryText
                        )
                    
                    if let day = analytics.currentCycleDay {
                        HStack(
                            alignment: .firstTextBaseline,
                            spacing: 7
                        ) {
                            Text("\(day)")
                                .font(
                                    .system(
                                        size: 52,
                                        weight: .bold
                                    )
                                )
                                .foregroundStyle(.white)
                            
                            Text("день")
                                .font(.system(size: 16))
                                .foregroundStyle(
                                    AGContentColors.secondaryText
                                )
                        }
                    } else {
                        Text("—")
                            .font(
                                .system(
                                    size: 52,
                                    weight: .bold
                                )
                            )
                            .foregroundStyle(.white)
                    }
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(
                            AGContentColors.purple.opacity(0.14)
                        )
                    
                    Image(systemName: "drop.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(
                            AGContentColors.purple
                        )
                }
                .frame(width: 52, height: 52)
            }
            
            Spacer()
                .frame(height: 22)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Фаза")
                        .font(.system(size: 11))
                        .foregroundStyle(
                            AGContentColors.secondaryText
                        )
                    
                    Text(analytics.currentPhase.title)
                        .font(
                            .system(
                                size: 16,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(.white)
                }
                
                Spacer()
                
                if let average = analytics.averageCycleLength {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Средний цикл")
                            .font(.system(size: 11))
                            .foregroundStyle(
                                AGContentColors.secondaryText
                            )
                        
                        Text("\(Int(average.rounded())) дней")
                            .font(
                                .system(
                                    size: 16,
                                    weight: .semibold
                                )
                            )
                            .foregroundStyle(.white)
                    }
                }
            }
            
            if
                let day = analytics.currentCycleDay,
                let average = analytics.averageCycleLength,
                average > 0
            {
                Spacer()
                    .frame(height: 16)
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.07))
                        
                        Capsule()
                            .fill(AGContentColors.purple)
                            .frame(
                                width: geometry.size.width
                                    * min(
                                        max(
                                            Double(day) / Double(average),
                                            0
                                        ),
                                        1
                                    )
                            )
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [
                    AGContentColors.cardSecondary,
                    AGContentColors.card
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    AGContentColors.purple.opacity(0.16),
                    lineWidth: 1
                )
        )
        .clipShape(
            RoundedRectangle(cornerRadius: 24)
        )
    }
}

// MARK: - Forecast

struct CycleForecastCard: View {
    let analytics: CycleAnalytics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            
            Text("ПРОГНОЗ")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(
                    AGContentColors.secondaryText
                )
            
            HStack(spacing: 10) {
                CycleForecastTile(
                    title: "Менструация",
                    value: formattedForecastDate(
                        analytics.predictedNextPeriod
                    ),
                    subtitle: nextPeriodSubtitle,
                    icon: "drop.fill",
                    color: AGContentColors.red
                )
                
                CycleForecastTile(
                    title: "ПМС",
                    value: formattedPMSRange(
                        start: analytics.predictedPMSStart,
                        end: analytics.predictedPMSEnd
                    ),
                    subtitle: "ориентировочно",
                    icon: "calendar.badge.clock",
                    color: AGContentColors.orange
                )
            }
        }
        .padding(18)
        .background(AGContentColors.card)
        .clipShape(
            RoundedRectangle(cornerRadius: 22)
        )
    }
    
    private var nextPeriodSubtitle: String {
        guard let nextPeriod = analytics.predictedNextPeriod else {
            return "недостаточно данных"
        }
        
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: nextPeriod)
        ).day ?? 0
        
        if days < 0 {
            return "прогноз"
        }
        
        return "через \(days) \(dayWord(days))"
    }
}

struct CycleForecastTile: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.13))
                    
                    Image(systemName: icon)
                        .font(.system(size: 13))
                        .foregroundStyle(color)
                }
                .frame(width: 32, height: 32)
                
                Spacer()
            }
            
            Text(title)
                .font(
                    .system(
                        size: 12,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    AGContentColors.secondaryText
                )
            
            Text(value)
                .font(
                    .system(
                        size: 15,
                        weight: .semibold
                    )
                )
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(
                    AGContentColors.tertiaryText
                )
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding(14)
        .background(
            AGContentColors.cardSecondary
        )
        .clipShape(
            RoundedRectangle(cornerRadius: 17)
        )
    }
}

// MARK: - Analytics

struct CycleAnalyticsCard: View {
    let analytics: CycleAnalytics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            
            Text("АНАЛИТИКА ЗА ГОД")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(
                    AGContentColors.secondaryText
                )
            
            HStack(spacing: 10) {
                CycleAnalyticItem(
                    title: "Средний цикл",
                    value: averageCycleText,
                    icon: "arrow.triangle.2.circlepath"
                )
                
                CycleAnalyticItem(
                    title: "Менструация",
                    value: averagePeriodText,
                    icon: "drop.fill"
                )
            }
            
            HStack(spacing: 10) {
                CycleAnalyticItem(
                    title: "Минимум",
                    value: cycleValue(
                        analytics.shortestCycle
                    ),
                    icon: "arrow.down"
                )
                
                CycleAnalyticItem(
                    title: "Максимум",
                    value: cycleValue(
                        analytics.longestCycle
                    ),
                    icon: "arrow.up"
                )
            }
            
            if
                let shortest = analytics.shortestCycle,
                let longest = analytics.longestCycle
            {
                HStack(spacing: 7) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 12))
                        .foregroundStyle(
                            AGContentColors.purple
                        )
                    
                    Text(
                        "Разброс длины цикла: \(longest - shortest) дней"
                    )
                    .font(.system(size: 12))
                    .foregroundStyle(
                        AGContentColors.secondaryText
                    )
                }
                .padding(.top, 2)
            }
        }
        .padding(18)
        .background(AGContentColors.card)
        .clipShape(
            RoundedRectangle(cornerRadius: 22)
        )
    }
    
    private var averageCycleText: String {
        guard let value = analytics.averageCycleLength else {
            return "—"
        }
        
        return "\(Int(value.rounded())) дн."
    }
    
    private var averagePeriodText: String {
        guard let value = analytics.averagePeriodLength else {
            return "—"
        }
        
        return "\(Int(value.rounded())) дн."
    }
    
    private func cycleValue(_ value: Int?) -> String {
        guard let value else {
            return "—"
        }
        
        return "\(value) дн."
    }
}

struct CycleAnalyticItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        AGContentColors.purple.opacity(0.10)
                    )
                
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(
                        AGContentColors.purple
                    )
            }
            .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(
                        .system(
                            size: 17,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(.white)
                
                Text(title)
                    .font(.system(size: 10))
                    .foregroundStyle(
                        AGContentColors.secondaryText
                    )
                    .lineLimit(1)
            }
            
            Spacer(minLength: 0)
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding(12)
        .background(
            AGContentColors.cardSecondary
        )
        .clipShape(
            RoundedRectangle(cornerRadius: 15)
        )
    }
}

// MARK: - Phases

struct CyclePhasesCard: View {
    let analytics: CycleAnalytics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            
            Text("ФАЗЫ")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(
                    AGContentColors.secondaryText
                )
            
            VStack(spacing: 7) {
                CyclePhaseRow(
                    title: "Менструация",
                    phase: .menstruation,
                    current: analytics.currentPhase
                )
                
                CyclePhaseRow(
                    title: "Фолликулярная",
                    phase: .follicular,
                    current: analytics.currentPhase
                )
                
                CyclePhaseRow(
                    title: "Овуляция",
                    phase: .ovulation,
                    current: analytics.currentPhase
                )
                
                CyclePhaseRow(
                    title: "Лютеиновая",
                    phase: .luteal,
                    current: analytics.currentPhase
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

struct CyclePhaseRow: View {
    let title: String
    let phase: CyclePhase
    let current: CyclePhase
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        phase == current
                        ? AGContentColors.purple.opacity(0.16)
                        : Color.white.opacity(0.04)
                    )
                
                Circle()
                    .fill(
                        phase == current
                        ? AGContentColors.purple
                        : AGContentColors.tertiaryText
                    )
                    .frame(width: 7, height: 7)
            }
            .frame(width: 30, height: 30)
            
            Text(title)
                .font(
                    .system(
                        size: 14,
                        weight: phase == current
                            ? .semibold
                            : .regular
                    )
                )
                .foregroundStyle(
                    phase == current
                    ? .white
                    : AGContentColors.secondaryText
                )
            
            Spacer()
            
            if phase == current {
                Text("Сейчас")
                    .font(
                        .system(
                            size: 11,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        AGContentColors.purple
                    )
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        AGContentColors.purple.opacity(0.10)
                    )
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            phase == current
            ? AGContentColors.purple.opacity(0.055)
            : Color.clear
        )
        .clipShape(
            RoundedRectangle(cornerRadius: 13)
        )
    }
}

// MARK: - Phase Description

struct CyclePhaseDescriptionCard: View {
    let phase: CyclePhase
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            
            HStack(spacing: 11) {
                ZStack {
                    Circle()
                        .fill(
                            AGContentColors.purple.opacity(0.14)
                        )
                    
                    Image(systemName: phaseDescriptionIcon)
                        .font(.system(size: 15))
                        .foregroundStyle(
                            AGContentColors.purple
                        )
                }
                .frame(width: 38, height: 38)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("СЕЙЧАС")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(
                            AGContentColors.secondaryText
                        )
                    
                    Text(phase.title)
                        .font(
                            .system(
                                size: 18,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(.white)
                }
            }
            
            // Рекомендации намеренно идут выше описания,
            // чтобы пользователь видел практическую часть первой.
            VStack(alignment: .leading, spacing: 11) {
                Text("РЕКОМЕНДАЦИИ")
                    .font(
                        .system(
                            size: 10,
                            weight: .bold
                        )
                    )
                    .tracking(1.1)
                    .foregroundStyle(
                        AGContentColors.purple
                    )
                
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(
                        recommendations,
                        id: \.self
                    ) { recommendation in
                        HStack(
                            alignment: .top,
                            spacing: 9
                        ) {
                            Image(systemName: "checkmark")
                                .font(
                                    .system(
                                        size: 9,
                                        weight: .bold
                                    )
                                )
                                .foregroundStyle(
                                    AGContentColors.purple
                                )
                                .frame(
                                    width: 18,
                                    height: 18
                                )
                                .background(
                                    AGContentColors.purple.opacity(0.10)
                                )
                                .clipShape(Circle())
                            
                            Text(recommendation)
                                .font(.system(size: 13))
                                .foregroundStyle(
                                    AGContentColors.secondaryText
                                )
                                .fixedSize(
                                    horizontal: false,
                                    vertical: true
                                )
                        }
                    }
                }
            }
            .padding(14)
            .background(
                AGContentColors.purple.opacity(0.045)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(
                        AGContentColors.purple.opacity(0.10),
                        lineWidth: 1
                    )
            )
            .clipShape(
                RoundedRectangle(cornerRadius: 15)
            )
            
            VStack(alignment: .leading, spacing: 8) {
                Text("ЧТО ПРОИСХОДИТ")
                    .font(
                        .system(
                            size: 10,
                            weight: .bold
                        )
                    )
                    .tracking(1.1)
                    .foregroundStyle(
                        AGContentColors.secondaryText
                    )
                
                Text(phaseDescription)
                    .font(.system(size: 13))
                    .foregroundStyle(
                        AGContentColors.secondaryText
                    )
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
            }
        }
        .padding(18)
        .background(AGContentColors.card)
        .clipShape(
            RoundedRectangle(cornerRadius: 22)
        )
    }
    
    private var phaseDescriptionIcon: String {
        switch phase {
        case .menstruation:
            return "drop.fill"
        case .follicular:
            return "circle.fill"
        case .ovulation:
            return "sparkles"
        case .luteal:
            return "moon.fill"
        case .unknown:
            return "questionmark.circle"
        }
    }
    
    private var phaseDescription: String {
        switch phase {
        case .menstruation:
            return """
            Начинается менструальное кровотечение: уровень эстрогена и прогестерона низкий. Организм избавляется от функционального слоя эндометрия. В первые дни могут быть снижение энергии, сонливость, спазмы и повышенная чувствительность к боли.
            """
            
        case .follicular:
            return """
            После начала менструации постепенно повышается уровень эстрогена. Созревает фолликул, организм готовится к овуляции. У многих в этот период постепенно повышаются энергия, работоспособность и настроение.
            """
            
        case .ovulation:
            return """
            Происходит выброс лютеинизирующего гормона и выход яйцеклетки из доминантного фолликула. Это наиболее фертильное время цикла. У некоторых могут быть кратковременные изменения самочувствия, например лёгкая боль внизу живота или изменение выделений.
            """
            
        case .luteal:
            return """
            После овуляции повышается прогестерон. Организм готовится к возможной имплантации. Во второй половине фазы у некоторых появляются симптомы ПМС: изменения настроения, усталость, нагрубание груди, вздутие, изменения аппетита и сна.
            """
            
        case .unknown:
            return """
            Недостаточно данных для определения особенностей текущей фазы.
            """
        }
    }
    
    private var recommendations: [String] {
        switch phase {
        case .menstruation:
            return [
                "Снизить нагрузку, если самочувствие хуже обычного.",
                "Силовые тренировки можно сохранять при хорошем самочувствии, но ориентироваться на состояние, а не на план любой ценой.",
                "Поддерживать обычное питание и достаточное потребление жидкости.",
                "Обращать внимание на необычно сильную боль, чрезмерное кровотечение или резкое ухудшение самочувствия."
            ]
            
        case .follicular:
            return [
                "Постепенно увеличивать тренировочную нагрузку по самочувствию.",
                "Хороший период для интенсивных тренировок и прогрессии в силовых.",
                "Поддерживать достаточное количество белка, энергии и сна.",
                "Не считать повышение энергии обязательным: индивидуальные ощущения важнее календарной фазы."
            ]
            
        case .ovulation:
            return [
                "Можно использовать хорошее самочувствие для интенсивных тренировок.",
                "Следить за восстановлением и не увеличивать нагрузку только из-за предполагаемой фазы.",
                "Если беременность нежелательна, учитывать, что календарный прогноз овуляции не является надёжным методом контрацепции."
            ]
            
        case .luteal:
            return [
                "Сохранять физическую активность, корректируя интенсивность по самочувствию.",
                "Следить за сном, восстановлением и регулярным питанием.",
                "Не воспринимать небольшое снижение работоспособности как необходимость полностью прекращать тренировки.",
                "Если симптомы ПМС сильно мешают повседневной жизни, стоит обсудить их с врачом."
            ]
            
        case .unknown:
            return [
                "Ориентироваться на самочувствие и данные цикла.",
                "При выраженных или необычных симптомах обратиться к врачу."
            ]
        }
    }
}

// MARK: - History

struct CycleHistoryCard: View {
    let analytics: CycleAnalytics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            
            HStack {
                Text("ИСТОРИЯ")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(
                        AGContentColors.secondaryText
                    )
                
                Spacer()
                
                if !analytics.periods.isEmpty {
                    Text("\(min(analytics.periods.count, 12)) записей")
                        .font(.system(size: 10))
                        .foregroundStyle(
                            AGContentColors.tertiaryText
                        )
                }
            }
            
            if analytics.periods.isEmpty {
                Text("За этот год данных нет.")
                    .font(.system(size: 14))
                    .foregroundStyle(
                        AGContentColors.secondaryText
                    )
            } else {
                VStack(spacing: 0) {
                    ForEach(
                        Array(
                            analytics.periods
                                .reversed()
                                .prefix(12)
                        )
                    ) { period in
                        
                        CycleInfoRow(
                            title: formattedDate(
                                period.startDate
                            ),
                            value: "\(period.durationDays) дн."
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
}

struct CycleInfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        AGContentColors.red.opacity(0.10)
                    )
                
                Image(systemName: "drop.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(
                        AGContentColors.red
                    )
            }
            .frame(width: 28, height: 28)
            
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(.white)
            
            Spacer()
            
            Text(value)
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
        .padding(.vertical, 8)
    }
}

// MARK: - Error

struct CycleErrorCard: View {
    let message: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        AGContentColors.purple.opacity(0.12)
                    )
                
                Image(systemName: "heart.text.square")
                    .font(.system(size: 18))
                    .foregroundStyle(
                        AGContentColors.purple
                    )
            }
            .frame(width: 42, height: 42)
            
            Text("Не удалось загрузить цикл")
                .font(
                    .system(
                        size: 17,
                        weight: .semibold
                    )
                )
                .foregroundStyle(.white)
            
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(
                    AGContentColors.secondaryText
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

// MARK: - Formatting

private func formattedForecastDate(
    _ date: Date?
) -> String {
    guard let date else {
        return "Недостаточно данных"
    }
    
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ru_RU")
    formatter.dateFormat = "d MMMM"
    
    return formatter.string(from: date)
}

private func formattedPMSRange(
    start: Date?,
    end: Date?
) -> String {
    guard
        let start,
        let end
    else {
        return "Недостаточно данных"
    }
    
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ru_RU")
    formatter.dateFormat = "d MMM"
    
    return "\(formatter.string(from: start)) — \(formatter.string(from: end))"
}

private func dayWord(_ days: Int) -> String {
    let value = days % 100
    
    if value >= 11 && value <= 19 {
        return "дней"
    }
    
    switch days % 10 {
    case 1:
        return "день"
    case 2, 3, 4:
        return "дня"
    default:
        return "дней"
    }
}
