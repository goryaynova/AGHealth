import SwiftUI

struct WorkoutsSectionView: View {
    @State private var selectedFilter = "Все"

    private let filters = [
        "Все",
        "Силовые",
        "Бег",
        "Плавание",
        "Велосипед"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Тренировки")
                            .font(
                                .system(
                                    size: 30,
                                    weight: .bold
                                )
                            )
                            .foregroundStyle(.white)

                        Text(
                            "Активность и история тренировок"
                        )
                        .font(.system(size: 15))
                        .foregroundStyle(
                            AGContentColors.secondaryText
                        )
                    }

                    ScrollView(
                        .horizontal,
                        showsIndicators: false
                    ) {
                        HStack(spacing: 8) {
                            ForEach(
                                filters,
                                id: \.self
                            ) { filter in
                                Button {
                                    selectedFilter = filter
                                } label: {
                                    Text(filter)
                                        .font(
                                            .system(
                                                size: 13,
                                                weight: .medium
                                            )
                                        )
                                        .foregroundStyle(
                                            selectedFilter == filter
                                            ? .white
                                            : AGContentColors.secondaryText
                                        )
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 9)
                                        .background(
                                            selectedFilter == filter
                                            ? AGContentColors.accent
                                            : AGContentColors.card
                                        )
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    NavigationLink {
                        WorkoutDetailView()
                    } label: {
                        WorkoutListCard(
                            title: "Силовая тренировка",
                            subtitle: "Сегодня • 58 мин",
                            calories: "420 ккал",
                            icon: "figure.strengthtraining.traditional",
                            color: AGContentColors.accent
                        )
                    }
                    .buttonStyle(.plain)

                    WorkoutListCard(
                        title: "Бег",
                        subtitle: "12 сентября • 18 мин",
                        calories: "150 ккал",
                        icon: "figure.run",
                        color: AGContentColors.green
                    )

                    WorkoutListCard(
                        title: "Плавание",
                        subtitle: "10 сентября • 42 мин",
                        calories: "310 ккал",
                        icon: "figure.pool.swim",
                        color: AGContentColors.accent
                    )
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

struct WorkoutListCard: View {
    let title: String
    let subtitle: String
    let calories: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 19))
                .foregroundStyle(color)
                .frame(width: 46, height: 46)
                .background(
                    color.opacity(0.12)
                )
                .clipShape(
                    RoundedRectangle(cornerRadius: 14)
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

            Text(calories)
                .font(
                    .system(
                        size: 12,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    AGContentColors.secondaryText
                )
        }
        .padding(16)
        .background(
            AGContentColors.card
        )
        .clipShape(
            RoundedRectangle(cornerRadius: 19)
        )
    }
}
