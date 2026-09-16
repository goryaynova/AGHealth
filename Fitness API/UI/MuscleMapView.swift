import SwiftUI

// Body muscle map: front + back stylised human silhouettes with muscle groups highlighted by
// training intensity. Redrawn (CP5) for a cleaner, more anatomical look: a smooth curved silhouette
// and visually separated muscle regions, several intensity levels, neutral for untrained.
//
// Two levels of detail (task §9):
//   • Level 1 — body part (groupKey): passed via `levels: [groupKey: level]`.
//   • Level 2 — specific muscle: optionally passed via `muscleLevels: [muscleKey: level]`, where a
//     region tagged with a specific muscle is highlighted by that muscle's own level. This lets the
//     exercise-detail map light up an individual muscle, while the weekly map lights whole groups.
//
// Built entirely with SwiftUI Shapes — no third-party framework, no external asset. The reference
// image is used only as a visual guide, not copied.
//
// Levels: "high" | "medium" | "low" | "none" — matching the backend muscle-summary vocabulary.

enum MuscleIntensity: String {
    case none, low, medium, high

    init(level: String?) {
        self = MuscleIntensity(rawValue: level ?? "none") ?? .none
    }

    func color(base: Color) -> Color {
        switch self {
        case .none: return Color.white.opacity(0.055)
        case .low: return base.opacity(0.34)
        case .medium: return base.opacity(0.62)
        case .high: return base.opacity(0.95)
        }
    }
}

enum BodySide {
    case front, back
}

// A muscle region drawn on a normalized 100 (w) × 220 (h) canvas.
// `groupKey` = the body part it belongs to; `muscle` (optional) = the specific muscle, used for
// level-2 (per-muscle) highlighting.
private struct MuscleShape {
    let groupKey: String
    let muscle: String?
    let side: BodySide
    let path: (CGRect) -> Path
}

// MARK: - Shape library (normalized 100×220 coordinate space)

private enum MuscleShapeLibrary {
    static let W: CGFloat = 100
    static let H: CGFloat = 220

