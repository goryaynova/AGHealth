import SwiftUI

// Поток добавления еды (промт §4/§5/§14). Каталог — Open Food Facts (русскоязычная база,
// РФ-продукты). Если продукта нет — ручное создание. После выбора — экран количества с
// авто-пересчётом КБЖУ. Состояния: загрузка, пусто, ошибка API, нет сети, debounce, пагинация.
// FatSecret временно убран из UI (решение Анны 22.09.2026); код провайдера сохранён на бэкенде.

struct AddFoodFlowView: View {
    let date: Date
    let mealType: String
    @ObservedObject var store: NutritionStore
    @Environment(\.dismiss) private var dismiss

    enum SourceMode: String, CaseIterable { case catalog = "Каталог"; case mine = "Мои продукты" }

    @State private var sourceMode: SourceMode = .catalog
    @State private var query = ""
    @State private var results: [APIClient.FoodSearchResult] = []
    @State private var myFoods: [APIClient.Food] = []
    @State private var isSearching = false
    @State private var searchError: String?
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

    private var searchPlaceholder: String {
        sourceMode == .catalog ? "Поиск в каталоге (англ., напр. chicken)" : "Поиск среди моих продуктов"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Источник", selection: $sourceMode) {
                    ForEach(SourceMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.top, 12)

                searchBar

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if let err = searchError {
                            ErrorCard(message: err)
                        }

                        if sourceMode == .catalog {
                            catalogContent
                        } else {
                            myFoodsContent
                        }
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
            .sheet(isPresented: $showingManual, onDismiss: { Task { await loadMyFoods() } }) {
                ManualFoodView(date: date, mealType: mealType, store: store) {
                    dismiss()
                }
            }
            .task {
                await loadMyFoods()
            }
            .onChange(of: sourceMode) { _, _ in
                query = ""; results = []; searchError = nil
                if sourceMode == .mine { Task { await loadMyFoods() } }
            }
        }
        .preferredColorScheme(.dark)
    }

    // —— Каталог Open Food Facts ——
    @ViewBuilder private var catalogContent: some View {
        if results.isEmpty && query.count < 2 {
            Text("Каталог Open Food Facts — российские продукты и бренды. Ищите по-русски (напр. «творог»).")
                .font(.system(size: 12))
                .foregroundStyle(AGContentColors.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }

        if isSearching && results.isEmpty {
            ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.top, 24)
        } else if results.isEmpty && query.count >= 2 && !isSearching && searchError == nil {
            EmptyResultsCard()
        }

        ForEach(results) { result in
            FoodResultRow(result: result) { picked = PickedFood(from: result) }
        }

        if hasMore && !results.isEmpty {
            Button { Task { await search(reset: false) } } label: {
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

        FatSecretAttributionView().padding(.top, 8)
    }

    // —— Мои продукты (созданные вручную) ——
    @ViewBuilder private var myFoodsContent: some View {
        if isSearching && myFoods.isEmpty {
            ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.top, 24)
        } else if myFoods.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "tray").font(.system(size: 26)).foregroundStyle(AGContentColors.tertiaryText)
                Text(query.isEmpty ? "Пока нет своих продуктов" : "Ничего не найдено")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                Text("Создайте продукт кнопкой «Вручную» — он сохранится здесь для повторного выбора.")
                    .font(.system(size: 13)).foregroundStyle(AGContentColors.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(24)
            .background(AGContentColors.card).clipShape(RoundedRectangle(cornerRadius: 18))
        } else {
            ForEach(myFoods) { food in
                MyFoodRow(food: food) { picked = PickedFood(from: food) }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AGContentColors.secondaryText)
            TextField(searchPlaceholder, text: $query)
                .foregroundStyle(.white)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { Task { await runSearch(reset: true) } }
                .onChange(of: query) { _, newValue in scheduleSearch(newValue) }
            if !query.isEmpty {
                Button { query = ""; results = []; searchError = nil; Task { await loadMyFoods() } } label: {
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

    private func scheduleSearch(_ text: String) {
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if sourceMode == .mine {
            // Локальный поиск — мгновенно (кириллица работает).
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 250_000_000)
                if Task.isCancelled { return }
                await loadMyFoods()
            }
            return
        }
        // Каталог FatSecret — debounce (промт §14).
        guard trimmed.count >= 2 else { results = []; hasMore = false; return }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            if Task.isCancelled { return }
            await runSearch(reset: true)
        }
    }

    private func runSearch(reset: Bool) async {
        if sourceMode == .mine { await loadMyFoods(); return }
        await search(reset: reset)
    }

    private func loadMyFoods() async {
        isSearching = true
        defer { isSearching = false }
        do {
            let api = try APIConfiguration().makeAPIClient()
            myFoods = try await api.fetchMyFoods(query: query.isEmpty ? nil : query)
        } catch {
            myFoods = []
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

// Строка «моего продукта» из каталога.
struct MyFoodRow: View {
    let food: APIClient.Food
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(food.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(2).multilineTextAlignment(.leading)
                    Text("100 г · \(Int(food.kcalPer100g.rounded())) ккал · Б \(NutritionDateFormat.grams(food.proteinPer100g)) Ж \(NutritionDateFormat.grams(food.fatPer100g)) У \(NutritionDateFormat.grams(food.carbsPer100g))")
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

// Продукт, переданный на экран количества (из каталога FatSecret, из «Моих продуктов», или manual).
// existingFoodId — если продукт уже в каталоге (мой продукт), не пересоздаём — логируем напрямую.
struct PickedFood: Identifiable {
    let id = UUID()
    let existingFoodId: String?
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

    // Из результата поиска каталога Open Food Facts (ещё НЕ в нашем каталоге → будет создан).
    init(from r: APIClient.FoodSearchResult) {
        existingFoodId = nil
        externalId = r.externalId
        source = "openfoodfacts"
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

    // Из уже сохранённого продукта каталога (мой продукт) — логируем по его id.
    init(from f: APIClient.Food) {
        existingFoodId = f.id
        externalId = f.externalId
        source = f.source
        name = f.name
        brand = f.brand
        foodType = f.foodType
        kcalPer100g = f.kcalPer100g
        proteinPer100g = f.proteinPer100g
        fatPer100g = f.fatPer100g
        carbsPer100g = f.carbsPer100g
        servingDescription = f.servingDescription
        servingGrams = f.servingGrams
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

// Attribution Open Food Facts (лицензия ODbL) — бейдж со ссылкой на openfoodfacts.org.
struct FatSecretAttributionView: View {
    var body: some View {
        Link(destination: URL(string: "https://openfoodfacts.org")!) {
            HStack(spacing: 6) {
                Text("Данные о питании —")
                    .font(.system(size: 11))
                    .foregroundStyle(AGContentColors.tertiaryText)
                Text("Open Food Facts (ODbL)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AGContentColors.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
