import SwiftUI

// «Тренировки → Аналитика» — все общие аналитические данные по тренировкам.
// Раньше эти блоки были разбросаны: недельная сводка мышц жила в списке тренировок,
// «Прогрессия веса» и «Прогресс плавания» — в «Ещё → Мои данные». Теперь всё здесь.
//
// Состав:
//   1. Недельная мышечная нагрузка + карта тела (WeeklyMuscleSummaryView).
//   2. Прогресс силовых (ExerciseProgressionView) — по ссылке.
//   3. Плавание (SwimmingProgressView) — по ссылке.
struct WorkoutsAnalyticsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Недельная нагрузка на мышцы + карта тела (интерактивная сводка).
                WeeklyMuscleSummaryView()

                // Прогресс силовых.
                NavigationLink {
                    ExerciseProgressionView()
                        .navigationTitle("Прогресс силовых")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    AnalyticsRow(
                        title: "Прогресс силовых",
                        subtitle: "Рабочие веса по группам мышц и их динамика",
                        systemImage: "chart.line.uptrend.xyaxis"
                    )
                }
                .buttonStyle(.plain)

                // Плавание.
                NavigationLink {
                    SwimmingProgressView()
                        .navigationTitle("Плавание")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    AnalyticsRow(
                        title: "Плавание",
                        subtitle: "Дистанция, время и стили по неделям",
                        systemImage: "figure.pool.swim"
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 2)
            .padding(.bottom, 32)
        }
    }
}

// Строка-навигация в аналитике, в едином чёрно-бело-синем стиле приложения.
private struct AnalyticsRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 19))
                .foregroundStyle(AGContentColors.accent)
                .frame(width: 46, height: 46)
                .background(AGContentColors.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(AGContentColors.secondaryText)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AGContentColors.tertiaryText)
        }
        .padding(16)
        .background(AGContentColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 19))
    }
}
