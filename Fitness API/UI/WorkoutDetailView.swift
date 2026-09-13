import SwiftUI

struct WorkoutDetailView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Силовая тренировка")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Сегодня • 58 мин • 420 ккал")
                        .font(.system(size: 14))
                        .foregroundStyle(
                            AGContentColors.secondaryText
                        )
                }

                HStack(spacing: 10) {
                    WorkoutStat(
                        title: "Упражнения",
                        value: "6"
                    )

                    WorkoutStat(
                        title: "Подходы",
                        value: "18"
                    )

                    WorkoutStat(
                        title: "Объём",
                        value: "4,2 т"
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("АНАЛИТИКА")
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

                    Text(
                        "Здесь будет динамика нагрузки, объёма и прогресс по упражнениям."
                    )
                    .font(.system(size: 14))
                    .foregroundStyle(
                        AGContentColors.secondaryText
                    )
                    .padding(18)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .background(
                        AGContentColors.card
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: 20)
                    )
                }

                NavigationLink {
                    StrengthWorkoutView(
                        workoutID: "57B9F89A-40D5-4F00-9F44-71ED798A4006"
                    )
                } label: {
                    HStack {
                        Image(systemName: "plus")

                        Text("Добавить упражнение")
                    }
                    .font(
                        .system(
                            size: 15,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        AGContentColors.accent
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: 16)
                    )
                }
            }
            .padding(20)
        }
        .background(
            AGContentColors.background
                .ignoresSafeArea()
        )
        .navigationTitle("Тренировка")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct WorkoutStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(
                    .system(
                        size: 20,
                        weight: .bold
                    )
                )
                .foregroundStyle(.white)

            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(
                    AGContentColors.secondaryText
                )
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding(14)
        .background(
            AGContentColors.card
        )
        .clipShape(
            RoundedRectangle(cornerRadius: 16)
        )
    }
}
