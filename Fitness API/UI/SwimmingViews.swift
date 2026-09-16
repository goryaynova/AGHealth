import SwiftUI

// Swimming UI: (1) the per-style breakdown block shown inside a swimming workout's detail, and
// (2) the swimming-progress screen (distance/time over weeks + per-style totals). Both use only the
// real HealthKit-sourced data returned by the backend — nothing is invented.

// MARK: - Per-style breakdown inside a workout detail

struct SwimmingBreakdownSection: View {
    let swimming: APIClient.SwimmingBreakdown

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ПЛАВАНИЕ ПО СТИЛЯМ")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1)
                .foregroundStyle(AGContentColors.secondaryText)

            // Totals row.
            HStack(spacing: 10) {
                if let dist = swimming.totalDistanceM, dist > 0 {
                    WorkoutStat(title: "Всего", value: SwimFormat.distance(dist))
                }
                if let time = swimming.totalDurationSec, time > 0 {
                    WorkoutStat(title: "Время", value: SwimFormat.duration(time))
                }
            }

            VStack(spacing: 8) {
                ForEach(swimming.styles) { style in
                    HStack(spacing: 12) {
                        Text(style.label)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                        Spacer()
                        if let dist = style.distanceM, dist > 0 {
                            Text(SwimFormat.distance(dist))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AGContentColors.accent)
                        }
                        if let time = style.durationSec, time > 0 {
                            Text(SwimFormat.duration(time))
                                .font(.system(size: 13))
                                .foregroundStyle(AGContentColors.secondaryText)
                        }
                    }
                    .padding(12)
                    .background(AGContentColors.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

// MARK: - Swimming progress screen

struct SwimmingProgressView: View {
    private let apiConfiguration = APIConfiguration()

    @State private var progress: APIClient.SwimmingProgress?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if isLoading && progress == nil {
                    HStack { Spacer(); ProgressView().tint(.white).padding(.vertical, 60); Spacer() }
                } else if let errorMessage, progress == nil {
                    ErrorCard(message: errorMessage)
                } else if let progress, !progress.weeks.isEmpty {
                    totals(progress)
                    distanceChart(progress)
                    if !progress.styleTotals.isEmpty {
                        styleTotals(progress)
                    } else {
                        noStyleDataNote
                    }
                } else {
                    emptyState
                }
            }
            .padding(18)
        }
        .background(AGContentColors.background.ignoresSafeArea())
        .navigationTitle("Прогресс плавания")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func totals(_ p: APIClient.SwimmingProgress) -> some View {
        HStack(spacing: 10) {
            WorkoutStat(title: "Дистанция", value: SwimFormat.distance(p.totals.distanceM))
            WorkoutStat(title: "Время", value: SwimFormat.duration(p.totals.durationSec))
            WorkoutStat(title: "Недели", value: "\(p.weeks.count)")
        }
    }

    private func distanceChart(_ p: APIClient.SwimmingProgress) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ДИСТАНЦИЯ ПО НЕДЕЛЯМ")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1)
                .foregroundStyle(AGContentColors.secondaryText)

            let maxDist = p.weeks.map(\.totalDistanceM).max() ?? 1
            VStack(spacing: 8) {
                ForEach(p.weeks) { week in
                    HStack(spacing: 10) {
                        Text(SwimFormat.week(week.week))
                            .font(.system(size: 12))
                            .foregroundStyle(AGContentColors.secondaryText)
                            .frame(width: 64, alignment: .leading)

                        ProgressBar(
                            progress: maxDist > 0 ? week.totalDistanceM / maxDist : 0,
                            color: AGContentColors.accent
                        )
                        .frame(height: 8)

                        Text(SwimFormat.distance(week.totalDistanceM))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 62, alignment: .trailing)
                    }
                }
            }
            .padding(14)
            .background(AGContentColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func styleTotals(_ p: APIClient.SwimmingProgress) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ПО СТИЛЯМ")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1)
                .foregroundStyle(AGContentColors.secondaryText)

            VStack(spacing: 8) {
                ForEach(p.styleTotals) { style in
                    HStack(spacing: 12) {
                        Text(style.label)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                        Spacer()
                        Text(SwimFormat.distance(style.distanceM))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AGContentColors.accent)
                        if style.durationSec > 0 {
                            Text(SwimFormat.duration(style.durationSec))
                                .font(.system(size: 13))
                                .foregroundStyle(AGContentColors.secondaryText)
                        }
                    }
                    .padding(12)
                    .background(AGContentColors.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // Honest note: real swims are shown, but Apple Health did not provide per-stroke styles for them.
    // We never invent styles — so we explain the absence instead of showing fake data.
    private var noStyleDataNote: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundStyle(AGContentColors.secondaryText)
            Text("Apple Health не передал разбивку по стилям для этих заплывов — показаны общая дистанция и время.")
                .font(.system(size: 12))
                .foregroundStyle(AGContentColors.secondaryText)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AGContentColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.pool.swim")
                .font(.system(size: 34))
                .foregroundStyle(AGContentColors.tertiaryText)
            Text("Пока нет заплывов")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Text("Синхронизируйте плавание из Apple Health — прогресс появится здесь.")
                .font(.system(size: 13))
                .foregroundStyle(AGContentColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let client = try apiConfiguration.makeAPIClient()
            let loaded = try await client.fetchSwimmingProgress()
            await MainActor.run { progress = loaded }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }
}

// MARK: - Formatting helpers

enum SwimFormat {
    static func distance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f км", meters / 1000).replacingOccurrences(of: ".", with: ",")
        }
        return "\(Int(meters.rounded())) м"
    }

    static func duration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h) ч \(m) мин" }
        return "\(m) мин"
    }

    /// "2026-W37" → "W37".
    static func week(_ iso: String) -> String {
        if let range = iso.range(of: "W") {
            return String(iso[range.lowerBound...])
        }
        return iso
    }
}
