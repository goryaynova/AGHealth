import SwiftUI

struct HealthMeasurementsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                MeasurementsTodayCard()

                MeasurementsGrid()

                MeasurementsHistoryCard()
            }
            .padding(20)
        }
        .background(
            AGContentColors.background
                .ignoresSafeArea()
        )
        .navigationTitle("Замеры")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MeasurementsTodayCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ПОСЛЕДНИЕ ЗАМЕРЫ")
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

            Text("13 сентября")
                .font(
                    .system(
                        size: 22,
                        weight: .bold
                    )
                )
                .foregroundStyle(.white)
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

struct MeasurementsGrid: View {
    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ],
            spacing: 12
        ) {
            MeasurementCard(
                title: "Вес",
                value: "75,2",
                unit: "кг"
            )

            MeasurementCard(
                title: "Талия",
                value: "82",
                unit: "см"
            )

            MeasurementCard(
                title: "Бёдра",
                value: "98",
                unit: "см"
            )

            MeasurementCard(
                title: "Грудь",
                value: "94",
                unit: "см"
            )

            MeasurementCard(
                title: "Бедро",
                value: "58",
                unit: "см"
            )

            MeasurementCard(
                title: "Плечо",
                value: "31",
                unit: "см"
            )
        }
    }
}

struct MeasurementCard: View {
    let title: String
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(
                    AGContentColors.secondaryText
                )

            HStack(alignment: .bottom, spacing: 4) {
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
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding(16)
        .background(AGContentColors.card)
        .clipShape(
            RoundedRectangle(cornerRadius: 18)
        )
    }
}

struct MeasurementsHistoryCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("ИСТОРИЯ")
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

                Spacer()

                Button {
                    // Добавление замера будет реализовано позже.
                } label: {
                    Image(systemName: "plus")
                        .font(
                            .system(
                                size: 14,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(
                            AGContentColors.accent
                        )
                        .clipShape(Circle())
                }
            }

            MeasurementHistoryRow(
                date: "13 сентября",
                weight: "75,2 кг",
                waist: "82 см"
            )

            MeasurementHistoryRow(
                date: "10 сентября",
                weight: "75,5 кг",
                waist: "82,5 см"
            )

            MeasurementHistoryRow(
                date: "3 сентября",
                weight: "75,8 кг",
                waist: "83 см"
            )
        }
        .padding(18)
        .background(AGContentColors.card)
        .clipShape(
            RoundedRectangle(cornerRadius: 22)
        )
    }
}

struct MeasurementHistoryRow: View {
    let date: String
    let weight: String
    let waist: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(date)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)

                Text("Вес \(weight)")
                    .font(.system(size: 12))
                    .foregroundStyle(
                        AGContentColors.secondaryText
                    )
            }

            Spacer()

            Text(waist)
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
