import SwiftUI

// Раздел «Зрение»: значения на каждый глаз по датам + добавление.
struct VisionView: View {
    private let apiConfiguration = APIConfiguration()

    @State private var records: [APIClient.VisionRecord] = []
    @State private var isLoading = true
    @State private var showingAdd = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if isLoading {
                    ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.top, 40)
                } else if records.isEmpty {
                    Text("Пока нет записей о зрении. Нажмите «+».")
                        .font(.system(size: 14)).foregroundStyle(AGContentColors.secondaryText)
                        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                        .background(AGContentColors.card).clipShape(RoundedRectangle(cornerRadius: 22))
                } else {
                    ForEach(records) { r in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(prettyDate(r.measuredAt)).font(.system(size: 14)).foregroundStyle(.white)
                                Text("Правый \(eye(r.rightEye)) · Левый \(eye(r.leftEye))")
                                    .font(.system(size: 13)).foregroundStyle(AGContentColors.secondaryText)
                            }
                            Spacer()
                        }
                        .padding(16).background(AGContentColors.card).clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                }
            }
            .padding(20)
        }
        .background(AGContentColors.background.ignoresSafeArea())
        .navigationTitle("Зрение")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .task { await load() }
        .sheet(isPresented: $showingAdd) {
            AddVisionView { added in showingAdd = false; if added { Task { await load() } } }
        }
    }

    private func eye(_ v: Double?) -> String { v.map { String(format: "%g", $0) } ?? "—" }

    private func load() async {
        isLoading = true
        do {
            let client = try apiConfiguration.makeAPIClient()
            let list = try await client.fetchVision()
            await MainActor.run { records = list.vision; isLoading = false }
        } catch {
            await MainActor.run { isLoading = false }
            print("AGHealth: VisionView load error = \(error)")
        }
    }

    private func prettyDate(_ iso: String) -> String {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let f2 = ISO8601DateFormatter(); f2.formatOptions = [.withInternetDateTime]
        guard let d = f.date(from: iso) ?? f2.date(from: iso) else { return iso }
        let out = DateFormatter(); out.locale = Locale(identifier: "ru_RU"); out.dateFormat = "d MMMM yyyy"
        return out.string(from: d)
    }
}

struct AddVisionView: View {
    let onDone: (Bool) -> Void
    private let apiConfiguration = APIConfiguration()

    @State private var date = Date()
    @State private var right = ""
    @State private var left = ""
    @State private var isSaving = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section { DatePicker("Дата", selection: $date, displayedComponents: .date) }
                Section("Значения (диоптрии)") {
                    HStack { Text("Правый глаз"); Spacer()
                        TextField("напр. -1.5", text: $right).keyboardType(.numbersAndPunctuation).multilineTextAlignment(.trailing).frame(width: 110) }
                    HStack { Text("Левый глаз"); Spacer()
                        TextField("напр. -2.0", text: $left).keyboardType(.numbersAndPunctuation).multilineTextAlignment(.trailing).frame(width: 110) }
                }
                if let errorText { Section { Text(errorText).font(.caption).foregroundStyle(.red) } }
            }
            .navigationTitle("Добавить зрение")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { onDone(false) } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { Task { await save() } }.disabled(isSaving || (parse(right) == nil && parse(left) == nil))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func parse(_ s: String) -> Double? {
        let n = s.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? nil : Double(n)
    }

    private func save() async {
        isSaving = true; errorText = nil
        do {
            let client = try apiConfiguration.makeAPIClient()
            _ = try await client.createVision(
                id: UUID().uuidString.lowercased(),
                measuredAt: date,
                rightEye: parse(right),
                leftEye: parse(left),
                note: nil
            )
            await MainActor.run { isSaving = false; onDone(true) }
        } catch {
            await MainActor.run { isSaving = false; errorText = error.localizedDescription }
        }
    }
}