    private static func ellipse(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> (CGRect) -> Path {
        { rect in
            let sx = rect.width / W, sy = rect.height / H
            return Path(ellipseIn: CGRect(x: x * sx, y: y * sy, width: w * sx, height: h * sy))
        }
    }

    private static func rr(
        _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat = 4
    ) -> (CGRect) -> Path {
        { rect in
            let sx = rect.width / W, sy = rect.height / H
            return Path(
                roundedRect: CGRect(x: x * sx, y: y * sy, width: w * sx, height: h * sy),
                cornerRadius: r * min(sx, sy)
            )
        }
    }

    // FRONT regions. Muscle tags enable level-2 highlighting.
    static let front: [MuscleShape] = [
        // Shoulders (front delts).
        MuscleShape(groupKey: "shoulders", muscle: "передняя дельта", side: .front, path: ellipse(22, 45, 15, 13)),
        MuscleShape(groupKey: "shoulders", muscle: "передняя дельта", side: .front, path: ellipse(63, 45, 15, 13)),
        // Chest — upper + main pecs (two rows so «верх груди» can be distinguished).
        MuscleShape(groupKey: "chest", muscle: "верх груди", side: .front, path: rr(35, 52, 13, 8, 4)),
        MuscleShape(groupKey: "chest", muscle: "верх груди", side: .front, path: rr(52, 52, 13, 8, 4)),
        MuscleShape(groupKey: "chest", muscle: "большая грудная", side: .front, path: rr(35, 60, 13, 11, 5)),
        MuscleShape(groupKey: "chest", muscle: "большая грудная", side: .front, path: rr(52, 60, 13, 11, 5)),
        // Arms (biceps).
        MuscleShape(groupKey: "arms", muscle: "бицепс", side: .front, path: rr(19, 61, 8, 25, 4)),
        MuscleShape(groupKey: "arms", muscle: "бицепс", side: .front, path: rr(73, 61, 8, 25, 4)),
        // Forearms.
        MuscleShape(groupKey: "forearms", muscle: "сгибатели", side: .front, path: rr(17, 87, 7, 22, 3)),
        MuscleShape(groupKey: "forearms", muscle: "сгибатели", side: .front, path: rr(76, 87, 7, 22, 3)),
        // Core (abs) + obliques.
        MuscleShape(groupKey: "core", muscle: "прямая мышца живота", side: .front, path: rr(42, 74, 16, 30, 4)),
        MuscleShape(groupKey: "core", muscle: "косые мышцы", side: .front, path: rr(37, 78, 5, 22, 3)),
        MuscleShape(groupKey: "core", muscle: "косые мышцы", side: .front, path: rr(58, 78, 5, 22, 3)),
        // Legs — quads + adductors + calves (front).
        MuscleShape(groupKey: "legs", muscle: "квадрицепс", side: .front, path: rr(35, 116, 12, 42, 6)),
        MuscleShape(groupKey: "legs", muscle: "квадрицепс", side: .front, path: rr(53, 116, 12, 42, 6)),
        MuscleShape(groupKey: "legs", muscle: "приводящие", side: .front, path: rr(46, 116, 8, 30, 4)),
        MuscleShape(groupKey: "legs", muscle: "икроножная", side: .front, path: rr(37, 160, 9, 32, 4)),
        MuscleShape(groupKey: "legs", muscle: "икроножная", side: .front, path: rr(54, 160, 9, 32, 4)),
    ]

    // BACK regions.
    static let back: [MuscleShape] = [
        // Shoulders (rear delts) + traps.
        MuscleShape(groupKey: "shoulders", muscle: "задняя дельта", side: .back, path: ellipse(22, 45, 15, 13)),
        MuscleShape(groupKey: "shoulders", muscle: "задняя дельта", side: .back, path: ellipse(63, 45, 15, 13)),
        MuscleShape(groupKey: "back", muscle: "трапеция", side: .back, path: rr(40, 44, 20, 14, 5)),
        // Back — lats (two sides) + mid back.
        MuscleShape(groupKey: "back", muscle: "широчайшие", side: .back, path: rr(35, 58, 13, 26, 6)),
        MuscleShape(groupKey: "back", muscle: "широчайшие", side: .back, path: rr(52, 58, 13, 26, 6)),
        MuscleShape(groupKey: "back", muscle: "разгибатели позвоночника", side: .back, path: rr(46, 60, 8, 30, 4)),
        // Arms (triceps).
        MuscleShape(groupKey: "arms", muscle: "трицепс", side: .back, path: rr(19, 61, 8, 25, 4)),
        MuscleShape(groupKey: "arms", muscle: "трицепс", side: .back, path: rr(73, 61, 8, 25, 4)),
        // Forearms.
        MuscleShape(groupKey: "forearms", muscle: "разгибатели", side: .back, path: rr(17, 87, 7, 22, 3)),
        MuscleShape(groupKey: "forearms", muscle: "разгибатели", side: .back, path: rr(76, 87, 7, 22, 3)),
        // Glutes.
        MuscleShape(groupKey: "glutes", muscle: "большая ягодичная", side: .back, path: rr(35, 100, 14, 16, 6)),
        MuscleShape(groupKey: "glutes", muscle: "большая ягодичная", side: .back, path: rr(51, 100, 14, 16, 6)),
        // Legs — hamstrings + calves (back).
        MuscleShape(groupKey: "legs", muscle: "бицепс бедра", side: .back, path: rr(35, 118, 12, 40, 6)),
        MuscleShape(groupKey: "legs", muscle: "бицепс бедра", side: .back, path: rr(53, 118, 12, 40, 6)),
        MuscleShape(groupKey: "legs", muscle: "икроножная", side: .back, path: rr(36, 160, 10, 32, 4)),
        MuscleShape(groupKey: "legs", muscle: "икроножная", side: .back, path: rr(54, 160, 10, 32, 4)),
    ]
}

// MARK: - Single body silhouette

private struct BodyView: View {
    let side: BodySide
    let levels: [String: String]        // groupKey -> level
    let muscleLevels: [String: String]  // muscle -> level (optional, level-2)
    let baseColor: Color

    private var shapes: [MuscleShape] {
        side == .front ? MuscleShapeLibrary.front : MuscleShapeLibrary.back
    }

    // Level for a region: prefer a specific-muscle level (level 2) when provided, else the group.
    private func level(for shape: MuscleShape) -> String {
        if !muscleLevels.isEmpty, let m = shape.muscle, let lvl = muscleLevels[m] {
            return lvl
        }
        return levels[shape.groupKey] ?? "none"
    }

