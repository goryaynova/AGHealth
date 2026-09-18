import SwiftUI
import QuickLook

// Экран просмотра «Мой анамнез»: одна карточка только для чтения + кнопки «Редактировать»
// и «Выгрузить PDF». Редактирование открывается отдельно (sheet).
struct AnamnesisView: View {
    private let apiConfiguration = APIConfiguration()

    @State private var a: APIClient.Anamnesis?
    @State private var weightKg: Double?
    @State private var heightCm: Double?
    @State private var visionText: String?
    @State private var medsById: [String: String] = [:]
    @State private var isLoading = true
    @State private var showingEdit = false
    @State private var pdfURL: URL?
    @State private var buildingPdf = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isLoading {
                    ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.top, 40)
                } else if a == nil {
                    emptyCard
                } else {
                    AnamnesisReadCard(a: a!, weightKg: weightKg, heightCm: heightCm,
                                      visionText: visionText, medsById: medsById)
                    exportButton
                }
            }
            .padding(20)
        }
        .background(AGContentColors.background.ignoresSafeArea())
        .navigationTitle("Анамнез")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(a == nil ? "Заполнить" : "Редактировать") { showingEdit = true }
            }
        }
        .task { await load() }
        .sheet(isPresented: $showingEdit) {
            AnamnesisEditView { saved in
                showingEdit = false
                if saved { Task { await load() } }
            }
        }
        .quickLookPreview($pdfURL)
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Анамнез ещё не заполнен").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
            Text("Нажмите «Заполнить», чтобы создать медицинскую карту.")
                .font(.system(size: 14)).foregroundStyle(AGContentColors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18).background(AGContentColors.card).clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var exportButton: some View {
        Button {
            Task { await exportPdf() }
        } label: {
            HStack(spacing: 8) {
                if buildingPdf { ProgressView().tint(.white) } else { Image(systemName: "square.and.arrow.up") }
                Text("Выгрузить в PDF").font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 48)
            .background(AGContentColors.accent).clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(buildingPdf)
    }

    private func load() async {
        isLoading = true
        do {
            let client = try apiConfiguration.makeAPIClient()
            let an = try await client.fetchAnamnesis()
            if let ms = try? await client.fetchMeasurements() {
                await MainActor.run { weightKg = ms.latest.weightKg?.value; heightCm = ms.latest.heightCm?.value }
            }
            if let medsList = try? await client.fetchMedications() {
                await MainActor.run { medsById = Dictionary(uniqueKeysWithValues: medsList.map { ($0.id, $0.name) }) }
            }
            if let v = try? await client.fetchVision(), let latest = v.latest {
                await MainActor.run {
                    let r = latest.rightEye.map { String(format: "%g", $0) } ?? "—"
                    let l = latest.leftEye.map { String(format: "%g", $0) } ?? "—"
                    visionText = "Правый \(r) · Левый \(l)"
                }
            }
            await MainActor.run { a = an; isLoading = false }
        } catch {
            print("AGHealth: AnamnesisView(read) load error = \(error)")
            await MainActor.run { isLoading = false }
        }
    }

    private func exportPdf() async {
        guard let a else { return }
        buildingPdf = true
        let url = AnamnesisPDF.build(a: a, weightKg: weightKg, heightCm: heightCm,
                                     visionText: visionText, medsById: medsById)
        await MainActor.run { pdfURL = url; buildingPdf = false }
    }
}

