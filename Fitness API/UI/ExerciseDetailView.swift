import SwiftUI

// Exercise detail: shows the exercise's muscle map (primary/secondary) using the SAME mapping the
// weekly analytics use, plus its equipment and a quick link to its weight progression. Opened from
// the «Упражнения» directory.

struct ExerciseDetailView: View {
    let exercise: APIClient.Exercise

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if let muscles = exercise.muscles, !muscles.isEmpty {
                    ExerciseMuscleView(muscles: muscles)
                } else {
                    Text("Для этого упражнения ещё не задана нагрузка на мышцы. Откройте редактирование, чтобы указать основную и дополнительные мышцы.")
                        .font(.system(size: 13))
                        .foregroundStyle(AGContentColors.secondaryText)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AGContentColors.card)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }

                NavigationLink {
                    ExerciseProgressionDetailView(
                        exerciseId: exercise.id,
                        exerciseName: exercise.name
                    )
                } label: {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                        Text("Прогрессия веса")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(AGContentColors.tertiaryText)
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(16)
                    .background(AGContentColors.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
            .padding(18)
        }
        .background(AGContentColors.background.ignoresSafeArea())
        .navigationTitle("Упражнение")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(exercise.name)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)

            if let equipment = exercise.equipment, !equipment.isEmpty {
                Text(equipment)
                    .font(.system(size: 14))
                    .foregroundStyle(AGContentColors.secondaryText)
            }
        }
    }
}
