import SwiftUI

// Раздел «Лекарства»: список зарегистрированных препаратов (карточки/сводки с графиком приёма и —
// для накапливаемых — накоплено/цель) + добавление нового лекарства.
struct MedicationsView: View {
    private let apiConfiguration = APIConfiguration()

    @State private var meds: [APIClient.Medication] = []
    @State private var isLoading = true
    @State private var errorText: String?
    @State private var showingAdd = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView().tint(.white).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorText {
                Text(errorText).font(.system(size: 14)).foregroundStyle(AGContentColors.secondaryText)
                    .padding(20)
            } else if meds.isEmpty {
                VStack {
                    Text("Пока нет лекарств. Нажмите «+», чтобы добавить.")
                        .font(.system(size: 14)).foregroundStyle(AGContentColors.secondaryText)
                        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                        .background(AGContentColors.card).clipShape(RoundedRectangle(cornerRadius: 22))
                    Spacer()
                }.padding(20)
            } else {
                // List — чтобы работал свайп удаления. Карточки — без разделителей/фона строк.
                List {
                    ForEach(meds) { med in
                        MedicationCard(med: med, onTaken: { Task { await load() } })
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await delete(med) }
                                } label: { Label("Удалить", systemImage: "trash") }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(AGContentColors.background.ignoresSafeArea())
        .navigationTitle("Лекарства")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .task { await load() }
        .sheet(isPresented: $showingAdd) {
            AddMedicationView { added in
                showingAdd = false
                if added { Task { await load() } }
            }
        }
    }

    private func delete(_ med: APIClient.Medication) async {
        do {
            let client = try apiConfiguration.makeAPIClient()
            try await client.archiveMedication(id: med.id)
            await MainActor.run { meds.removeAll { $0.id == med.id } }
        } catch {
            print("AGHealth: delete medication error = \(error)")
        }
    }

    private func load() async {
        isLoading = true; errorText = nil
        do {
            let client = try apiConfiguration.makeAPIClient()
            let list = try await client.fetchMedications()
            await MainActor.run { meds = list; isLoading = false }
        } catch {
            await MainActor.run { errorText = error.localizedDescription; isLoading = false }
        }
    }
}

// Карточка/сводка лекарства: название, дозировка/частота, график приёма за 30 дней и — для
// накапливаемых — прогресс накоплено/цель.
struct MedicationCard: View {
    let med: APIClient.Medication
    var onTaken: (() -> Void)? = nil

    @State private var marking = false
    private let apiConfiguration = APIConfiguration()

