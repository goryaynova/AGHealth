import SwiftUI

// Поток добавления еды (промт §4/§5/§14). По умолчанию — поиск в каталоге FatSecret; если продукта
// нет или каталог недоступен — ручное создание. После выбора продукта — экран количества с
// авто-пересчётом КБЖУ. Учтены состояния: загрузка, пусто, ошибка API, нет сети, debounce, пагинация.

struct AddFoodFlowView: View {
    let date: Date
    let mealType: String
    @ObservedObject var store: NutritionStore
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [APIClient.FoodSearchResult] = []
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var fatSecretConfigured = true
    @State private var page = 0
    @State private var hasMore = false
    @State private var searchTask: Task<Void, Never>?

    // Выбранный продукт для экрана количества.
    @State private var picked: PickedFood?
    @State private var showingManual = false

    private var mealLabel: String {
        ["breakfast": "Завтрак", "snack": "Перекус", "lunch": "Обед",
         "afternoon": "Полдник", "dinner": "Ужин"][mealType] ?? "Приём пищи"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if !fatSecretConfigured {
                            FatSecretUnavailableCard()
                        }
                        if let err = searchError {
                            ErrorCard(message: err)
                        }

                        if isSearching && results.isEmpty {
                            ProgressView().tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 24)
                        } else if results.isEmpty && !query.isEmpty && !isSearching && fatSecretConfigured && searchError == nil {
                            EmptyResultsCard()
                        }

                        ForEach(results) { result in
                            FoodResultRow(result: result) {
                                picked = PickedFood(from: result)
                            }
                        }

                        if hasMore && !results.isEmpty {
                            Button {
                                Task { await search(reset: false) }
                            } label: {
                                if isSearching {
                                    ProgressView().tint(.white).frame(maxWidth: .infinity)
                                } else {
                                    Text("Показать ещё")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(AGContentColors.accent)
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                }
                            }
                        }

                        FatSecretAttributionView()
                            .padding(.top, 8)
                    }
                    .padding(20)
                }
            }
            .background(AGContentColors.background.ignoresSafeArea())
            .navigationTitle("Добавить в «\(mealLabel)»")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }.foregroundStyle(AGContentColors.accent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingManual = true
                    } label: {
                        Label("Вручную", systemImage: "square.and.pencil")
                    }
                    .foregroundStyle(AGContentColors.accent)
                }
            }
            .sheet(item: $picked) { food in
                FoodQuantityView(date: date, mealType: mealType, food: food, store: store) {
                    dismiss()
                }
            }
            .sheet(isPresented: $showingManual) {
                ManualFoodView(date: date, mealType: mealType, store: store) {
                    dismiss()
                }
            }
            .task {
                await store.checkFatSecret()
                fatSecretConfigured = store.fatSecretConfigured
            }
        }
        .preferredColorScheme(.dark)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AGContentColors.secondaryText)
            TextField("Найти продукт, напр. курица", text: $query)
                .foregroundStyle(.white)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { Task { await search(reset: true) } }
                .onChange(of: query) { _, newValue in scheduleSearch(newValue) }
            if !query.isEmpty {
                Button { query = ""; results = []; searchError = nil } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AGContentColors.tertiaryText)
                }
            }
        }
        .padding(14)
        .background(AGContentColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    // Debounce: не дёргаем FatSecret на каждый символ (промт §14).
    private func scheduleSearch(_ text: String) {
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { results = []; hasMore = false; return }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            if Task.isCancelled { return }
            await search(reset: true)
        }
    }

    private func search(reset: Bool) async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return }
        if reset { page = 0 }
        isSearching = true
        searchError = nil
        defer { isSearching = false }
        do {
            let api = try APIConfiguration().makeAPIClient()
            let resp = try await api.searchFoods(query: trimmed, page: reset ? 0 : page)
            fatSecretConfigured = resp.configured
            if reset {
                results = resp.results
            } else {
                results.append(contentsOf: resp.results)
            }
            page = resp.page + 1
            hasMore = resp.hasMore
        } catch let apiErr as APIError {
            switch apiErr {
            case .network:
                searchError = "Нет сети. Продукт можно добавить вручную."
            case .httpStatus(let code):
                searchError = "Поиск недоступен (\(code)). Попробуйте ещё раз или добавьте вручную."
            default:
                searchError = "Не удалось выполнить поиск."
            }
        } catch {
            searchError = "Не удалось выполнить поиск."
        }
    }
}

// Продукт, переданный на экран количества (из каталога FatSecret или как основа для manual).
struct PickedFood: Identifiable {
    let id = UUID()
    let externalId: String?
    let source: String
    let name: String
    let brand: String?
    let foodType: String?
    let kcalPer100g: Double
    let proteinPer100g: Double
    let fatPer100g: Double
    let carbsPer100g: Double
    let servingDescription: String?
    let servingGrams: Double?

    init(from r: APIClient.FoodSearchResult) {
        externalId = r.externalId
        source = "fatsecret"
        name = r.name
        brand = r.brand
        foodType = r.foodType
        kcalPer100g = r.kcalPer100g
        proteinPer100g = r.proteinPer100g
        fatPer100g = r.fatPer100g
        carbsPer100g = r.carbsPer100g
        servingDescription = r.servingDescription
        servingGrams = r.servingGrams
    }
}

struct FoodResultRow: View {
    let result: APIClient.FoodSearchResult
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 6) {
                        if let brand = result.brand, !brand.isEmpty {
                            Text(brand).font(.system(size: 12))
                                .foregroundStyle(AGContentColors.secondaryText)
                        }
                        Text(result.foodType == "brand" ? "Бренд" : "Обычный")
                            .font(.system(size: 11))
                            .foregroundStyle(AGContentColors.tertiaryText)
                    }
                    Text("100 г · \(NutritionDateFormat.kcal(result.kcalPer100g)) ккал · Б \(NutritionDateFormat.grams(result.proteinPer100g)) Ж \(NutritionDateFormat.grams(result.fatPer100g)) У \(NutritionDateFormat.grams(result.carbsPer100g))")
                        .font(.system(size: 12))
                        .foregroundStyle(AGContentColors.secondaryText)
                }
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(AGContentColors.accent)
            }
            .padding(14)
            .background(AGContentColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

struct EmptyResultsCard: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 26))
                .foregroundStyle(AGContentColors.tertiaryText)
            Text("Ничего не найдено")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            Text("Попробуйте другое название или добавьте продукт вручную (кнопка «Вручную»).")
                .font(.system(size: 13))
                .foregroundStyle(AGContentColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(AGContentColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct FatSecretUnavailableCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Поиск каталога недоступен", systemImage: "info.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AGContentColors.orange)
            Text("Каталог FatSecret ещё не подключён. Продукты можно добавлять вручную — кнопка «Вручную» вверху.")
                .font(.system(size: 13))
                .foregroundStyle(AGContentColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AGContentColors.orange.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// Attribution FatSecret (промт §18) — обязателен для Basic/Premier Free. Официальный бейдж
// «Powered by fatsecret», ссылка на platform.fatsecret.com.
struct FatSecretAttributionView: View {
    var body: some View {
        Link(destination: URL(string: "https://platform.fatsecret.com")!) {
            HStack(spacing: 6) {
                Text("Данные о питании предоставлены")
                    .font(.system(size: 11))
                    .foregroundStyle(AGContentColors.tertiaryText)
                Text("fatsecret Platform API")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AGContentColors.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
