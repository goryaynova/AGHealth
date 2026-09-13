import SwiftUI

struct DentalView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DentalStatusCard()

                DentalVisitsCard()

                DentalTreatmentCard()
            }
            .padding(20)
        }
        .background(
            AGContentColors.background
                .ignoresSafeArea()
        )
        .navigationTitle("Стоматология")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DentalStatusCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("СОСТОЯНИЕ")
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

            Text("Последний осмотр")
                .font(.system(size: 14))
                .foregroundStyle(
                    AGContentColors.secondaryText
                )

            Text("12 августа 2026")
                .font(
                    .system(
                        size: 21,
                        weight: .bold
                    )
                )
                .foregroundStyle(.white)

            Text("Следующий плановый осмотр — через 5 месяцев")
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

struct DentalVisitsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ПОСЕЩЕНИЯ")
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

            DentalHistoryRow(
                date: "12 августа",
                title: "Плановый осмотр",
                subtitle: "Осмотр и профессиональная гигиена"
            )

            DentalHistoryRow(
                date: "18 мая",
                title: "Лечение",
                subtitle: "Пломба"
            )
        }
        .padding(18)
        .background(AGContentColors.card)
        .clipShape(
            RoundedRectangle(cornerRadius: 22)
        )
    }
}

struct DentalHistoryRow: View {
    let date: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(
                        .system(
                            size: 14,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.white)

                Spacer()

                Text(date)
                    .font(.system(size: 12))
                    .foregroundStyle(
                        AGContentColors.secondaryText
                    )
            }

            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(
                    AGContentColors.secondaryText
                )
        }
    }
}

struct DentalTreatmentCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ЛЕЧЕНИЕ")
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

            DentalToothRow(
                tooth: "36",
                status: "Пломба",
                completed: true
            )

            DentalToothRow(
                tooth: "24",
                status: "Лечение каналов",
                completed: true
            )

            DentalToothRow(
                tooth: "47",
                status: "Наблюдение",
                completed: false
            )
        }
        .padding(18)
        .background(AGContentColors.card)
        .clipShape(
            RoundedRectangle(cornerRadius: 22)
        )
    }
}

struct DentalToothRow: View {
    let tooth: String
    let status: String
    let completed: Bool

    var body: some View {
        HStack {
            Text(tooth)
                .font(
                    .system(
                        size: 15,
                        weight: .bold
                    )
                )
                .foregroundStyle(.white)
                .frame(width: 35)

            Text(status)
                .font(.system(size: 14))
                .foregroundStyle(
                    AGContentColors.secondaryText
                )

            Spacer()

            Image(
                systemName: completed
                ? "checkmark.circle.fill"
                : "clock"
            )
            .foregroundStyle(
                completed
                ? AGContentColors.green
                : AGContentColors.orange
            )
        }
    }
}
