import SwiftUI

// «Мышечная нагрузка тренировки» — сводка нагрузки именно ЭТОЙ тренировки внутри WorkoutDetailView.
// Данные приходят с бэкенда из ТОГО ЖЕ централизованного muscle-load слоя, что и общая аналитика и
// карта тела (endpoint GET /workouts/:id → muscleLoad). Отдельной логики для WorkoutDetail нет.
//
// Интерактивная: показываются задействованные группы (часть тела), тап раскрывает конкретные мышцы
// с их уровнем (высокая/средняя/низкая). Стиль уровней (цвет/бар) общий с недельной сводкой
// (MuscleLevelStyle), поэтому одна и та же мышца читается одинаково во всех местах.
struct WorkoutMuscleLoadView: View {
    let load: APIClient.WorkoutMuscleLoad

    // Показываем только реально задействованные группы (чтобы сводка тренировки была компактной);
    // если нагрузки нет вообще — блок не рисуем (см. hasAnyLoad ниже на стороне WorkoutDetailView).
    private var workedGroups: [APIClient.MuscleGroupLoad] {
        load.groups.filter { $0.level != "none" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Мышечная нагрузка тренировки")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Text("На какие мышцы повлияла эта тренировка")
                    .font(.system(size: 12))
                    .foregroundStyle(AGContentColors.secondaryText)
            }

            if workedGroups.isEmpty {
                Text("Эта тренировка не дала измеримой нагрузки на мышцы")
                    .font(.system(size: 13))
                    .foregroundStyle(AGContentColors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 6) {
                    ForEach(workedGroups) { group in
                        WorkoutMuscleCategoryRow(group: group)
                    }
                }
            }
        }
        .padding(16)
        .background(AGContentColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// Раскрываемая строка «часть тела → её мышцы», как в недельной сводке, но для одной тренировки.
private struct WorkoutMuscleCategoryRow: View {
    let group: APIClient.MuscleGroupLoad
    @State private var expanded = false

    // Показываем только реально нагруженные мышцы внутри группы.
    private var workedMuscles: [APIClient.MuscleLoad] {
        (group.muscles ?? []).filter { $0.level != "none" }
    }
    private var hasMuscles: Bool { !workedMuscles.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                if hasMuscles {
                    withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AGContentColors.tertiaryText)
                        .opacity(hasMuscles ? 1 : 0)
                        .frame(width: 12)

                    Text(group.label)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 84, alignment: .leading)

                    ProgressBar(
                        progress: MuscleLevelStyle.progress(group.level),
                        color: MuscleLevelStyle.color(group.level)
                    )
                    .frame(height: 7)

                    Text(group.levelRu)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AGContentColors.secondaryText)
                        .frame(width: 62, alignment: .trailing)
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(spacing: 5) {
                    ForEach(workedMuscles) { muscle in
                        HStack(spacing: 12) {
                            Text(muscle.muscle)
                                .font(.system(size: 12))
                                .foregroundStyle(AGContentColors.secondaryText)
                                .frame(width: 118, alignment: .leading)
                                .lineLimit(1)

                            ProgressBar(
                                progress: MuscleLevelStyle.progress(muscle.level),
                                color: MuscleLevelStyle.color(muscle.level)
                            )
                            .frame(height: 5)

                            Text(muscle.levelRu)
                                .font(.system(size: 11))
                                .foregroundStyle(AGContentColors.tertiaryText)
                                .frame(width: 56, alignment: .trailing)
                        }
                    }
                }
                .padding(.leading, 24)
                .padding(.top, 2)
                .padding(.bottom, 6)
            }
        }
    }
}
