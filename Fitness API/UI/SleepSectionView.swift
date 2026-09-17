import SwiftUI

// Sleep section: Apple-style sleep visualisation.
//  - Day: a hypnogram (stage bands across the night) like Apple Health, + stage breakdown + rating.
//  - Week: a per-night bar chart of asleep duration + averages.
// All data comes from the backend (/api/v1/sleep/day, /week), which is fed by HealthKit sync. Never
// invents data — honest empty states when nothing is synced.

// MARK: - Shared sleep helpers

enum SleepStageStyle {
    // Apple-like palette: awake (orange), REM (light blue), core (blue), deep (indigo).
    static func color(_ stage: String) -> Color {
        switch stage {
        case "awake": return Color(red: 1.0, green: 0.62, blue: 0.22)
        case "rem": return Color(red: 0.36, green: 0.78, blue: 0.98)
        case "core": return Color(red: 0.24, green: 0.52, blue: 0.96)
        case "deep": return Color(red: 0.36, green: 0.30, blue: 0.86)
        case "inbed": return Color.white.opacity(0.25)
        default: return Color(red: 0.30, green: 0.56, blue: 0.94) // generic asleep
        }
    }

    static func label(_ stage: String) -> String {
        switch stage {
        case "awake": return "Бодрствование"
        case "rem": return "Быстрый (REM)"
        case "core": return "Основной"
        case "deep": return "Глубокий"
        case "inbed": return "В постели"
        default: return "Сон"
        }
    }

    // Vertical ordering of the hypnogram lanes (awake on top, deep at the bottom), Apple-style.
    static let laneOrder = ["awake", "rem", "core", "deep", "asleep", "inbed"]
    static func lane(_ stage: String) -> Int {
        laneOrder.firstIndex(of: stage) ?? laneOrder.count - 2
    }
}

func sleepDuration(_ seconds: Int) -> String {
    let h = seconds / 3600
    let m = (seconds % 3600) / 60
    if h == 0 { return "\(m) мин" }
    if m == 0 { return "\(h) ч" }
    return "\(h) ч \(m) мин"
}

func sleepShortDuration(_ seconds: Int) -> String {
    let h = seconds / 3600
    let m = (seconds % 3600) / 60
    return "\(h)ч \(String(format: "%02d", m))м"
}

// MARK: - Section screen

struct SleepSectionView: View {
    private let apiConfiguration = APIConfiguration()

    @State private var day: APIClient.SleepDay?
    @State private var week: APIClient.SleepWeek?
    @State private var isLoading = true
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Сон")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(AGContentColors.primaryText)

