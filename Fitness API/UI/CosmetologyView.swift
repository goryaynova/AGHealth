import SwiftUI

struct CosmetologyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CosmetologyNextCard()

                CosmetologyPlanCard()

                CosmetologyHistoryCard()
            }
            .padding(20)
        }
        .background(
            AGContentColors.background
                .ignoresSafeArea()
        )
        .navigationTitle("Косметология")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CosmetologyNextCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("СЛЕДУЮЩАЯ ПРОЦЕДУРА")
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

            Text("20 сентября")
                .font(
                    .system(
                        size: 23,
                        weight: .bold
                    )
                )
                .foregroundStyle(.white)

            Text("Косметологическая процедура")
                .font(.system(size: 14))
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

struct CosmetologyPlanCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ПЛАН")
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

            CosmetologyPlanRow(
                title: "Уход",
                subtitle: "Регулярный уход"
            )

            CosmetologyPlanRow(
                title: "Процедуры",
                subtitle: "По необходимости"
            )

            CosmetologyPlanRow(
                title: "Специалисты",
                subtitle: "История посещений"
            )
        }
        .padding(18)
        .background(AGContentColors.card)
        .clipShape(
            RoundedRectangle(cornerRadius: 22)
        )
    }
}

struct CosmetologyPlanRow: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(
                        .system(
                            size: 14,
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
    }
}

struct CosmetologyHistoryCard: View {
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

            CosmetologyHistoryRow(
                date: "10 сентября",
                title: "Процедура"
            )

            CosmetologyHistoryRow(
                date: "18 августа",
                title: "Процедура"
            )

            CosmetologyHistoryRow(
                date: "22 июля",
                title: "Процедура"
            )
        }
        .padding(18)
        .background(AGContentColors.card)
        .clipShape(
            RoundedRectangle(cornerRadius: 22)
        )
    }
}

struct CosmetologyHistoryRow: View {
    let date: String
    let title: String

    var body: some View {
        HStack {
            Text(date)
                .font(.system(size: 14))
                .foregroundStyle(.white)

            Spacer()

            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(
                    AGContentColors.secondaryText
                )
        }
    }
}
