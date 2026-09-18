import SwiftUI
import QuickLook
import UniformTypeIdentifiers

// Раздел «Приёмы врачей»: два таба — История и План. В истории — полная карточка приёма (текстовые
// разделы + прикреплённый PDF). В плане — короткая карточка запланированного приёма.
struct DoctorVisitsView: View {
    @State private var tab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                Text("История").tag(0)
                Text("План").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.top, 8)

            if tab == 0 {
                VisitsList(kind: "history")
            } else {
                VisitsList(kind: "plan")
            }
        }
        .background(AGContentColors.background.ignoresSafeArea())
        .navigationTitle("Приёмы врачей")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct VisitsList: View {
    let kind: String
    private let apiConfiguration = APIConfiguration()

    @State private var visits: [APIClient.DoctorVisit] = []
    @State private var isLoading = true
    @State private var showingAdd = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if isLoading {
                    ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.top, 40)
                } else if visits.isEmpty {
                    Text(kind == "history" ? "Пока нет приёмов в истории." : "Пока нет запланированных приёмов.")
                        .font(.system(size: 14)).foregroundStyle(AGContentColors.secondaryText)
                        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                        .background(AGContentColors.card).clipShape(RoundedRectangle(cornerRadius: 22))
                } else {
                    ForEach(visits) { v in VisitCard(visit: v, onChanged: { Task { await load() } }) }
                }
            }
            .padding(20)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .task { await load() }
        .sheet(isPresented: $showingAdd) {
            AddVisitView(kind: kind) { added in showingAdd = false; if added { Task { await load() } } }
        }
    }

    private func load() async {
        isLoading = true
        do {
            let client = try apiConfiguration.makeAPIClient()
            let list = try await client.fetchVisits(kind: kind)
            await MainActor.run { visits = list; isLoading = false }
        } catch {
            await MainActor.run { isLoading = false }
            print("AGHealth: VisitsList load error = \(error)")
        }
    }
}

struct VisitCard: View {
    let visit: APIClient.DoctorVisit
    let onChanged: () -> Void
    private let apiConfiguration = APIConfiguration()

    @State private var pdfURL: URL?
    @State private var loadingPdf = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(prettyDate(visit.visitDate)).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                if let organ = visit.organ, !organ.isEmpty {
                    Text(organ).font(.system(size: 12)).foregroundStyle(AGContentColors.secondaryText)
                }
            }
            field("Жалоба", visit.complaint)
            field("Врач (направление)", visit.referral)
            field("Врач (ФИО)", visit.doctorName)
            field("Заключение", visit.conclusion)
            field("Лечение", visit.treatment)
            field("Процедуры", visit.procedures)
            field("Описание", visit.description)

            if visit.hasPdf {
                Button {
                    Task { await openPdf() }
                } label: {
                    HStack(spacing: 8) {
                        if loadingPdf { ProgressView().tint(.white) }
                        else { Image(systemName: "doc.fill") }
                        Text(visit.pdfName ?? "Открыть PDF").font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white).padding(.horizontal, 14).frame(height: 36)
                    .background(AGContentColors.accent).clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(AGContentColors.card).clipShape(RoundedRectangle(cornerRadius: 18))
        .quickLookPreview($pdfURL)
    }

    @ViewBuilder
    private func field(_ title: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(AGContentColors.tertiaryText)
                Text(value).font(.system(size: 14)).foregroundStyle(AGContentColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func openPdf() async {
        loadingPdf = true
        do {
            let client = try apiConfiguration.makeAPIClient()
            let url = try await client.downloadVisitPdf(visitId: visit.id)
            await MainActor.run { pdfURL = url }
        } catch {
            print("AGHealth: openPdf error = \(error)")
        }
        loadingPdf = false
    }

    private func prettyDate(_ iso: String) -> String {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let f2 = ISO8601DateFormatter(); f2.formatOptions = [.withInternetDateTime]
        guard let d = f.date(from: iso) ?? f2.date(from: iso) else { return iso }
        let out = DateFormatter(); out.locale = Locale(identifier: "ru_RU"); out.dateFormat = "d MMMM yyyy"
        return out.string(from: d)
    }
}

// Форма добавления приёма. Для истории — полный набор полей + прикрепить PDF; для плана — краткий.
struct AddVisitView: View {
    let kind: String
    let onDone: (Bool) -> Void
    private let apiConfiguration = APIConfiguration()

    @State private var date = Date()
    @State private var organ = ""
    @State private var complaint = ""
    @State private var referral = ""
    @State private var doctorName = ""
    @State private var conclusion = ""
    @State private var treatment = ""
    @State private var procedures = ""
    @State private var description = ""
    @State private var pickedPdf: URL?
    @State private var showingPicker = false
    @State private var isSaving = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section { DatePicker("Дата", selection: $date, displayedComponents: .date) }
                Section("Приём") {
                    TextField("Орган / с жалобами", text: $organ)
                    TextField("Жалоба", text: $complaint, axis: .vertical)
                }
                if kind == "history" {
                    Section("Детали") {
                        TextField("Врач (направление)", text: $referral)
                        TextField("Врач (ФИО)", text: $doctorName)
                        TextField("Заключение", text: $conclusion, axis: .vertical)
                        TextField("Лечение", text: $treatment, axis: .vertical)
                        TextField("Процедуры", text: $procedures, axis: .vertical)
                    }
                    Section("PDF") {
                        Button {
                            showingPicker = true
                        } label: {
                            Label(pickedPdf == nil ? "Прикрепить PDF" : (pickedPdf?.lastPathComponent ?? "PDF выбран"),
                                  systemImage: "paperclip")
                        }
                    }
                } else {
                    Section("Детали") {
                        TextField("Врач", text: $doctorName)
                        TextField("Описание", text: $description, axis: .vertical)
                    }
                }
                if let errorText { Section { Text(errorText).font(.caption).foregroundStyle(.red) } }
            }
            .navigationTitle(kind == "history" ? "Добавить приём" : "Запланировать приём")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { onDone(false) } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { Task { await save() } }.disabled(isSaving)
                }
            }
            .fileImporter(isPresented: $showingPicker, allowedContentTypes: [UTType.pdf]) { result in
                if case .success(let url) = result { pickedPdf = url }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func save() async {
        isSaving = true; errorText = nil
        do {
            let client = try apiConfiguration.makeAPIClient()
            let id = UUID().uuidString.lowercased()
            _ = try await client.createVisit(
                id: id, kind: kind, visitDate: date,
                organ: organ.isEmpty ? nil : organ,
                complaint: complaint.isEmpty ? nil : complaint,
                referral: referral.isEmpty ? nil : referral,
                doctorName: doctorName.isEmpty ? nil : doctorName,
                conclusion: conclusion.isEmpty ? nil : conclusion,
                treatment: treatment.isEmpty ? nil : treatment,
                procedures: procedures.isEmpty ? nil : procedures,
                description: description.isEmpty ? nil : description
            )
            // Загрузить PDF, если выбран (только для истории).
            if kind == "history", let url = pickedPdf {
                let didAccess = url.startAccessingSecurityScopedResource()
                defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url) {
                    _ = try? await client.uploadVisitPdf(visitId: id, data: data, fileName: url.lastPathComponent)
                }
            }
            await MainActor.run { isSaving = false; onDone(true) }
        } catch {
            await MainActor.run { isSaving = false; errorText = error.localizedDescription }
        }
    }
}