                if isLoading {
                    ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.top, 40)
                } else if let errorText {
                    errorCard(errorText)
                } else {
                    lastNightBlock
                    weekBlock
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(AGContentColors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    // MARK: Last night

    @ViewBuilder
    private var lastNightBlock: some View {
        SectionHeader("Прошлая ночь")
        if let day, day.hasData, let session = day.session {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .bottom, spacing: 8) {
                    Text(sleepDuration(session.asleepSec))
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                    if let rating = day.rating {
                        Text(rating.label)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(sleepRatingColor(rating.key))
                            .padding(.bottom, 5)
                    }
                    Spacer()
                    if let eff = session.efficiency {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(Int((eff * 100).rounded()))%")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("эффект.")
                                .font(.system(size: 11))
                                .foregroundStyle(AGContentColors.secondaryText)
                        }
                    }
                }

                if let segments = session.segments, !segments.isEmpty {
                    HypnogramView(segments: segments)
                        .frame(height: 128)
                }

                SleepStageBreakdown(session: session)
            }
            .padding(18)
            .background(AGContentColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 22))
        } else {
            emptyCard("Нет данных о сне. Синхронизируйте Apple Health в «Настройки → Синхронизация».")
        }
    }

    // MARK: Week

    @ViewBuilder
    private var weekBlock: some View {
        SectionHeader("За неделю")
        if let week, week.hasData, !week.nights.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                if let avg = week.averages {
                    HStack(alignment: .bottom, spacing: 8) {
                        Text("\(sleepShortDuration(avg.asleepSec))")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)
                        Text("в среднем")
                            .font(.system(size: 13))
                            .foregroundStyle(AGContentColors.secondaryText)
                            .padding(.bottom, 4)
                        Spacer()
                        if let eff = avg.efficiency {
                            Text("\(Int((eff * 100).rounded()))% эффект.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AGContentColors.secondaryText)
                        }
                    }
                }
                SleepWeekChart(nights: week.nights, goalSec: week.goalSec)
                    .frame(height: 150)
            }
            .padding(18)
            .background(AGContentColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 22))
        } else {
            emptyCard("Пока нет истории сна за неделю.")
        }
    }

    // MARK: Loading

    private func load() async {
        isLoading = true
        errorText = nil
        do {
            let client = try apiConfiguration.makeAPIClient()
            async let d = client.fetchSleepDay()
            async let w = client.fetchSleepWeek(days: 7)
            let (dayResult, weekResult) = try await (d, w)
            await MainActor.run {
                day = dayResult
                week = weekResult
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorText = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func emptyCard(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundStyle(AGContentColors.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(AGContentColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private func errorCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Не удалось загрузить сон", systemImage: "exclamationmark.triangle")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AGContentColors.orange)
            Text(text).font(.system(size: 13)).foregroundStyle(AGContentColors.secondaryText)
        }
        .padding(18)
        .background(AGContentColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

func sleepRatingColor(_ key: String) -> Color {
    switch key {
    case "excellent": return AGContentColors.green
    case "good": return Color(red: 0.5, green: 0.82, blue: 0.45)
    case "fair": return AGContentColors.orange
    default: return AGContentColors.red
    }
}

struct SectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .tracking(1)
            .foregroundStyle(AGContentColors.secondaryText)
    }
}

// MARK: - Hypnogram (Apple-style stage bands across the night)

struct HypnogramView: View {
    let segments: [APIClient.SleepSegment]

    private var parsed: [(stage: String, start: Date, end: Date)] {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime]
        func parse(_ s: String) -> Date? { f.date(from: s) ?? f2.date(from: s) }
        return segments.compactMap { seg in
            guard let s = parse(seg.startedAt), let e = parse(seg.endedAt), e > s else { return nil }
            return (seg.stage, s, e)
        }.sorted { $0.start < $1.start }
    }

    var body: some View {
        GeometryReader { geo in
            let items = parsed
            let lanes = SleepStageStyle.laneOrder.filter { lane in items.contains { $0.stage == lane } }
            let laneCount = max(lanes.count, 1)
            let laneHeight = geo.size.height / CGFloat(laneCount)
            let t0 = items.first?.start ?? Date()
            let t1 = items.last?.end ?? Date()
            let total = max(t1.timeIntervalSince(t0), 1)

            ZStack(alignment: .topLeading) {
                // Lane guide lines.
                ForEach(Array(lanes.enumerated()), id: \.offset) { idx, _ in
                    Rectangle()
                        .fill(Color.white.opacity(0.04))
                        .frame(height: laneHeight - 4)
                        .position(x: geo.size.width / 2, y: laneHeight * CGFloat(idx) + laneHeight / 2)
                }
                // Stage segments as rounded bars in their lane.
                ForEach(Array(items.enumerated()), id: \.offset) { _, seg in
                    let laneIdx = lanes.firstIndex(of: seg.stage) ?? 0
                    let x = geo.size.width * CGFloat(seg.start.timeIntervalSince(t0) / total)
                    let w = max(2, geo.size.width * CGFloat(seg.end.timeIntervalSince(seg.start) / total))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(SleepStageStyle.color(seg.stage))
                        .frame(width: w, height: laneHeight * 0.62)
                        .position(x: x + w / 2, y: laneHeight * CGFloat(laneIdx) + laneHeight / 2)
                }
            }
        }
    }
}

// MARK: - Stage breakdown rows

struct SleepStageBreakdown: View {
    let session: APIClient.SleepSession

    private var rows: [(stage: String, sec: Int)] {
        var out: [(String, Int)] = []
        if let v = session.deepSec { out.append(("deep", v)) }
        if let v = session.coreSec { out.append(("core", v)) }
        if let v = session.remSec { out.append(("rem", v)) }
        if let v = session.awakeSec { out.append(("awake", v)) }
        // Fall back to a single "asleep" row if no stages exist.
        if out.isEmpty { out.append(("asleep", session.asleepSec)) }
        return out
    }

    var body: some View {
        VStack(spacing: 10) {
            ForEach(rows, id: \.stage) { row in
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(SleepStageStyle.color(row.stage))
                        .frame(width: 12, height: 12)
                    Text(SleepStageStyle.label(row.stage))
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(sleepDuration(row.sec))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AGContentColors.secondaryText)
                }
            }
        }
    }
}

// MARK: - Weekly bar chart

struct SleepWeekChart: View {
    let nights: [APIClient.SleepNight]
    let goalSec: Int

    private var maxSec: Int {
        max(nights.map { $0.asleepSec }.max() ?? 1, goalSec)
    }

    var body: some View {
        GeometryReader { geo in
            let maxV = CGFloat(maxSec)
            let count = max(nights.count, 1)
            let spacing: CGFloat = 8
            let barW = (geo.size.width - spacing * CGFloat(count - 1)) / CGFloat(count)
            let chartH = geo.size.height - 22 // leave room for labels
            let goalY = chartH * (1 - CGFloat(goalSec) / maxV)

            ZStack(alignment: .topLeading) {
                // Goal line.
                Path { p in
                    p.move(to: CGPoint(x: 0, y: goalY))
                    p.addLine(to: CGPoint(x: geo.size.width, y: goalY))
                }
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(Color.white.opacity(0.25))

                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(nights) { night in
                        VStack(spacing: 6) {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 5)
                                .fill(barColor(night))
                                .frame(
                                    width: barW,
                                    height: max(3, chartH * CGFloat(night.asleepSec) / maxV)
                                )
                            Text(weekdayShort(night.nightDate))
                                .font(.system(size: 10))
                                .foregroundStyle(AGContentColors.tertiaryText)
                        }
                        .frame(height: geo.size.height, alignment: .bottom)
                    }
                }
            }
        }
    }

    private func barColor(_ night: APIClient.SleepNight) -> Color {
        night.asleepSec >= goalSec ? AGContentColors.green : Color(red: 0.30, green: 0.56, blue: 0.94)
    }

    private func weekdayShort(_ isoDate: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: isoDate) else { return "" }
        let out = DateFormatter()
        out.locale = Locale(identifier: "ru_RU")
        out.dateFormat = "EE"
        return out.string(from: d)
    }
}
