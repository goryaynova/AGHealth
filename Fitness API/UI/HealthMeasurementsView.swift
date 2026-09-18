import SwiftUI

// «Замеры» detail: latest values grid + history, with an add flow that logs weight and body
// circumferences SEPARATELY (any subset per entry). Backed by the measurements domain.
struct HealthMeasurementsView: View {
    private let apiConfiguration = APIConfiguration()

    @State private var data: APIClient.MeasurementsList?
    @State private var isLoading = true
    @State private var errorText: String?
    @State private var showingAdd = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isLoading {
                    ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.top, 40)
                } else if let errorText {
                    errorCard(errorText)
                } else {
                    latestCard
                    grid
                    historyCard
                }
            }
            .padding(20)
        }
        .background(AGContentColors.background.ignoresSafeArea())
        .navigationTitle("Замеры")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(isPresented: $showingAdd) {
            AddMeasurementView { didAdd in
                showingAdd = false
                if didAdd { Task { await load() } }
            }
        }
    }

    private var latest: APIClient.MeasurementsLatest? { data?.latest }

    private var latestCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ПОСЛЕДНИЕ ЗАМЕРЫ")
                .font(.system(size: 11, weight: .semibold)).tracking(1)
                .foregroundStyle(AGContentColors.secondaryText)
            Text(lastDateText)
                .font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(AGContentColors.card).clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var grid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            metricCard("Вес", latest?.weightKg, "кг")
            metricCard("Талия", latest?.waistCm, "см")
            metricCard("Бёдра", latest?.hipsCm, "см")
            metricCard("Грудь", latest?.chestCm, "см")
            metricCard("Бедро", latest?.thighCm, "см")
            metricCard("Плечо", latest?.armCm, "см")
            metricCard("Шея", latest?.neckCm, "см")
            metricCard("Бицепс", latest?.bicepsCm, "см")
        }
    }

    private func metricCard(_ title: String, _ metric: APIClient.MetricLatest?, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 13)).foregroundStyle(AGContentColors.secondaryText)
            HStack(alignment: .bottom, spacing: 4) {
                Text(metric.map { fmt($0.value) } ?? "—")
                    .font(.system(size: 23, weight: .bold)).foregroundStyle(.white)
                Text(unit).font(.system(size: 11)).foregroundStyle(AGContentColors.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16).background(AGContentColors.card).clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("ИСТОРИЯ")
                    .font(.system(size: 11, weight: .semibold)).tracking(1)
                    .foregroundStyle(AGContentColors.secondaryText)
                Spacer()
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                        .frame(width: 32, height: 32).background(AGContentColors.accent).clipShape(Circle())
                }
            }

            if let items = data?.measurements, !items.isEmpty {
                ForEach(items) { m in
                    MeasurementHistoryRow(measurement: m)
                    if m.id != items.last?.id {
                        Divider().overlay(AGContentColors.separator)
                    }
                }
            } else {
                Text("Пока нет записей. Нажмите «+», чтобы добавить вес или замеры.")
                    .font(.system(size: 13)).foregroundStyle(AGContentColors.secondaryText)
            }
        }
        .padding(18).background(AGContentColors.card).clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var lastDateText: String {
        guard let iso = data?.measurements.first?.measuredAt else { return "Нет записей" }
        return prettyDate(iso)
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
            let result = try await client.fetchMeasurements()
            await MainActor.run { data = result; isLoading = false }
        } catch {
            await MainActor.run { errorText = error.localizedDescription; isLoading = false }
        }
    }

    private func fmt(_ v: Double) -> String {
        String(format: "%g", v).replacingOccurrences(of: ".", with: ",")
    }

    private func prettyDate(_ iso: String) -> String {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let f2 = ISO8601DateFormatter(); f2.formatOptions = [.withInternetDateTime]
        guard let d = f.date(from: iso) ?? f2.date(from: iso) else { return iso }
        let out = DateFormatter(); out.locale = Locale(identifier: "ru_RU"); out.dateFormat = "d MMMM"
        return out.string(from: d)
    }
}

struct MeasurementHistoryRow: View {
    let measurement: APIClient.Measurement

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(dateText)
                    .font(.system(size: 14)).foregroundStyle(.white)
                Text(detailsText)
                    .font(.system(size: 12)).foregroundStyle(AGContentColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }

