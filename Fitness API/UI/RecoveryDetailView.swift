import SwiftUI

// Recovery detail: shows the current score, the factors that fed it, and a transparent explanation
// of HOW it's calculated (deterministic, not AI). Opened by tapping the Home «Восстановление» card.
struct RecoveryDetailView: View {
    // Passed in from the Home card (already loaded); re-fetched here to stay fresh.
    let recovery: APIClient.Recovery?

    private let apiConfiguration = APIConfiguration()
    @State private var loaded: APIClient.Recovery?
    @State private var isLoading = false

    private var data: APIClient.Recovery? { loaded ?? recovery }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let r = data, r.hasData, let score = r.score {
                    scoreCard(r, score: score)
                    factorsCard(r)
                    howItWorksCard()
                } else if isLoading {
                    ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.top, 40)
                } else {
                    Text(data?.message ?? "Нет данных для расчёта восстановления.")
                        .font(.system(size: 15))
                        .foregroundStyle(AGContentColors.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                        .background(AGContentColors.card)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                    howItWorksCard()
                }
            }
            .padding(20)
        }
        .background(AGContentColors.background.ignoresSafeArea())
        .navigationTitle("Восстановление")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            isLoading = true
            do {
                let client = try apiConfiguration.makeAPIClient()
                loaded = try await client.fetchRecovery()
            } catch {
                print("AGHealth: RecoveryDetail load error = \(error)")
            }
            isLoading = false
        }
    }

    // MARK: Score

    private func scoreCard(_ r: APIClient.Recovery, score: Int) -> some View {
        let color = bandColor(r.band ?? "")
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom) {
                Text("\(score)")
                    .font(.system(size: 54, weight: .bold))
                    .foregroundStyle(.white)
                Text("/ 100")
                    .font(.system(size: 16))
                    .foregroundStyle(AGContentColors.secondaryText)
                    .padding(.bottom, 9)
                Spacer()
                Text(r.bandLabel ?? "")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
            }
            ProgressBar(progress: Double(score) / 100.0, color: color, height: 9)
            Text(r.verdict ?? "")
                .font(.system(size: 14))
                .foregroundStyle(AGContentColors.secondaryText)
        }
        .padding(18)
        .background(AGContentColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    // MARK: Factors (statistics)

    private func factorsCard(_ r: APIClient.Recovery) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ЧТО ПОВЛИЯЛО")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1)
                .foregroundStyle(AGContentColors.secondaryText)

            if let s = r.factors?.sleep {
                factorRow(
                    icon: "bed.double.fill",
                    tint: AGContentColors.purple,
                    title: "Сон",
                    value: "\(sleepShortDuration(s.asleepSec))" + (s.efficiency != nil ? " · \(Int((s.efficiency! * 100).rounded()))%" : ""),
                    detail: "Вклад в балл: \(s.score)/100 (основной фактор)"
                )
            }
            if let l = r.factors?.trainingLoad {
                factorRow(
                    icon: "figure.strengthtraining.traditional",
                    tint: AGContentColors.accent,
                    title: "Нагрузка (72 ч)",
                    value: l.workouts > 0 ? "\(l.workouts) трен. · \(String(format: "%.1f", l.points)) очк." : "Нет нагрузки",
                    detail: l.penalty > 0 ? "Снижает балл на \(l.penalty)" : "Не снижает балл"
                )
            }
            if let n = r.factors?.nutrition {
                factorRow(
                    icon: "fork.knife",
                    tint: AGContentColors.green,
                    title: "Питание",
                    value: n.available ? "Учитывается" : "Пока не учитывается",
                    detail: n.note
                )
            }
        }
        .padding(18)
        .background(AGContentColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private func factorRow(icon: String, tint: Color, title: String, value: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                Text(value).font(.system(size: 14)).foregroundStyle(AGContentColors.secondaryText)
                Text(detail).font(.system(size: 12)).foregroundStyle(AGContentColors.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }

    // MARK: How it works (explanation)

    private func howItWorksCard() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("КАК СЧИТАЕТСЯ")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1)
                .foregroundStyle(AGContentColors.secondaryText)

            explanationRow("Балл восстановления детерминированный — это фиксированная формула, а не ИИ. Одни и те же данные всегда дают один и тот же результат.")
            explanationRow("Сон — основной фактор: чем дольше и эффективнее сон прошлой ночи, тем выше базовый балл (8 ч ≈ 100, 6 ч ≈ 65, эффективность добавляет/убавляет до ±8).")
            explanationRow("Нагрузка за последние 72 часа снижает балл: чем больше объём силовых и кардио, тем сильнее штраф (до −25).")
            explanationRow("Итог = балл сна − штраф за нагрузку, ограничен диапазоном 0…100. Затем присваивается уровень: 80+ отличное, 65+ хорошее, 50+ среднее, 35+ низкое, ниже — плохое.")
            explanationRow("Питание пока не учитывается — в приложении ещё нет данных о питании. Когда они появятся, они станут дополнительным фактором.")
        }
        .padding(18)
        .background(AGContentColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private func explanationRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(AGContentColors.accent).frame(width: 5, height: 5).padding(.top, 7)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(AGContentColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func bandColor(_ band: String) -> Color {
        switch band {
        case "excellent": return AGContentColors.green
        case "good": return Color(red: 0.5, green: 0.82, blue: 0.45)
        case "fair": return AGContentColors.orange
        case "low": return AGContentColors.orange
        default: return AGContentColors.red
        }
    }
}