// Карточка просмотра анамнеза (только чтение).
struct AnamnesisReadCard: View {
    let a: APIClient.Anamnesis
    let weightKg: Double?
    let heightCm: Double?
    let visionText: String?
    let medsById: [String: String]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            group("Общее") {
                row("ФИО", a.fullName)
                row("Пол", a.sex)
                row("Возраст", a.age.map { "\($0)" })
            }
            group("Кровь") {
                row("Группа крови", [a.bloodGroup, a.rhFactor].compactMap { $0 }.joined(separator: " "))
                row("ВИЧ/СПИД", a.hivStatus)
            }
            group("Тело") {
                row("Вес", weightKg.map { "\(fmt($0)) кг" })
                row("Рост", heightCm.map { "\(fmt($0)) см" })
                row("Зрение", visionText)
            }
            group("Образ жизни") {
                row("Активность", a.lifestyle)
                row("Вредные привычки", habitsText)
            }
            if let chronic = a.chronic, !chronic.isEmpty {
                group("Хронические заболевания") {
                    ForEach(Array(chronic.enumerated()), id: \.offset) { _, c in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                            if let d = c.date, !d.isEmpty { subline("С \(d)") }
                            if let t = c.treatment, !t.isEmpty { subline(t) }
                            if let mid = c.medicationId, let name = medsById[mid] { subline("Препарат: \(name)") }
                        }
                    }
                }
            }
            if let sports = a.sports, !sports.isEmpty {
                group("Спорт") { subline(sports.joined(separator: ", ")) }
            }
            if let surgeries = a.surgeries, !surgeries.isEmpty {
                group("Перенесённые операции") {
                    ForEach(Array(surgeries.enumerated()), id: \.offset) { _, s in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                            if let d = s.date, !d.isEmpty { subline(d) }
                            if let ds = s.description, !ds.isEmpty { subline(ds) }
                        }
                    }
                }
            }
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(AGContentColors.card).clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var habitsText: String? {
        guard let h = a.habits else { return nil }
        var parts: [String] = []
        if h.alcohol == true { parts.append("алкоголь") }
        if h.smoking == true { parts.append("курение") }
        if h.drugs == true { parts.append("наркотики") }
        return parts.isEmpty ? "нет" : parts.joined(separator: ", ")
    }

    @ViewBuilder
    private func group<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(.system(size: 11, weight: .semibold)).tracking(1)
                .foregroundStyle(AGContentColors.secondaryText)
            content()
        }
    }
    @ViewBuilder
    private func row(_ title: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            HStack { Text(title).font(.system(size: 14)).foregroundStyle(AGContentColors.secondaryText)
                Spacer(); Text(value).font(.system(size: 14)).foregroundStyle(.white) }
        }
    }
    private func subline(_ t: String) -> some View {
        Text(t).font(.system(size: 13)).foregroundStyle(AGContentColors.secondaryText)
    }
    private func fmt(_ v: Double) -> String { String(format: "%g", v).replacingOccurrences(of: ".", with: ",") }
}

// Форма редактирования анамнеза (открывается по кнопке из карточки просмотра). Вес/рост
// подтягиваются из «Замеров», зрение — из «Зрения»; хронические болезни можно пролинковать с
// лекарством из раздела «Лекарства».
struct AnamnesisEditView: View {
    let onDone: (Bool) -> Void
    private let apiConfiguration = APIConfiguration()

    @State private var a = APIClient.Anamnesis(
        fullName: nil, sex: nil, age: nil, bloodGroup: nil, rhFactor: nil, hivStatus: nil,
        lifestyle: nil, habits: APIClient.Habits(alcohol: false, smoking: false, drugs: false),
        chronic: [], sports: [], surgeries: []
    )
    @State private var meds: [APIClient.Medication] = []
    @State private var weightKg: Double?
    @State private var heightCm: Double?
    @State private var visionText: String?
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var savedNote: String?