    private var takenToday: Bool {
        let today = String(ISO8601DateFormatter().string(from: Date()).prefix(10))
        return (med.intakes ?? []).contains { String($0.takenAt.prefix(10)) == today }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "pills.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(AGContentColors.accent)
                    .frame(width: 38, height: 38)
                    .background(AGContentColors.accent.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 2) {
                    Text(med.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(AGContentColors.secondaryText)
                }
                Spacer()
            }

            if med.isCumulative, let target = med.target, target > 0 {
                let acc = med.accumulated ?? 0
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Накоплено")
                            .font(.system(size: 12)).foregroundStyle(AGContentColors.secondaryText)
                        Spacer()
                        Text("\(fmt(acc)) / \(fmt(target)) \(med.unit ?? "")")
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                    }
                    ProgressBar(progress: min(acc / target, 1), color: AGContentColors.green)
                }
            }

            if let intakes = med.intakes, !intakes.isEmpty {
                Text("График приёма (30 дней)")
                    .font(.system(size: 11, weight: .semibold)).tracking(0.5)
                    .foregroundStyle(AGContentColors.tertiaryText)
                IntakeCalendarStrip(intakeDates: intakeDays(intakes))
                    .frame(height: 26)
            } else {
                Text("Пока нет отметок приёма")
                    .font(.system(size: 12)).foregroundStyle(AGContentColors.tertiaryText)
            }

            // Кнопка отметки / отмены приёма прямо в карточке лекарства.
            if takenToday {
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Принято").font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(AGContentColors.green)
                    .frame(maxWidth: .infinity).frame(height: 40)
                    .background(AGContentColors.green.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button {
                        Task { await undoTaken() }
                    } label: {
                        HStack(spacing: 5) {
                            if marking { ProgressView().tint(.white) }
                            else {
                                Image(systemName: "arrow.uturn.backward").font(.system(size: 12, weight: .bold))
                                Text("Отменить").font(.system(size: 13, weight: .semibold))
                            }
                        }
                        .foregroundStyle(AGContentColors.secondaryText)
                        .padding(.horizontal, 14).frame(height: 40)
                        .background(AGContentColors.cardSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(marking)
                }
            } else {
                Button {
                    Task { await markTaken() }
                } label: {
                    HStack(spacing: 6) {
                        if marking { ProgressView().tint(.white) }
                        else {
                            Image(systemName: "checkmark").font(.system(size: 13, weight: .bold))
                            Text("Отметить приём").font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 40)
                    .background(AGContentColors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(marking)
            }
        }
        .padding(16)
        .background(AGContentColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func markTaken() async {
        marking = true
        do {
            let client = try apiConfiguration.makeAPIClient()
            let dose: Double? = med.isCumulative ? singleDose() : nil
            _ = try await client.recordMedIntake(
                medicationId: med.id,
                id: UUID().uuidString.lowercased(),
                takenAt: Date(),
                amount: dose
            )
            onTaken?()
        } catch {
            print("AGHealth: MedicationCard markTaken error = \(error)")
        }
        marking = false
    }

    private func undoTaken() async {
        marking = true
        do {
            let client = try apiConfiguration.makeAPIClient()
            _ = try await client.undoMedIntake(medicationId: med.id)
            onTaken?()   // перезагрузка списка
        } catch {
            print("AGHealth: MedicationCard undoTaken error = \(error)")
        }
        marking = false
    }

    private func singleDose() -> Double? {
        guard let d = med.dosage else { return nil }
        let normalized = d.replacingOccurrences(of: ",", with: ".")
        let num = normalized.prefix { $0.isNumber || $0 == "." }
        return Double(num)
    }

    private var subtitle: String {
        var parts: [String] = []
        if let d = med.dosage, !d.isEmpty { parts.append(d) }
        if let f = med.frequency, !f.isEmpty { parts.append(f) }
        else { parts.append(med.scheduleKind == "weekly" ? "раз в неделю" : "ежедневно") }
        return parts.joined(separator: " · ")
    }

    private func intakeDays(_ intakes: [APIClient.MedIntake]) -> Set<String> {
        Set(intakes.map { String($0.takenAt.prefix(10)) })
    }

    private func fmt(_ v: Double) -> String {
        String(format: "%g", v).replacingOccurrences(of: ".", with: ",")
    }
}

// Полоска последних 30 дней: закрашенные точки — дни с приёмом.
struct IntakeCalendarStrip: View {
    let intakeDates: Set<String>

    private var days: [String] {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return (0..<30).reversed().map { offset in
            let d = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            return f.string(from: d)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let count = days.count
            let spacing: CGFloat = 3
            let w = (geo.size.width - spacing * CGFloat(count - 1)) / CGFloat(count)
            HStack(spacing: spacing) {
                ForEach(days, id: \.self) { day in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(intakeDates.contains(day) ? AGContentColors.green : Color.white.opacity(0.10))
                        .frame(width: w)
                }
            }
        }
    }
}

// Форма добавления лекарства: название, дозировка, частота, день недели старта, накопление.
struct AddMedicationView: View {
    let onDone: (Bool) -> Void
    private let apiConfiguration = APIConfiguration()

    @State private var name = ""
    @State private var dosage = ""
    @State private var frequency = ""
    @State private var scheduleKind = "daily"
    @State private var startWeekday = 1
    @State private var startDate = Date()
    @State private var isCumulative = false
    @State private var accumulated = ""
    @State private var target = ""
    @State private var unit = "мг"
    @State private var isSaving = false
    @State private var errorText: String?

    private let weekdays = ["Вс", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Препарат") {
                    TextField("Название", text: $name)
                    TextField("Дозировка (напр. 20 мг)", text: $dosage)
                    TextField("Частота (напр. 1 раз в день)", text: $frequency)
                }
                Section("График") {
                    Picker("Частота приёма", selection: $scheduleKind) {
                        Text("Ежедневно").tag("daily")
                        Text("Раз в неделю").tag("weekly")
                    }
                    if scheduleKind == "weekly" {
                        Picker("День недели", selection: $startWeekday) {
                            ForEach(1..<7) { i in Text(fullWeekday(i)).tag(i) }
                            Text(fullWeekday(0)).tag(0)
                        }
                    }
                    DatePicker("Начинать с", selection: $startDate, displayedComponents: .date)
                }
                Section("Накопление") {
                    Toggle("Накапливаемое", isOn: $isCumulative)
                    if isCumulative {
                        HStack { Text("Уже накоплено"); Spacer()
                            TextField("0", text: $accumulated).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 90) }
                        HStack { Text("Цель"); Spacer()
                            TextField("напр. 11250", text: $target).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 90) }
                        HStack { Text("Единицы"); Spacer()
                            TextField("мг", text: $unit).multilineTextAlignment(.trailing).frame(width: 90) }
                    }
                }
                if let errorText {
                    Section { Text(errorText).font(.caption).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Добавить лекарство")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { onDone(false) } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { Task { await save() } }
                        .disabled(isSaving || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func fullWeekday(_ i: Int) -> String {
        ["Воскресенье", "Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота"][i]
    }

    private func parse(_ s: String) -> Double? {
        let n = s.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? nil : Double(n)
    }

    private func save() async {
        isSaving = true; errorText = nil
        do {
            let client = try apiConfiguration.makeAPIClient()
            let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
            _ = try await client.createMedication(
                id: UUID().uuidString.lowercased(),
                name: name.trimmingCharacters(in: .whitespaces),
                dosage: dosage.isEmpty ? nil : dosage,
                frequency: frequency.isEmpty ? nil : frequency,
                scheduleKind: scheduleKind,
                startWeekday: scheduleKind == "weekly" ? startWeekday : nil,
                startDate: f.string(from: startDate),
                isCumulative: isCumulative,
                accumulated: isCumulative ? parse(accumulated) : nil,
                target: isCumulative ? parse(target) : nil,
                unit: isCumulative ? (unit.isEmpty ? nil : unit) : nil
            )
            await MainActor.run { isSaving = false; onDone(true) }
        } catch {
            await MainActor.run { isSaving = false; errorText = error.localizedDescription }
        }
    }
}
