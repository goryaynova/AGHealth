import SwiftUI

// Body muscle map: front + back ANATOMICAL human figures with muscle groups highlighted by training
// intensity.
//
// CP3 / review: the base body is now a real anatomical muscle illustration (asset `BodyFront` /
// `BodyBack`), matching the reference style Anna wanted. Muscle load is shown as tinted highlight
// overlays placed over the corresponding muscles. Highlights use a semantic colour scale
// (нет→красный … высокая→зелёный). Interactivity: tapping a muscle region calls onSelect(groupKey).
//
// Asset attribution (CC BY-SA 4.0): "Muscles front and back" by OpenStax & Tomáš Kebert &
// umimeto.org, via Wikimedia Commons. Shown in the app's «О приложении» (see BodyMapAttribution).
//
// Levels: "high" | "medium" | "low" | "none" — совпадает со словарём backend muscle-summary.
//
// Цветовая шкала (по просьбе Анны): недоработанные мышцы — «тревожными» цветами:
//   нет → красный, низкая → оранжевый, средняя → жёлтый, высокая → зелёный.

enum MuscleIntensity: String {
    case none, low, medium, high

    init(level: String?) {
        self = MuscleIntensity(rawValue: level ?? "none") ?? .none
    }

    // Семантическая цветовая шкала. `base` сохранён в сигнатуре для совместимости.
    func color(base: Color = .clear) -> Color {
        switch self {
        case .none: return Self.red
        case .low: return Self.orange
        case .medium: return Self.yellow
        case .high: return Self.green
        }
    }

    // Прозрачность подсветки поверх ассета. По просьбе Анны раскраска мышц сделана более
    // насыщенной (тело приглушено ниже), чтобы нагрузка не терялась на фоне иллюстрации.
    var overlayOpacity: Double {
        switch self {
        case .none: return 0.0      // не подсвечиваем «нет» на теле (видно по легенде/спискам)
        case .low: return 0.70
        case .medium: return 0.82
        case .high: return 0.95
        }
    }

    // Насыщенные семантические цвета (подняли контраст/чистоту тона под просьбу Анны).
    static let red = Color(red: 0.94, green: 0.18, blue: 0.16)     // нет проработки
    static let orange = Color(red: 1.00, green: 0.50, blue: 0.05)  // низкая
    static let yellow = Color(red: 1.00, green: 0.82, blue: 0.05)  // средняя
    static let green = Color(red: 0.15, green: 0.80, blue: 0.35)   // высокая
}

enum BodySide {
    case front, back

    var assetName: String { self == .front ? "BodyFront" : "BodyBack" }
    // Aspect ratio (w/h) of the corresponding asset, so the overlay frame matches the image exactly.
    var aspect: CGFloat { self == .front ? 0.556 : 0.501 }
}

// A highlight region over the body asset, in NORMALISED coordinates (0…1) of the image frame.
// `rect` is the ellipse's bounding box; muscles are drawn as soft ellipses over the anatomy.
private struct MuscleRegion {
    let groupKey: String
    let muscle: String?
    let cx: CGFloat  // center x (0…1)
    let cy: CGFloat  // center y (0…1)
    let w: CGFloat   // width  (0…1)
    let h: CGFloat   // height (0…1)
}

// MARK: - Region library (normalised to each asset)

