import SwiftUI
import Combine

// Раздел «Питание» (промт AGHEALTH_FOOD_21092026) — реальный трекер еды.
// Данные проходят полный путь: FatSecret/Manual → backend → DB → iOS → дневная/недельная сводка.
// Никаких mock-данных: всё грузится через APIClient. Заглушка импорта Excel/CSV удалена навсегда.

// MARK: - Форматирование дат для API (YYYY-MM-DD, локальный календарь).

enum NutritionDateFormat {
    static func apiString(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    // Понедельник недели, в которую попадает date.
    static func weekStart(_ date: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        var start = cal.date(from: comps) ?? date
        // Гарантируем понедельник (Calendar может дать воскресенье в зависимости от локали).
        let weekday = cal.component(.weekday, from: start) // 1=вс
        let offset = (weekday + 5) % 7 // до понедельника
        start = cal.date(byAdding: .day, value: -offset, to: start) ?? start
        return start
    }

    static func kcal(_ v: Double) -> String {
        String(Int(v.rounded()))
    }

    static func grams(_ v: Double) -> String {
        let r = (v * 10).rounded() / 10
        return r == r.rounded() ? String(Int(r)) : String(r)
    }
}

// MARK: - Корневой экран

struct NutritionSectionView: View {
    @State private var selectedDate = Date()
    @State private var selectedTab = NutritionTab.day
    @StateObject private var store = NutritionStore()

    enum NutritionTab: String, CaseIterable {
        case day = "День"
        case analytics = "Аналитика"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    NutritionHeader()

                    if selectedTab == .day {
                        NutritionDateSelector(selectedDate: $selectedDate)
                    }

                    Picker("Раздел", selection: $selectedTab) {
                        ForEach(NutritionTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)

                    if selectedTab == .day {
                        NutritionDayScreen(date: selectedDate, store: store)
                    } else {
                        NutritionAnalyticsScreen(anchorDate: selectedDate, store: store)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
            .background(AGContentColors.background.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .task(id: selectedDate) {
            if selectedTab == .day {
                await store.loadDay(date: selectedDate)
            }
        }
        .task(id: selectedTab) {
            if selectedTab == .day {
                await store.loadDay(date: selectedDate)
            } else {
                await store.loadWeek(anchor: selectedDate)
            }
        }
    }
}

struct NutritionHeader: View {
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Питание")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)

                Text("Калории, КБЖУ и рацион")
                    .font(.system(size: 15))
                    .foregroundStyle(AGContentColors.secondaryText)
            }
            Spacer()
        }
    }
}

struct NutritionDateSelector: View {
    @Binding var selectedDate: Date

    private var isToday: Bool { Calendar.current.isDateInToday(selectedDate) }

    var body: some View {
        HStack(spacing: 8) {
            Button { moveDay(-1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .background(AGContentColors.card)
                    .clipShape(Circle())
            }
            Spacer()
            VStack(spacing: 3) {
                Text(isToday ? "Сегодня" : formattedDate(selectedDate))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(formattedWeekday(selectedDate))
                    .font(.system(size: 12))
                    .foregroundStyle(AGContentColors.secondaryText)
            }
            Spacer()
            Button { guard !isToday else { return }; moveDay(1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isToday ? AGContentColors.tertiaryText : .white)
                    .frame(width: 34, height: 34)
                    .background(AGContentColors.card)
                    .clipShape(Circle())
            }
            .disabled(isToday)
        }
    }

    private func moveDay(_ value: Int) {
        selectedDate = Calendar.current.date(byAdding: .day, value: value, to: selectedDate) ?? selectedDate
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMMM"
        return f.string(from: date)
    }

    private func formattedWeekday(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "EEEE"
        return f.string(from: date).capitalized
    }
}

// MARK: - Store (загрузка/мутации, единый источник состояния раздела)

@MainActor
final class NutritionStore: ObservableObject {
    @Published var day: APIClient.NutritionDay?
    @Published var week: APIClient.NutritionWeek?
    @Published var isLoadingDay = false
    @Published var isLoadingWeek = false
    @Published var errorMessage: String?
    @Published var fatSecretConfigured = true

    private let config = APIConfiguration()

    private func client() throws -> APIClient { try config.makeAPIClient() }

    func loadDay(date: Date) async {
        isLoadingDay = true
        errorMessage = nil
        defer { isLoadingDay = false }
        do {
            let api = try client()
            day = try await api.fetchNutritionDay(date: NutritionDateFormat.apiString(date))
        } catch {
            errorMessage = friendly(error)
        }
    }

    func loadWeek(anchor: Date) async {
        isLoadingWeek = true
        errorMessage = nil
        defer { isLoadingWeek = false }
        do {
            let api = try client()
            let start = NutritionDateFormat.apiString(NutritionDateFormat.weekStart(anchor))
            week = try await api.fetchNutritionWeek(start: start, days: 7)
        } catch {
            errorMessage = friendly(error)
        }
    }

    // Записать факт употребления и обновить день.
    func addEntry(date: Date, mealType: String, foodId: String, grams: Double,
                  servingDescription: String?, servingQty: Double?) async -> Bool {
        do {
            let api = try client()
            _ = try await api.createFoodEntry(
                id: UUID().uuidString, date: NutritionDateFormat.apiString(date),
                mealType: mealType, foodId: foodId, grams: grams,
                servingDescription: servingDescription, servingQty: servingQty)
            await loadDay(date: date)
            return true
        } catch {
            errorMessage = friendly(error)
            return false
        }
    }

    func deleteEntry(id: String, date: Date) async {
        do {
            let api = try client()
            try await api.deleteFoodEntry(id: id)
            await loadDay(date: date)
        } catch {
            errorMessage = friendly(error)
        }
    }

    func checkFatSecret() async {
        do {
            let api = try client()
            fatSecretConfigured = try await api.fetchFatSecretConfigured()
        } catch {
            fatSecretConfigured = false
        }
    }

    private func friendly(_ error: Error) -> String {
        if let apiErr = error as? APIError {
            switch apiErr {
            case .network:
                return "Нет связи с сервером. Проверьте подключение."
            case .httpStatus(let code):
                return "Сервер вернул ошибку (\(code))."
            default:
                return "Не удалось загрузить данные."
            }
        }
        if case APIConfigurationError.tokenNotConfigured = error {
            return "Не настроен доступ к серверу (токен)."
        }
        return "Не удалось загрузить данные."
    }
}