    var body: some View {
        GeometryReader { geo in
            let rect = CGRect(origin: .zero, size: geo.size)
            ZStack {
                silhouette(in: rect).fill(Color.white.opacity(0.05))

                ForEach(Array(shapes.enumerated()), id: \.offset) { _, shape in
                    let intensity = MuscleIntensity(level: level(for: shape))
                    shape.path(rect)
                        .fill(intensity.color(base: baseColor))
                }

                silhouette(in: rect).stroke(Color.white.opacity(0.14), lineWidth: 1.1)
            }
        }
        .aspectRatio(MuscleShapeLibrary.W / MuscleShapeLibrary.H, contentMode: .fit)
    }

    // Smooth humanoid outline (head + tapered torso + limbs) built with curves.
    private func silhouette(in rect: CGRect) -> Path {
        let sx = rect.width / MuscleShapeLibrary.W
        let sy = rect.height / MuscleShapeLibrary.H
        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * sx, y: y * sy) }

        var path = Path()
        // Head + neck.
        path.addEllipse(in: CGRect(x: 43 * sx, y: 6 * sy, width: 14 * sx, height: 16 * sy))
        path.addRect(CGRect(x: 46 * sx, y: 20 * sy, width: 8 * sx, height: 6 * sy))

        // Torso: shoulders → waist → hips, as a closed curved shape.
        path.move(to: P(30, 42))
        path.addQuadCurve(to: P(38, 40), control: P(33, 38)) // left shoulder top
        path.addLine(to: P(62, 40))
        path.addQuadCurve(to: P(70, 42), control: P(67, 38)) // right shoulder top
        path.addQuadCurve(to: P(64, 74), control: P(70, 60)) // right side to waist
        path.addQuadCurve(to: P(68, 104), control: P(63, 90)) // hip out
        path.addLine(to: P(32, 104))
        path.addQuadCurve(to: P(36, 74), control: P(37, 90)) // left hip to waist
        path.addQuadCurve(to: P(30, 42), control: P(30, 60))
        path.closeSubpath()

        // Arms.
        path.addRoundedRect(in: CGRect(x: 16 * sx, y: 42 * sy, width: 12 * sx, height: 68 * sy),
                            cornerSize: CGSize(width: 6 * sx, height: 6 * sy))
        path.addRoundedRect(in: CGRect(x: 72 * sx, y: 42 * sy, width: 12 * sx, height: 68 * sy),
                            cornerSize: CGSize(width: 6 * sx, height: 6 * sy))
        // Legs.
        path.addRoundedRect(in: CGRect(x: 33 * sx, y: 104 * sy, width: 15 * sx, height: 104 * sy),
                            cornerSize: CGSize(width: 7 * sx, height: 7 * sy))
        path.addRoundedRect(in: CGRect(x: 52 * sx, y: 104 * sy, width: 15 * sx, height: 104 * sy),
                            cornerSize: CGSize(width: 7 * sx, height: 7 * sy))
        return path
    }
}

// MARK: - Public muscle map (front + back side by side)

struct MuscleMapView: View {
    /// groupKey -> level ("high"/"medium"/"low"/"none").
    let levels: [String: String]
    /// Optional specific-muscle -> level, for level-2 (per-muscle) highlighting.
    var muscleLevels: [String: String] = [:]
    var baseColor: Color = AGContentColors.accent

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 18) {
                labelledBody(title: "Спереди", side: .front)
                labelledBody(title: "Сзади", side: .back)
            }
            legend
        }
    }

    private func labelledBody(title: String, side: BodySide) -> some View {
        VStack(spacing: 8) {
            BodyView(side: side, levels: levels, muscleLevels: muscleLevels, baseColor: baseColor)
                .frame(maxWidth: .infinity)
                .frame(height: 210)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AGContentColors.secondaryText)
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem("Нет", MuscleIntensity.none.color(base: baseColor))
            legendItem("Низкая", MuscleIntensity.low.color(base: baseColor))
            legendItem("Средняя", MuscleIntensity.medium.color(base: baseColor))
            legendItem("Высокая", MuscleIntensity.high.color(base: baseColor))
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