private enum MuscleRegionLibrary {
    // FRONT — coordinates tuned to the BodyFront asset (head ~top, pecs upper, abs mid, quads lower).
    static let front: [MuscleRegion] = [
        // Shoulders (front delts).
        MuscleRegion(groupKey: "shoulders", muscle: "передняя дельта", cx: 0.30, cy: 0.235, w: 0.14, h: 0.06),
        MuscleRegion(groupKey: "shoulders", muscle: "передняя дельта", cx: 0.70, cy: 0.235, w: 0.14, h: 0.06),
        // Chest (pecs).
        MuscleRegion(groupKey: "chest", muscle: "большая грудная", cx: 0.40, cy: 0.28, w: 0.16, h: 0.08),
        MuscleRegion(groupKey: "chest", muscle: "большая грудная", cx: 0.60, cy: 0.28, w: 0.16, h: 0.08),
        // Biceps.
        MuscleRegion(groupKey: "arms", muscle: "бицепс", cx: 0.235, cy: 0.355, w: 0.08, h: 0.10),
        MuscleRegion(groupKey: "arms", muscle: "бицепс", cx: 0.765, cy: 0.355, w: 0.08, h: 0.10),
        // Forearms.
        MuscleRegion(groupKey: "forearms", muscle: "сгибатели", cx: 0.18, cy: 0.45, w: 0.08, h: 0.10),
        MuscleRegion(groupKey: "forearms", muscle: "сгибатели", cx: 0.82, cy: 0.45, w: 0.08, h: 0.10),
        // Core (abs) + obliques.
        MuscleRegion(groupKey: "core", muscle: "прямая мышца живота", cx: 0.50, cy: 0.375, w: 0.14, h: 0.10),
        MuscleRegion(groupKey: "core", muscle: "косые мышцы", cx: 0.38, cy: 0.40, w: 0.05, h: 0.08),
        MuscleRegion(groupKey: "core", muscle: "косые мышцы", cx: 0.62, cy: 0.40, w: 0.05, h: 0.08),
        // Quads.
        MuscleRegion(groupKey: "legs", muscle: "квадрицепс", cx: 0.41, cy: 0.60, w: 0.12, h: 0.15),
        MuscleRegion(groupKey: "legs", muscle: "квадрицепс", cx: 0.59, cy: 0.60, w: 0.12, h: 0.15),
        // Calves (front/shin).
        MuscleRegion(groupKey: "legs", muscle: "икроножная", cx: 0.42, cy: 0.775, w: 0.09, h: 0.11),
        MuscleRegion(groupKey: "legs", muscle: "икроножная", cx: 0.58, cy: 0.775, w: 0.09, h: 0.11),
    ]

    // BACK — coordinates tuned to the BodyBack asset (traps/lats upper, glutes mid, hamstrings lower).
    static let back: [MuscleRegion] = [
        // Rear delts.
        MuscleRegion(groupKey: "shoulders", muscle: "задняя дельта", cx: 0.28, cy: 0.235, w: 0.13, h: 0.06),
        MuscleRegion(groupKey: "shoulders", muscle: "задняя дельта", cx: 0.72, cy: 0.235, w: 0.13, h: 0.06),
        // Traps.
        MuscleRegion(groupKey: "back", muscle: "трапеция", cx: 0.50, cy: 0.235, w: 0.20, h: 0.07),
        // Lats.
        MuscleRegion(groupKey: "back", muscle: "широчайшие", cx: 0.40, cy: 0.33, w: 0.13, h: 0.10),
        MuscleRegion(groupKey: "back", muscle: "широчайшие", cx: 0.60, cy: 0.33, w: 0.13, h: 0.10),
        // Spinal erectors.
        MuscleRegion(groupKey: "back", muscle: "разгибатели позвоночника", cx: 0.50, cy: 0.36, w: 0.07, h: 0.12),
        // Triceps.
        MuscleRegion(groupKey: "arms", muscle: "трицепс", cx: 0.225, cy: 0.33, w: 0.08, h: 0.10),
        MuscleRegion(groupKey: "arms", muscle: "трицепс", cx: 0.775, cy: 0.33, w: 0.08, h: 0.10),
        // Forearms (extensors).
        MuscleRegion(groupKey: "forearms", muscle: "разгибатели", cx: 0.16, cy: 0.45, w: 0.08, h: 0.10),
        MuscleRegion(groupKey: "forearms", muscle: "разгибатели", cx: 0.84, cy: 0.45, w: 0.08, h: 0.10),
        // Glutes.
        MuscleRegion(groupKey: "glutes", muscle: "большая ягодичная", cx: 0.41, cy: 0.475, w: 0.13, h: 0.09),
        MuscleRegion(groupKey: "glutes", muscle: "большая ягодичная", cx: 0.59, cy: 0.475, w: 0.13, h: 0.09),
        // Hamstrings.
        MuscleRegion(groupKey: "legs", muscle: "бицепс бедра", cx: 0.41, cy: 0.63, w: 0.12, h: 0.14),
        MuscleRegion(groupKey: "legs", muscle: "бицепс бедра", cx: 0.59, cy: 0.63, w: 0.12, h: 0.14),
        // Calves (back).
        MuscleRegion(groupKey: "legs", muscle: "икроножная", cx: 0.42, cy: 0.80, w: 0.09, h: 0.11),
        MuscleRegion(groupKey: "legs", muscle: "икроножная", cx: 0.58, cy: 0.80, w: 0.09, h: 0.11),
    ]
}

