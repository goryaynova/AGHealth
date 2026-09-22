import SwiftUI

// Экран количества (промт §4): размер порции / граммы / доступные serving-опции, авто-пересчёт КБЖУ.
// Продукт сначала регистрируется в каталоге (createFood, идемпотентно), затем пишется food entry.

struct FoodQuantityView: View {
    let date: Date
    let mealType: String
    let food: PickedFood
    @ObservedObject var store: NutritionStore
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss

    enum Mode: String, CaseIterable { case grams = "Граммы"; case serving = "Порции" }

    @State private var mode: Mode = .grams
    @State private var gramsText = "100"
    @State private var servingsText = "1"
    @State private var isSaving = false
    @State private var error: String?

    // Итоговые граммы в зависимости от режима.
    private var effectiveGrams: Double {
        switch mode {
        case .grams:
            return Double(gramsText.replacingOccurrences(of: ",", with: ".")) ?? 0
        case .serving:
            let qty = Double(servingsText.replacingOccurrences(of: ",", with: ".")) ?? 0
            return qty * (food.servingGrams ?? 0)
        }
    }

    private var calc: (kcal: Double, p: Double, f: Double, c: Double) {
        let factor = effectiveGrams / 100
        return (food.kcalPer100g * factor, food.proteinPer100g * factor,
                food.fatPer100g * factor, food.carbsPer100g * factor)
    }

    private var hasServing: Bool { (food.servingGrams ?? 0) > 0 && food.servingDescription != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(food.name)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                        if let brand = food.brand, !brand.isEmpty {
                            Text(brand).font(.system(size: 14))
                                .foregroundStyle(AGContentColors.secondaryText)
                        }
                        Text("На 100 г: \(NutritionDateFormat.kcal(food.kcalPer100g)) ккал")
                            .font(.system(size: 13))
                            .foregroundStyle(AGContentColors.tertiaryText)
                    }

                    if hasServing {
                        Picker("Режим", selection: $mode) {
                            ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }

                    if mode == .grams || !hasServing {
                        quantityField(title: "Количество, г", text: $gramsText)
                    } else {
                        quantityField(title: "Порций (\(food.servingDescription ?? ""))", text: $servingsText)
                        Text("1 порция ≈ \(NutritionDateFormat.grams(food.servingGrams ?? 0)) г")
                            .font(.system(size: 12))
                            .foregroundStyle(AGContentColors.tertiaryText)
                    }

                    // Живой пересчёт КБЖУ (промт §4: не заставлять вводить КБЖУ вручную).
                    CalcPreviewCard(kcal: calc.kcal, protein: calc.p, fat: calc.f, carbs: calc.c)

                    if let error { ErrorCard(message: error) }

                    AGPrimaryButton(
                        title: "Добавить",
                        isLoading: isSaving,
                        isDisabled: effectiveGrams <= 0
                    ) {
                        Task { await save() }
                    }
                }
                .padding(20)
            }
            .background(AGContentColors.background.ignoresSafeArea())
            .navigationTitle("Количество")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Назад") { dismiss() }.foregroundStyle(AGContentColors.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func quantityField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 13))
                .foregroundStyle(AGContentColors.secondaryText)
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .padding(14)
                .background(AGContentColors.card)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func save() async {
        guard effectiveGrams > 0 else { return }
        isSaving = true
        error = nil
        defer { isSaving = false }
        do {
            let api = try APIConfiguration().makeAPIClient()
            // 1) Определить foodId: если продукт уже в каталоге (мой продукт) — берём его id;
            // иначе (из поиска FatSecret) — регистрируем в каталоге (идемпотентно, дедуп по externalId).
            let foodId: String
            if let existing = food.existingFoodId {
                foodId = existing
            } else {
                let created = try await api.createFood(
                    id: UUID().uuidString,
                    source: food.source,
                    name: food.name,
                    kcalPer100g: food.kcalPer100g,
                    proteinPer100g: food.proteinPer100g,
                    fatPer100g: food.fatPer100g,
                    carbsPer100g: food.carbsPer100g,
                    externalId: food.externalId,
                    foodType: food.foodType,
                    brand: food.brand,
                    servingDescription: food.servingDescription,
                    servingGrams: food.servingGrams)
                foodId = created.id
            }

            // 2) Записать факт употребления.
            let servingDesc = (mode == .serving && hasServing) ? food.servingDescription : nil
            let servingQty = (mode == .serving && hasServing)
                ? Double(servingsText.replacingOccurrences(of: ",", with: ".")) : nil
            let ok = await store.addEntry(
                date: date, mealType: mealType, foodId: foodId, grams: effectiveGrams,
                servingDescription: servingDesc, servingQty: servingQty)
            if ok { onDone() } else { error = store.errorMessage ?? "Не удалось сохранить." }
        } catch {
            self.error = "Не удалось сохранить продукт."
        }
    }
}

struct CalcPreviewCard: View {
    let kcal: Double
    let protein: Double
    let fat: Double
    let carbs: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom, spacing: 6) {
                Text(NutritionDateFormat.kcal(kcal))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                Text("ккал").font(.system(size: 14))
                    .foregroundStyle(AGContentColors.secondaryText)
                    .padding(.bottom, 4)
            }
            HStack(spacing: 10) {
                macroChip("Б", protein, AGContentColors.accent)
                macroChip("Ж", fat, AGContentColors.orange)
                macroChip("У", carbs, AGContentColors.purple)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(AGContentColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func macroChip(_ label: String, _ value: Double, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(label) \(NutritionDateFormat.grams(value)) г")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(AGContentColors.cardSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
