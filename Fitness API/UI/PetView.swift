import SwiftUI

struct PetView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PetProfileCard()

                PetHealthCard()

                PetMedicalCard()

                PetHistoryCard()
            }
            .padding(20)
        }
        .background(
            AGContentColors.background
                .ignoresSafeArea()
        )
        .navigationTitle("Питомец")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PetProfileCard: View {
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        AGContentColors.accent.opacity(0.12)
                    )
                    .frame(width: 64, height: 64)

                Image(systemName: "pawprint.fill")
                    .font(.system(size: 25))
                    .foregroundStyle(
                        AGContentColors.accent
                    )
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Питомец")
                    .font(
                        .system(
                            size: 22,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(.white)

                Text("Собака • 8 лет")
                    .font(.system(size: 14))
                    .foregroundStyle(
                        AGContentColors.secondaryText
                    )
            }

            Spacer()
        }
        .padding(18)
        .background(AGContentColors.card)
        .clipShape(
            RoundedRectangle(cornerRadius: 22)
        )
    }
}

struct PetHealthCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("ЗДОРОВЬЕ")
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

            PetInfoRow(
                title: "Вес",
                value: "24,6 кг"
            )

            PetInfoRow(
                title: "Следующая вакцинация",
                value: "15 октября"
            )

            PetInfoRow(
                title: "Следующий визит",
                value: "20 ноября"
            )
        }
        .padding(18)
        .background(AGContentColors.card)
        .clipShape(
            RoundedRectangle(cornerRadius: 22)
        )
    }
}

struct PetInfoRow: View {
    let title: String
    let value: String

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
                    AGContentColors.secondaryText
                )
        }
    }
}

struct PetMedicalCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("МЕДИЦИНА")
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

            PetActionRow(
                title: "Вакцинации",
                icon: "syringe.fill"
            )

            PetActionRow(
                title: "Лекарства",
                icon: "pills.fill"
            )

            PetActionRow(
                title: "Анализы",
                icon: "cross.case.fill"
            )

            PetActionRow(
                title: "Ветеринар",
                icon: "stethoscope"
            )
        }
        .padding(18)
        .background(AGContentColors.card)
        .clipShape(
            RoundedRectangle(cornerRadius: 22)
        )
    }
}

struct PetActionRow: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(
                    AGContentColors.accent
                )

            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(.white)

            Spacer()

            Image(systemName: "chevron.right")
                .font(
                    .system(
                        size: 11,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    AGContentColors.tertiaryText
                )
        }
    }
}

struct PetHistoryCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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

            PetInfoRow(
                title: "Последний визит",
                value: "20 августа"
            )

            PetInfoRow(
                title: "Последняя вакцинация",
                value: "15 апреля"
            )
        }
        .padding(18)
        .background(AGContentColors.card)
        .clipShape(
            RoundedRectangle(cornerRadius: 22)
        )
    }
}