    private var dateText: String {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let f2 = ISO8601DateFormatter(); f2.formatOptions = [.withInternetDateTime]
        guard let d = f.date(from: measurement.measuredAt) ?? f2.date(from: measurement.measuredAt) else { return "" }
        let out = DateFormatter(); out.locale = Locale(identifier: "ru_RU"); out.dateFormat = "d MMMM"
        return out.string(from: d)
    }

    private var detailsText: String {
        var parts: [String] = []
        if let v = measurement.weightKg { parts.append("Вес \(fmt(v)) кг") }
        if let v = measurement.waistCm { parts.append("талия \(fmt(v))") }
        if let v = measurement.hipsCm { parts.append("бёдра \(fmt(v))") }
        if let v = measurement.chestCm { parts.append("грудь \(fmt(v))") }
        if let v = measurement.thighCm { parts.append("бедро \(fmt(v))") }
        if let v = measurement.armCm { parts.append("плечо \(fmt(v))") }
        if let v = measurement.neckCm { parts.append("шея \(fmt(v))") }
        if let v = measurement.bicepsCm { parts.append("бицепс \(fmt(v))") }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }

    private func fmt(_ v: Double) -> String {
        String(format: "%g", v).replacingOccurrences(of: ".", with: ",")
    }
}

// Add sheet: weight and circumferences are entered SEPARATELY (two sections) — the user can log only
// weight, only measurements, or both. At least one field is required.
struct AddMeasurementView: View {
    let onDone: (Bool) -> Void

    private let apiConfiguration = APIConfiguration()

    @State private var mode = 0 // 0 = вес, 1 = замеры
    @State private var date = Date()
    @State private var weight = ""
    @State private var waist = ""
    @State private var hips = ""
    @State private var chest = ""
    @State private var thigh = ""
    @State private var arm = ""
    @State private var neck = ""
    @State private var biceps = ""
    @State private var isSaving = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Что добавить", selection: $mode) {
                        Text("Вес").tag(0)
                        Text("Замеры").tag(1)
                    }
                    .pickerStyle(.segmented)

                    DatePicker("Дата", selection: $date, displayedComponents: .date)
                }

                if mode == 0 {
                    Section("Вес") {
                        numberField("Вес, кг", text: $weight)
                    }
                } else {
                    Section("Замеры, см") {
                        numberField("Талия", text: $waist)
                        numberField("Бёдра", text: $hips)
                        numberField("Грудь", text: $chest)
                        numberField("Бедро", text: $thigh)
                        numberField("Плечо", text: $arm)
                        numberField("Шея", text: $neck)
                        numberField("Бицепс", text: $biceps)
                    }
                }

                if let errorText {
                    Section { Text(errorText).font(.caption).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Добавить")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { onDone(false) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { Task { await save() } }
                        .disabled(isSaving || !hasAnyValue)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func numberField(_ title: String, text: Binding<String>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("—", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
        }
    }

    private var hasAnyValue: Bool {
        if mode == 0 { return parse(weight) != nil }
        return [waist, hips, chest, thigh, arm, neck, biceps].contains { parse($0) != nil }
    }

    private func parse(_ s: String) -> Double? {
        let normalized = s.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        guard !normalized.isEmpty, let v = Double(normalized), v > 0 else { return nil }
        return v
    }

    private func save() async {
        isSaving = true
        errorText = nil
        do {
            let client = try apiConfiguration.makeAPIClient()
            _ = try await client.createMeasurement(
                id: UUID().uuidString.lowercased(),
                measuredAt: date,
                weightKg: mode == 0 ? parse(weight) : nil,
                waistCm: mode == 1 ? parse(waist) : nil,
                hipsCm: mode == 1 ? parse(hips) : nil,
                chestCm: mode == 1 ? parse(chest) : nil,
                thighCm: mode == 1 ? parse(thigh) : nil,
                armCm: mode == 1 ? parse(arm) : nil,
                neckCm: mode == 1 ? parse(neck) : nil,
                bicepsCm: mode == 1 ? parse(biceps) : nil,
                note: nil
            )
            await MainActor.run { isSaving = false; onDone(true) }
        } catch {
            await MainActor.run { isSaving = false; errorText = error.localizedDescription }
        }
    }
}