// MARK: - Single anatomical body (asset + highlight overlays)

private struct BodyView: View {
    let side: BodySide
    let levels: [String: String]        // groupKey -> level
    let muscleLevels: [String: String]  // muscle -> level (optional, level-2)
    let baseColor: Color
    var onSelect: ((String) -> Void)? = nil

    private var regions: [MuscleRegion] {
        side == .front ? MuscleRegionLibrary.front : MuscleRegionLibrary.back
    }

    private func level(for region: MuscleRegion) -> String {
        if !muscleLevels.isEmpty, let m = region.muscle, let lvl = muscleLevels[m] {
            return lvl
        }
        return levels[region.groupKey] ?? "none"
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                // Base anatomical figure. Приглушено (по просьбе Анны) — чтобы раскраска мышц читалась ярче.
                Image(side.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size.width, height: size.height)
                    .opacity(0.45)
                    .saturation(0.35)

                // Highlight overlays over the muscles.
                ForEach(Array(regions.enumerated()), id: \.offset) { _, region in
                    let intensity = MuscleIntensity(level: level(for: region))
                    let rect = CGRect(
                        x: (region.cx - region.w / 2) * size.width,
                        y: (region.cy - region.h / 2) * size.height,
                        width: region.w * size.width,
                        height: region.h * size.height
                    )
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [
                                    intensity.color().opacity(intensity.overlayOpacity),
                                    intensity.color().opacity(intensity.overlayOpacity),
                                    intensity.color().opacity(0),
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: max(rect.width, rect.height) / 1.35
                            )
                        )
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .allowsHitTesting(false)

                    // Transparent tap target over the muscle (interactivity).
                    Ellipse()
                        .fill(Color.white.opacity(0.001))
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .onTapGesture { onSelect?(region.groupKey) }
                }
            }
        }
        .aspectRatio(side.aspect, contentMode: .fit)
    }
}

// MARK: - Public muscle map (front + back side by side)

struct MuscleMapView: View {
    /// groupKey -> level ("high"/"medium"/"low"/"none").
    let levels: [String: String]
    /// Optional specific-muscle -> level, for level-2 (per-muscle) highlighting.
    var muscleLevels: [String: String] = [:]
    var baseColor: Color = AGContentColors.accent
    /// Optional tap handler — receives the tapped region's groupKey (interactivity).
    var onSelect: ((String) -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 18) {
                labelledBody(title: "Спереди", side: .front)
                labelledBody(title: "Сзади", side: .back)
            }
            legend
            BodyMapAttribution()
        }
    }

    private func labelledBody(title: String, side: BodySide) -> some View {
        VStack(spacing: 8) {
            BodyView(
                side: side,
                levels: levels,
                muscleLevels: muscleLevels,
                baseColor: baseColor,
                onSelect: onSelect
            )
            .frame(maxWidth: .infinity)
            .frame(height: 230)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AGContentColors.secondaryText)
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem("Нет", MuscleIntensity.none.color())
            legendItem("Низкая", MuscleIntensity.low.color())
            legendItem("Средняя", MuscleIntensity.medium.color())
            legendItem("Высокая", MuscleIntensity.high.color())
        }
        .frame(maxWidth: .infinity)
    }

    private func legendItem(_ text: String, _ color: Color) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 12, height: 12)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(AGContentColors.secondaryText)
        }
    }
}

// Attribution required by the CC BY-SA 4.0 licence of the body asset.
struct BodyMapAttribution: View {
    var body: some View {
        Text("Иллюстрация тела: OpenStax, Tomáš Kebert & umimeto.org · CC BY-SA 4.0")
            .font(.system(size: 9))
            .foregroundStyle(AGContentColors.tertiaryText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}