    var body: some View {
      NavigationStack {
        Form {
            Section("Общее") {
                textRow("ФИО", text: bindStr(\.fullName))
                Picker("Пол", selection: bindStrPicker(\.sex)) {
                    Text("—").tag(""); Text("жен").tag("жен"); Text("муж").tag("муж")
                }
                HStack { Text("Возраст"); Spacer()
                    TextField("—", text: bindInt(\.age)).keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 80) }
            }

            Section("Кровь") {
                Picker("Группа крови", selection: bindStrPicker(\.bloodGroup)) {
                    Text("—").tag(""); Text("I").tag("I"); Text("II").tag("II"); Text("III").tag("III"); Text("IV").tag("IV")
                }
                Picker("Резус", selection: bindStrPicker(\.rhFactor)) {
                    Text("—").tag(""); Text("+").tag("+"); Text("−").tag("−")
                }
                Picker("ВИЧ/СПИД", selection: bindStrPicker(\.hivStatus)) {
                    Text("—").tag(""); Text("отрицательный").tag("отрицательный"); Text("положительный").tag("положительный")
                }
            }

            Section("Тело (из «Замеров»)") {
                infoRow("Вес", weightKg.map { "\(fmt($0)) кг" } ?? "нет данных")
                infoRow("Рост", heightCm.map { "\(fmt($0)) см" } ?? "нет данных — добавьте в «Замеры»")
            }

            Section("Зрение (из раздела «Зрение»)") {
                infoRow("Последнее", visionText ?? "нет данных")
            }

            Section("Образ жизни") {
                Picker("Активность", selection: bindStrPicker(\.lifestyle)) {
                    Text("—").tag(""); Text("активный").tag("активный"); Text("сидячий").tag("сидячий")
                }
                Toggle("Алкоголь", isOn: bindHabit(\.alcohol))
                Toggle("Курение", isOn: bindHabit(\.smoking))
                Toggle("Наркотики", isOn: bindHabit(\.drugs))
            }

            chronicSection
            sportsSection
            surgeriesSection

            if let savedNote {
                Section { Text(savedNote).font(.caption).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Редактирование")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Отмена") { onDone(false) } }
            ToolbarItem(placement: .confirmationAction) {
                Button(isSaving ? "Сохранение…" : "Сохранить") { Task { await save() } }.disabled(isSaving)
            }
        }
        .task { await load() }
      }
      .preferredColorScheme(.dark)
    }

    // MARK: Chronic

    private var chronicSection: some View {
        Section("Хронические заболевания") {
            ForEach(Array((a.chronic ?? []).enumerated()), id: \.offset) { idx, _ in
                VStack(alignment: .leading, spacing: 6) {
                    TextField("Название", text: chronicBind(idx, \.name))
                    TextField("Дата начала лечения", text: chronicBindOpt(idx, \.date))
                    TextField("Описание лечения", text: chronicBindOpt(idx, \.treatment))
                    Picker("Препарат", selection: chronicMedBind(idx)) {
                        Text("— не выбран").tag("")
                        ForEach(meds) { m in Text(m.name).tag(m.id) }
                    }
                }
                .padding(.vertical, 4)
            }
            .onDelete { offsets in a.chronic?.remove(atOffsets: offsets) }
            Button {
                a.chronic = (a.chronic ?? []) + [APIClient.ChronicItem(name: "", date: nil, treatment: nil, medicationId: nil)]
            } label: { Label("Добавить заболевание", systemImage: "plus") }
        }
    }

    private var sportsSection: some View {
        Section("Спорт") {
            ForEach(Array((a.sports ?? []).enumerated()), id: \.offset) { idx, _ in
                TextField("Вид спорта", text: sportBind(idx))
            }
            .onDelete { offsets in a.sports?.remove(atOffsets: offsets) }
            Button {
                a.sports = (a.sports ?? []) + [""]
            } label: { Label("Добавить вид спорта", systemImage: "plus") }
        }
    }

    private var surgeriesSection: some View {
        Section("Перенесённые операции") {
            ForEach(Array((a.surgeries ?? []).enumerated()), id: \.offset) { idx, _ in
                VStack(alignment: .leading, spacing: 6) {
                    TextField("Название", text: surgeryBind(idx, \.name))
                    TextField("Дата", text: surgeryBindOpt(idx, \.date))
                    TextField("Описание", text: surgeryBindOpt(idx, \.description))
                }
                .padding(.vertical, 4)
            }
            .onDelete { offsets in a.surgeries?.remove(atOffsets: offsets) }
            Button {
                a.surgeries = (a.surgeries ?? []) + [APIClient.SurgeryItem(name: "", date: nil, description: nil)]
            } label: { Label("Добавить операцию", systemImage: "plus") }
        }
    }

    // MARK: helpers UI

    private func textRow(_ title: String, text: Binding<String>) -> some View {
        HStack { Text(title); Spacer(); TextField("—", text: text).multilineTextAlignment(.trailing) }
    }
    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack { Text(title); Spacer(); Text(value).foregroundStyle(AGContentColors.secondaryText) }
    }

    // MARK: bindings (Anamnesis is a value type in @State)

    private func bindStr(_ kp: WritableKeyPath<APIClient.Anamnesis, String?>) -> Binding<String> {
        Binding(get: { a[keyPath: kp] ?? "" }, set: { a[keyPath: kp] = $0.isEmpty ? nil : $0 })
    }
    private func bindStrPicker(_ kp: WritableKeyPath<APIClient.Anamnesis, String?>) -> Binding<String> {
        Binding(get: { a[keyPath: kp] ?? "" }, set: { a[keyPath: kp] = $0.isEmpty ? nil : $0 })
    }
    private func bindInt(_ kp: WritableKeyPath<APIClient.Anamnesis, Int?>) -> Binding<String> {
        Binding(get: { a[keyPath: kp].map { "\($0)" } ?? "" }, set: { a[keyPath: kp] = Int($0) })
    }
    private func bindHabit(_ kp: WritableKeyPath<APIClient.Habits, Bool?>) -> Binding<Bool> {
        Binding(
            get: { a.habits?[keyPath: kp] ?? false },
            set: { newVal in
                var h = a.habits ?? APIClient.Habits(alcohol: false, smoking: false, drugs: false)
                h[keyPath: kp] = newVal
                a.habits = h
            }
        )
    }
    private func chronicBind(_ idx: Int, _ kp: WritableKeyPath<APIClient.ChronicItem, String>) -> Binding<String> {
        Binding(get: { a.chronic?[safe: idx]?[keyPath: kp] ?? "" },
                set: { if a.chronic != nil, idx < a.chronic!.count { a.chronic![idx][keyPath: kp] = $0 } })
    }
    private func chronicBindOpt(_ idx: Int, _ kp: WritableKeyPath<APIClient.ChronicItem, String?>) -> Binding<String> {
        Binding(get: { a.chronic?[safe: idx]?[keyPath: kp] ?? "" },
                set: { if a.chronic != nil, idx < a.chronic!.count { a.chronic![idx][keyPath: kp] = $0.isEmpty ? nil : $0 } })
    }
    private func chronicMedBind(_ idx: Int) -> Binding<String> {
        Binding(get: { a.chronic?[safe: idx]?.medicationId ?? "" },
                set: { if a.chronic != nil, idx < a.chronic!.count { a.chronic![idx].medicationId = $0.isEmpty ? nil : $0 } })
    }
    private func sportBind(_ idx: Int) -> Binding<String> {
        Binding(get: { a.sports?[safe: idx] ?? "" },
                set: { if a.sports != nil, idx < a.sports!.count { a.sports![idx] = $0 } })
    }
    private func surgeryBind(_ idx: Int, _ kp: WritableKeyPath<APIClient.SurgeryItem, String>) -> Binding<String> {
        Binding(get: { a.surgeries?[safe: idx]?[keyPath: kp] ?? "" },
                set: { if a.surgeries != nil, idx < a.surgeries!.count { a.surgeries![idx][keyPath: kp] = $0 } })
    }
    private func surgeryBindOpt(_ idx: Int, _ kp: WritableKeyPath<APIClient.SurgeryItem, String?>) -> Binding<String> {
        Binding(get: { a.surgeries?[safe: idx]?[keyPath: kp] ?? "" },
                set: { if a.surgeries != nil, idx < a.surgeries!.count { a.surgeries![idx][keyPath: kp] = $0.isEmpty ? nil : $0 } })
    }

    private func fmt(_ v: Double) -> String { String(format: "%g", v).replacingOccurrences(of: ".", with: ",") }

    // MARK: load / save

    private func load() async {
        isLoading = true
        do {
            let client = try apiConfiguration.makeAPIClient()
            if let existing = try await client.fetchAnamnesis() {
                await MainActor.run { a = existing }
            }
            if let ms = try? await client.fetchMeasurements() {
                await MainActor.run {
                    weightKg = ms.latest.weightKg?.value
                    heightCm = ms.latest.heightCm?.value
                }
            }
            if let medsList = try? await client.fetchMedications() {
                await MainActor.run { meds = medsList }
            }
            if let v = try? await client.fetchVision(), let latest = v.latest {
                await MainActor.run {
                    let r = latest.rightEye.map { String(format: "%g", $0) } ?? "—"
                    let l = latest.leftEye.map { String(format: "%g", $0) } ?? "—"
                    visionText = "Правый \(r) · Левый \(l)"
                }
            }
        } catch {
            print("AGHealth: AnamnesisView load error = \(error)")
        }
        await MainActor.run { isLoading = false }
    }

    private func save() async {
        isSaving = true; savedNote = nil
        do {
            let client = try apiConfiguration.makeAPIClient()
            // Не пишем в анамнез пустые хронические/спорт/операции без названия.
            var toSave = a
            toSave.chronic = (a.chronic ?? []).filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
            toSave.sports = (a.sports ?? []).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            toSave.surgeries = (a.surgeries ?? []).filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
            _ = try await client.saveAnamnesis(toSave)
            await MainActor.run { isSaving = false; onDone(true) }
        } catch {
            await MainActor.run { isSaving = false; savedNote = "Ошибка: \(error.localizedDescription)" }
        }
    }
}

// Безопасный доступ по индексу.
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
