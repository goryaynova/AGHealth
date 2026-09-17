import SwiftUI

// Weight detail: a chart of weight over time + latest value + change, from the measurements domain.
// Opened by tapping the «Вес» metric in Health. Read-only here — new weight is added in «Замеры».
struct WeightDetailView: View {
    private let apiConfiguration = APIConfiguration()

    @State private var series: [APIClient.WeightPoint] = []
    @State private var isLoading = true
    @State private var errorText: String?
    @State private var rangeDays: Int? = 90 // nil = all

    private let ranges: [(String, Int?)] = [("1М", 30), ("3М", 90), ("1Г", 365), ("Всё", nil)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isLoading {
                    ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.top, 40)
                } else if let errorText {
                    errorCard(errorText)
                } else if series.isEmpty {
                    emptyCard
                } else {
                    summaryCard
                    rangePicker
                    chartCard
                }
            }
            .padding(20)
        }
        .background(AGContentColors.background.ignoresSafeArea())
        .navigationTitle("Вес")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var summaryCard: some View {
        let latest = series.last
        let first = series.first
        let change = (latest != nil && first != nil) ? latest!.weightKg - first!.weightKg : 0
        return VStack(alignment: .leading, spacing: 8) {
            Text("ТЕКУЩИЙ ВЕС")
                .font(.system(size: 11, weight: .semibold)).tracking(1)
                .foregroundStyle(AGContentColors.secondaryText)
            HStack(alignment: .bottom, spacing: 8) {
                Text(formatKg(latest?.weightKg ?? 0))
                    .font(.system(size: 34, weight: .bold)).foregroundStyle(.white)
                Text("кг").font(.system(size: 15)).foregroundStyle(AGContentColors.secondaryText)
                    .padding(.bottom, 5)
                Spacer()
                if abs(change) >= 0.05 {
                    let up = change > 0
                    Label(
                        "\(up ? "+" : "")\(formatKg(change)) кг",
                        systemImage: up ? "arrow.up.right" : "arrow.down.right"
                    )
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(up ? AGContentColors.orange : AGContentColors.green)
                }
            }
            if let d = latest {
                Text("Последний замер: \(prettyDate(d.measuredAt))")
                    .font(.system(size: 12)).foregroundStyle(AGContentColors.tertiaryText)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AGContentColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var rangePicker: some View {
        HStack(spacing: 8) {
            ForEach(ranges, id: \.0) { label, days in
                Button {
                    rangeDays = days
                    Task { await load() }
                } label: {
                    Text(label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(rangeDays == days ? .white : AGContentColors.secondaryText)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(rangeDays == days ? AGContentColors.accent : AGContentColors.cardSecondary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ДИНАМИКА")
                .font(.system(size: 11, weight: .semibold)).tracking(1)
                .foregroundStyle(AGContentColors.secondaryText)
            WeightHistoryChart(points: series)
                .frame(height: 200)
        }
        .padding(18)
        .background(AGContentColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Нет данных о весе")
                .font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
            Text("Добавьте вес в разделе «Замеры».")
                .font(.system(size: 14)).foregroundStyle(AGContentColors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(AGContentColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private func errorCard(_ text: String) -> some View {
        Text(text).font(.system(size: 14)).foregroundStyle(AGContentColors.secondaryText)
            .padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(AGContentColors.card).clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private func load() async {
        isLoading = true
        errorText = nil
        do {
            let client = try apiConfiguration.makeAPIClient()
            let result = try await client.fetchWeightSeries(days: rangeDays)
            await MainActor.run { series = result.series; isLoading = false }
        } catch {
            await MainActor.run { errorText = error.localizedDescription; isLoading = false }
        }
    }

    private func formatKg(_ v: Double) -> String {
        String(format: "%.1f", v).replacingOccurrences(of: ".", with: ",")
    }

    private func prettyDate(_ iso: String) -> String {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let f2 = ISO8601DateFormatter(); f2.formatOptions = [.withInternetDateTime]
        guard let d = f.date(from: iso) ?? f2.date(from: iso) else { return "" }
        let out = DateFormatter(); out.locale = Locale(identifier: "ru_RU"); out.dateFormat = "d MMMM yyyy"
        return out.string(from: d)
    }
}

// Weight line chart (self-contained; same visual language as the strength progression chart).
struct WeightHistoryChart: View {
    let points: [APIClient.WeightPoint]

    var body: some View {
        GeometryReader { geo in
            let weights = points.map { $0.weightKg }
            let minW = (weights.min() ?? 0)
            let maxW = (weights.max() ?? 1)
            let range = max(maxW - minW, 1)
            let w = geo.size.width
            let h = geo.size.height
            let padY: CGFloat = 18
            let usableH = h - padY * 2
            let step = points.count > 1 ? w / CGFloat(points.count - 1) : 0

            let pos: (Int) -> CGPoint = { i in
                let value = points[i].weightKg
                let x = points.count > 1 ? CGFloat(i) * step : w / 2
                let norm = (value - minW) / range
                let y = padY + usableH * (1 - CGFloat(norm))
                return CGPoint(x: x, y: y)
            }

            ZStack(alignment: .topLeading) {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h - padY))
                    p.addLine(to: CGPoint(x: w, y: h - padY))
                }
                .stroke(Color.white.opacity(0.08), lineWidth: 1)

                if points.count > 0 {
                    Path { p in
                        p.move(to: CGPoint(x: pos(0).x, y: h - padY))
                        for i in points.indices { p.addLine(to: pos(i)) }
                        p.addLine(to: CGPoint(x: pos(points.count - 1).x, y: h - padY))
                        p.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [AGContentColors.accent.opacity(0.25), AGContentColors.accent.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    Path { p in
                        p.move(to: pos(0))
                        for i in points.indices { p.addLine(to: pos(i)) }
                    }
                    .stroke(AGContentColors.accent, style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))

                    ForEach(points.indices, id: \.self) { i in
                        Circle().fill(AGContentColors.accent).frame(width: 6, height: 6).position(pos(i))
                    }
                }

                Text("\(fmt(maxW)) кг")
                    .font(.system(size: 10)).foregroundStyle(AGContentColors.tertiaryText)
                    .position(x: 26, y: padY)
                Text("\(fmt(minW)) кг")
                    .font(.system(size: 10)).foregroundStyle(AGContentColors.tertiaryText)
                    .position(x: 26, y: h - padY - 6)
            }
        }
    }

    private func fmt(_ v: Double) -> String {
        String(format: "%.1f", v).replacingOccurrences(of: ".", with: ",")
    }
}
