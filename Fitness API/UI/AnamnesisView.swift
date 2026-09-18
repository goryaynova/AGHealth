import SwiftUI

// Раздел «Анамнез»: ровно одна карточка «мой анамнез», с сохранением/обновлением. Вес/рост
// подтягиваются из «Замеров», зрение — из «Зрения»; хронические болезни можно пролинковать с
// лекарством из раздела «Лекарства».
struct AnamnesisView: View {
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

            Section {
                Button {
                    Task { await save() }
                } label: {
                    HStack { Spacer(); Text(isSaving ? "Сохранение…" : "Сохранить").bold(); Spacer() }
                }
                .disabled(isSaving)
                if let savedNote {
                    Text(savedNote).font(.caption).foregroundStyle(AGContentColors.green)
                }
            }
        }
        .navigationTitle("Анамнез")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .task { await load() }
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
            let saved = try await client.saveAnamnesis(toSave)
            await MainActor.run { a = saved; isSaving = false; savedNote = "Анамнез сохранён" }
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
