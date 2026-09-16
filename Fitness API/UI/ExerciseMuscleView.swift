import SwiftUI

// Exercise-level muscle map + primary/secondary breakdown, driven by the SAME muscle mapping
// (`exercise.muscles`) the weekly analytics use. Given the list of muscles an exercise works, it:
//   1. highlights the involved body parts on the shared MuscleMapView (front/back);
//   2. lists «Основная нагрузка» and «Дополнительная» muscles.
// This reuses the single mapping — no separate logic for exercise detail.

struct ExerciseMuscleView: View {
    let muscles: [APIClient.ExerciseMuscle]

    // Map contribution/role → a map intensity level so the body map reads sensibly:
    //   primary → high; secondary ≥ 0.5 → medium; secondary < 0.5 → low.
    private func level(for m: APIClient.ExerciseMuscle) -> String {
        if m.isPrimary { return "high" }
        return m.contribution >= 0.5 ? "medium" : "low"
    }

    // Per-body-part level = the strongest level among that part's muscles.
    private var levels: [String: String] {
        let rank = ["none": 0, "low": 1, "medium": 2, "high": 3]
        var out: [String: String] = [:]
        for m in muscles {
            let lvl = level(for: m)
            if (rank[lvl] ?? 0) > (rank[out[m.groupKey] ?? "none"] ?? 0) {
                out[m.groupKey] = lvl
            }
        }
        return out
    }

    private var primary: [APIClient.ExerciseMuscle] { muscles.filter { $0.isPrimary } }
    private var secondary: [APIClient.ExerciseMuscle] { muscles.filter { !$0.isPrimary } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("НАГРУЗКА НА МЫШЦЫ")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1)
                .foregroundStyle(AGContentColors.secondaryText)

            MuscleMapView(levels: levels)
                .padding(.vertical, 2)

            if !primary.isEmpty {
                muscleBlock(title: "Основная нагрузка", items: primary, color: AGContentColors.accent)
            }
            if !secondary.isEmpty {
                muscleBlock(
                    title: "Дополнительная",
                    items: secondary,
                    color: AGContentColors.accent.opacity(0.6)
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AGContentColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func muscleBlock(
        title: String,
        items: [APIClient.ExerciseMuscle],
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)

            ForEach(items) { m in
                HStack(spacing: 8) {
                    Circle().fill(color).frame(width: 7, height: 7)
                    Text(muscleLabel(m))
                        .font(.system(size: 14))
                        .foregroundStyle(AGContentColors.secondaryText)
                    Spacer()
                }
            }
        }
    }

    private func muscleLabel(_ m: APIClient.ExerciseMuscle) -> String {
        let part = MuscleCatalog.label(forKey: m.groupKey)
        if let muscle = m.muscle, !muscle.isEmpty {
            return "\(part) → \(muscle)"
        }
        return part
    }
}
