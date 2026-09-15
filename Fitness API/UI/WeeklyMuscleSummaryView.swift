import SwiftUI

// "Проработанные мышцы за неделю" block for the Workouts screen. Fetches the backend weekly
// muscle summary (real completed workouts: strength sets + cardio mapping) and renders:
//   1. a body muscle map (front/back) highlighting trained muscles;
//   2. a per-group list with an intensity label + bar.
// It is a self-contained additive block — it does not modify the existing workout list/detail.

struct WeeklyMuscleSummaryView: View {
    var days: Int = 7

    private let apiConfiguration = APIConfiguration()

    @State private var summary: APIClient.MuscleSummary?
    @State private var isLoading = false
    @State private var errorMessage: String?

    // groupKey -> level, for the muscle map.
    private var levels: [String: String] {
        guard let summary else { return [:] }
        var map: [String: String] = [:]
        for g in summary.groups { map[g.groupKey] = g.level }
        return map
    }

    private var hasAnyLoad: Bool {
        guard let summary else { return false }
        return summary.groups.contains { $0.level != "none" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if isLoading && summary == nil {
                loadingState
            } else if let errorMessage, summary == nil {
                errorState(errorMessage)
            } else if let summary {
                content(for: summary)
            }
        }
        .padding(16)
        .background(AGContentColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .task {
            await load()
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Проработанные мышцы за неделю")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Text("Последние \(days) дней • силовые и кардио")
                .font(.system(size: 12))
                .foregroundStyle(AGContentColors.secondaryText)
        }
    }

    @ViewBuilder
    private func content(for summary: APIClient.MuscleSummary) -> some View {
        if hasAnyLoad {
            // Muscle map first, then the per-group breakdown.
            MuscleMapView(levels: levels)
                .padding(.vertical, 4)

            VStack(spacing: 8) {
                ForEach(summary.groups.filter { $0.level != "none" }) { group in
                    MuscleGroupRow(group: group)
                }
            }

            totalsFooter(summary.totals)
        } else {
            emptyState
        }
    }

    private func totalsFooter(_ totals: APIClient.MuscleSummary.Totals) -> some View {
        HStack(spacing: 6) {
            Text("Силовые подходы: \(totals.strengthSets)")
            Text("•").foregroundStyle(AGContentColors.tertiaryText)
            Text("Кардио: \(totals.cardioWorkouts)")
        }
        .font(.system(size: 11))
        .foregroundStyle(AGContentColors.secondaryText)
        .padding(.top, 2)
    }

    private var loadingState: some View {
        HStack {
            Spacer()
            ProgressView().tint(.white).padding(.vertical, 24)
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 26))
                .foregroundStyle(AGContentColors.tertiaryText)
            Text("Нет тренировок за неделю")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
            Text("Завершите тренировку — и мышцы подсветятся здесь")
                .font(.system(size: 12))
                .foregroundStyle(AGContentColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 6) {
            Text("Не удалось загрузить сводку")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(AGContentColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: - Load

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let client = try apiConfiguration.makeAPIClient()
            let loaded = try await client.fetchMuscleSummary(days: days)
            await MainActor.run { summary = loaded }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }
}

// MARK: - One muscle-group row

private struct MuscleGroupRow: View {
    let group: APIClient.MuscleGroupLoad

    private var barColor: Color {
        switch group.level {
        case "high": return AGContentColors.accent
        case "medium": return AGContentColors.accent.opacity(0.7)
        case "low": return AGContentColors.accent.opacity(0.45)
        default: return Color.white.opacity(0.12)
        }
    }

    private var progress: Double {
        switch group.level {
        case "high": return 1.0
        case "medium": return 0.6
        case "low": return 0.3
        default: return 0.0
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(group.label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 92, alignment: .leading)

            ProgressBar(progress: progress, color: barColor)
                .frame(height: 7)

            Text(group.levelRu)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AGContentColors.secondaryText)
                .frame(width: 66, alignment: .trailing)
        }
    }
}
