import SwiftUI

// Ручное создание продукта (промт §5). Поля: название + КБЖУ на 100 г + количество (граммы).
// Хранение нормализованное (на 100 г), фактическое потребление считается из количества.
// Не усложняем UX: продукт создаётся и сразу добавляется в приём пищи одним действием.

struct ManualFoodView: View {
    let date: Date
    let mealType: String
    @ObservedObject var store: NutritionStore
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var kcalText = ""
    @State private var proteinText = ""
    @State private var fatText = ""
    @State private var carbsText = ""
    @State private var gramsText = "100"
    @State private var isSaving = false
    @State private var error: String?

    private func d(_ s: String) -> Double { Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0 }

    private var grams: Double { d(gramsText) }
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && grams > 0 && !kcalText.isEmpty
    }

    // Предпросмотр фактического КБЖУ за указанное количество.
    private var calc: (kcal: Double, p: Double, f: Double, c: Double) {
        let factor = grams / 100
        return (d(kcalText) * factor, d(proteinText) * factor, d(fatText) * factor, d(carbsText) * factor)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Значения КБЖУ указываются на 100 г. Фактическое потребление посчитаем из количества.")
                        .font(.system(size: 13))
                        .foregroundStyle(AGContentColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    field("Название продукта", text: $name, keyboard: .default, placeholder: "напр. Творог 5%")

                    HStack(spacing: 10) {
                        numField("Ккал / 100 г", text: $kcalText)
                        numField("Кол-во, г", text: $gramsText)
                    }
                    HStack(spacing: 10) {
                        numField("Белки / 100 г", text: $proteinText)
                        numField("Жиры / 100 г", text: $fatText)
                        numField("Углев / 100 г", text: $carbsText)
                    }

                    CalcPreviewCard(kcal: calc.kcal, protein: calc.p, fat: calc.f, carbs: calc.c)

                    if let error { ErrorCard(message: error) }

                    AGPrimaryButton(title: "Создать и добавить", isLoading: isSaving, isDisabled: !canSave) {
                        Task { await save() }
                    }
                }
                .padding(20)
            }
            .background(AGContentColors.background.ignoresSafeArea())
            .navigationTitle("Добавить вручную")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }.foregroundStyle(AGContentColors.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func field(_ title: String, text: Binding<String>, keyboard: UIKeyboardType, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 13)).foregroundStyle(AGContentColors.secondaryText)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .foregroundStyle(.white)
                .padding(14)
                .background(AGContentColors.card)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func numField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 12)).foregroundStyle(AGContentColors.secondaryText)
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .padding(12)
                .background(AGContentColors.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxWidth: .infinity)
    }

    private func save() async {
        guard canSave else { return }
        isSaving = true
        error = nil
        defer { isSaving = false }
        do {
            let api = try APIConfiguration().makeAPIClient()
            let created = try await api.createFood(
                id: UUID().uuidString, source: "manual",
                name: name.trimmingCharacters(in: .whitespaces),
                kcalPer100g: d(kcalText), proteinPer100g: d(proteinText),
                fatPer100g: d(fatText), carbsPer100g: d(carbsText))
            let ok = await store.addEntry(
                date: date, mealType: mealType, foodId: created.id, grams: grams,
                servingDescription: nil, servingQty: nil)
            if ok { onDone() } else { error = store.errorMessage ?? "Не удалось сохранить." }
        } catch {
            self.error = "Не удалось создать продукт."
        }
    }
}
