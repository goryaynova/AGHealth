import SwiftUI

// Body muscle map: front + back ANATOMICAL human silhouettes with muscle groups highlighted by
// training intensity.
//
// CP3 redraw — по референсу Анны (реалистичный манекен-фигура, экран «Замеры»): вместо прежней
// абстрактной схемы (прямоугольники/эллипсы) теперь анатомичный силуэт женской фигуры с плавными
// кривыми (округлые плечи, талия, бёдра, сужающиеся бёдра/голени) и мышечные зоны, повторяющие
// контур тела. Референс зафиксирован в docs/reference/CP3_bodymap_reference.md. Мы повторяем
// визуальный ПРИНЦИП (человеческий силуэт + подсветка зон + интерактивность), не копируя картинку.
//
// Собрано целиком на SwiftUI Shapes (Bézier) — без сторонних фреймворков и без внешнего 3D-ассета.
//
// Two levels of detail (task §9):
//   • Level 1 — body part (groupKey): passed via `levels: [groupKey: level]`.
//   • Level 2 — specific muscle: optionally via `muscleLevels: [muscleKey: level]`.
//
// Интерактивность: тап по зоне мышцы → onSelect(groupKey) (используется в аналитике для раскрытия
// соответствующей категории). API сохранён обратно совместимым (onSelect опционален).
//
// Levels: "high" | "medium" | "low" | "none" — совпадает со словарём backend muscle-summary.

enum MuscleIntensity: String {
    case none, low, medium, high

    init(level: String?) {
        self = MuscleIntensity(rawValue: level ?? "none") ?? .none
    }

    func color(base: Color) -> Color {
        switch self {
        case .none: return Color.white.opacity(0.05)
        case .low: return base.opacity(0.34)
        case .medium: return base.opacity(0.62)
        case .high: return base.opacity(0.95)
        }
    }
}

enum BodySide {
    case front, back
}

// Normalized 100 (w) × 220 (h) canvas helpers shared by the silhouette and every muscle region,
// so limbs and muscles always align to the same anatomical outline.
private enum BodyCanvas {
    static let W: CGFloat = 100
    static let H: CGFloat = 220
    static func x(_ v: CGFloat, _ rect: CGRect) -> CGFloat { v / W * rect.width }
    static func y(_ v: CGFloat, _ rect: CGRect) -> CGFloat { v / H * rect.height }
    static func p(_ px: CGFloat, _ py: CGFloat, _ rect: CGRect) -> CGPoint {
        CGPoint(x: x(px, rect), y: y(py, rect))
    }
}

// A muscle region: a closed anatomical patch (built from curves) that follows the body contour.
private struct MuscleShape {
    let groupKey: String
    let muscle: String?
    let side: BodySide
    let build: (CGRect) -> Path
}

// Small path builder: a smooth closed blob through points using quad curves between midpoints,
// giving organic muscle shapes instead of rectangles.
private func blob(_ pts: [(CGFloat, CGFloat)]) -> (CGRect) -> Path {
    { rect in
        guard pts.count >= 3 else { return Path() }
        let P = pts.map { BodyCanvas.p($0.0, $0.1, rect) }
        var path = Path()
        let mid0 = CGPoint(x: (P[0].x + P[P.count - 1].x) / 2, y: (P[0].y + P[P.count - 1].y) / 2)
        path.move(to: mid0)
        for i in 0..<P.count {
            let cur = P[i]
            let next = P[(i + 1) % P.count]
            let mid = CGPoint(x: (cur.x + next.x) / 2, y: (cur.y + next.y) / 2)
            path.addQuadCurve(to: mid, control: cur)
        }
        path.closeSubpath()
        return path
    }
}

// Mirror x around the body centre (50) for the right-side twin of a muscle.
private func mirrored(_ pts: [(CGFloat, CGFloat)]) -> [(CGFloat, CGFloat)] {
    pts.map { (100 - $0.0, $0.1) }
}

// MARK: - Anatomical muscle regions

private enum MuscleShapeLibrary {
    // FRONT — quads/abs/chest/shoulders/biceps/forearms, shaped to the figure's contour.
    static let front: [MuscleShape] = {
        var s: [MuscleShape] = []

        // Shoulders (front delts) — rounded caps on the shoulder line.
        let deltL: [(CGFloat, CGFloat)] = [(24,43),(32,42),(35,48),(31,54),(25,52),(22,47)]
        s.append(MuscleShape(groupKey: "shoulders", muscle: "передняя дельта", side: .front, build: blob(deltL)))
        s.append(MuscleShape(groupKey: "shoulders", muscle: "передняя дельта", side: .front, build: blob(mirrored(deltL))))

        // Chest (pecs) — two soft pec plates under the collarbone.
        let pecL: [(CGFloat, CGFloat)] = [(37,52),(48,53),(49,62),(44,68),(37,65),(35,57)]
        s.append(MuscleShape(groupKey: "chest", muscle: "большая грудная", side: .front, build: blob(pecL)))
        s.append(MuscleShape(groupKey: "chest", muscle: "большая грудная", side: .front, build: blob(mirrored(pecL))))

        // Biceps — upper-arm bulge.
        let biL: [(CGFloat, CGFloat)] = [(20,60),(27,60),(28,74),(25,84),(20,82),(18,68)]
        s.append(MuscleShape(groupKey: "arms", muscle: "бицепс", side: .front, build: blob(biL)))
        s.append(MuscleShape(groupKey: "arms", muscle: "бицепс", side: .front, build: blob(mirrored(biL))))

        // Forearms (flexors).
        let faL: [(CGFloat, CGFloat)] = [(16,86),(23,87),(23,104),(20,110),(16,106),(15,92)]
        s.append(MuscleShape(groupKey: "forearms", muscle: "сгибатели", side: .front, build: blob(faL)))
        s.append(MuscleShape(groupKey: "forearms", muscle: "сгибатели", side: .front, build: blob(mirrored(faL))))

        // Core — rectus abdominis (central) + obliques (sides).
        let abs: [(CGFloat, CGFloat)] = [(43,72),(57,72),(58,84),(56,100),(50,104),(44,100),(42,84)]
        s.append(MuscleShape(groupKey: "core", muscle: "прямая мышца живота", side: .front, build: blob(abs)))
        let oblL: [(CGFloat, CGFloat)] = [(37,78),(42,80),(42,98),(38,100),(35,92)]
        s.append(MuscleShape(groupKey: "core", muscle: "косые мышцы", side: .front, build: blob(oblL)))
        s.append(MuscleShape(groupKey: "core", muscle: "косые мышцы", side: .front, build: blob(mirrored(oblL))))

        // Quads — large tapered thigh muscles.
        let quadL: [(CGFloat, CGFloat)] = [(35,116),(47,117),(47,140),(45,158),(38,158),(34,138)]
        s.append(MuscleShape(groupKey: "legs", muscle: "квадрицепс", side: .front, build: blob(quadL)))
        s.append(MuscleShape(groupKey: "legs", muscle: "квадрицепс", side: .front, build: blob(mirrored(quadL))))

        // Calves (front/shins).
        let calfL: [(CGFloat, CGFloat)] = [(37,162),(45,163),(45,182),(42,192),(38,190),(36,172)]
        s.append(MuscleShape(groupKey: "legs", muscle: "икроножная", side: .front, build: blob(calfL)))
        s.append(MuscleShape(groupKey: "legs", muscle: "икроножная", side: .front, build: blob(mirrored(calfL))))

        return s
    }()

    // BACK — traps/lats/rear-delts/triceps/glutes/hamstrings/calves.
    static let back: [MuscleShape] = {
        var s: [MuscleShape] = []

        // Rear delts.
        let deltL: [(CGFloat, CGFloat)] = [(24,43),(32,42),(35,48),(31,54),(25,52),(22,47)]
        s.append(MuscleShape(groupKey: "shoulders", muscle: "задняя дельта", side: .back, build: blob(deltL)))
        s.append(MuscleShape(groupKey: "shoulders", muscle: "задняя дельта", side: .back, build: blob(mirrored(deltL))))

        // Traps — upper-back diamond.
        let traps: [(CGFloat, CGFloat)] = [(50,40),(60,48),(56,58),(50,60),(44,58),(40,48)]
        s.append(MuscleShape(groupKey: "back", muscle: "трапеция", side: .back, build: blob(traps)))

        // Lats — broad wings tapering to the waist.
        let latL: [(CGFloat, CGFloat)] = [(37,58),(46,60),(48,74),(44,84),(38,82),(35,68)]
        s.append(MuscleShape(groupKey: "back", muscle: "широчайшие", side: .back, build: blob(latL)))
        s.append(MuscleShape(groupKey: "back", muscle: "широчайшие", side: .back, build: blob(mirrored(latL))))

        // Spinal erectors (central lower back).
        let erectors: [(CGFloat, CGFloat)] = [(46,62),(54,62),(55,84),(50,92),(45,84)]
        s.append(MuscleShape(groupKey: "back", muscle: "разгибатели позвоночника", side: .back, build: blob(erectors)))

        // Triceps.
        let triL: [(CGFloat, CGFloat)] = [(20,60),(27,60),(28,74),(25,84),(20,82),(18,68)]
        s.append(MuscleShape(groupKey: "arms", muscle: "трицепс", side: .back, build: blob(triL)))
        s.append(MuscleShape(groupKey: "arms", muscle: "трицепс", side: .back, build: blob(mirrored(triL))))

        // Forearms (extensors).
        let faL: [(CGFloat, CGFloat)] = [(16,86),(23,87),(23,104),(20,110),(16,106),(15,92)]
        s.append(MuscleShape(groupKey: "forearms", muscle: "разгибатели", side: .back, build: blob(faL)))
        s.append(MuscleShape(groupKey: "forearms", muscle: "разгибатели", side: .back, build: blob(mirrored(faL))))

        // Glutes — rounded seat.
        let gluL: [(CGFloat, CGFloat)] = [(36,100),(49,101),(50,110),(46,118),(38,117),(34,108)]
        s.append(MuscleShape(groupKey: "glutes", muscle: "большая ягодичная", side: .back, build: blob(gluL)))
        s.append(MuscleShape(groupKey: "glutes", muscle: "большая ягодичная", side: .back, build: blob(mirrored(gluL))))

        // Hamstrings.
        let hamL: [(CGFloat, CGFloat)] = [(35,120),(47,121),(47,142),(45,158),(38,158),(34,140)]
        s.append(MuscleShape(groupKey: "legs", muscle: "бицепс бедра", side: .back, build: blob(hamL)))
        s.append(MuscleShape(groupKey: "legs", muscle: "бицепс бедра", side: .back, build: blob(mirrored(hamL))))

        // Calves (back).
        let calfL: [(CGFloat, CGFloat)] = [(36,162),(45,163),(46,180),(42,192),(38,190),(35,172)]
        s.append(MuscleShape(groupKey: "legs", muscle: "икроножная", side: .back, build: blob(calfL)))
        s.append(MuscleShape(groupKey: "legs", muscle: "икроножная", side: .back, build: blob(mirrored(calfL))))

        return s
    }()
}

// MARK: - Single anatomical body silhouette

private struct BodyView: View {
    let side: BodySide
    let levels: [String: String]        // groupKey -> level
    let muscleLevels: [String: String]  // muscle -> level (optional, level-2)
    let baseColor: Color
    var onSelect: ((String) -> Void)? = nil

    private var shapes: [MuscleShape] {
        side == .front ? MuscleShapeLibrary.front : MuscleShapeLibrary.back
    }

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
                // Body fill + subtle inner shading for a 3D-ish, mannequin feel (référence).
                silhouette(in: rect).fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.10), Color.white.opacity(0.045)],
                        startPoint: .top, endPoint: .bottom
                    )
                )

                // Muscle regions, coloured by intensity, following the body contour.
                ForEach(Array(shapes.enumerated()), id: \.offset) { _, shape in
                    let intensity = MuscleIntensity(level: level(for: shape))
                    let path = shape.build(rect)
                    // Filled region + a transparent tap target (interactivity, task §1.1).
                    path
                        .fill(intensity.color(base: baseColor))
                        .overlay(
                            path
                                .fill(Color.white.opacity(0.001))
                                .contentShape(path)
                                .onTapGesture { onSelect?(shape.groupKey) }
                        )
                }

                silhouette(in: rect).stroke(Color.white.opacity(0.16), lineWidth: 1.1)
            }
        }
        .aspectRatio(BodyCanvas.W / BodyCanvas.H, contentMode: .fit)
    }

    // Anatomical outline: head, neck, rounded shoulders, waist, hips, tapered thighs & calves —
    // built from smooth curves so it reads as a human figure, not stick limbs.
    private func silhouette(in rect: CGRect) -> Path {
        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { BodyCanvas.p(x, y, rect) }
        var path = Path()

        // Head + neck.
        path.addEllipse(in: CGRect(
            x: BodyCanvas.x(43, rect), y: BodyCanvas.y(4, rect),
            width: BodyCanvas.x(14, rect), height: BodyCanvas.y(17, rect)
        ))

        // Outline from neck, around the right side, down the right leg, across the feet,
        // up the left leg and back to the neck — one continuous curved silhouette.
        path.move(to: P(46, 20))
        // Neck → right shoulder (rounded).
        path.addQuadCurve(to: P(58, 30), control: P(54, 22))
        path.addQuadCurve(to: P(72, 44), control: P(70, 34))   // right deltoid cap
        // Right arm outer edge → wrist.
        path.addQuadCurve(to: P(84, 78), control: P(84, 58))
        path.addQuadCurve(to: P(83, 112), control: P(86, 96))
        path.addQuadCurve(to: P(78, 112), control: P(80, 114))
        // Right arm inner edge back up to armpit.
        path.addQuadCurve(to: P(72, 78), control: P(74, 96))
        path.addQuadCurve(to: P(66, 50), control: P(70, 60))
        // Torso right: waist in, hip out.
        path.addQuadCurve(to: P(63, 74), control: P(67, 62))    // waist
        path.addQuadCurve(to: P(70, 104), control: P(70, 90))   // hip
        // Right leg outer → ankle.
        path.addQuadCurve(to: P(66, 150), control: P(70, 128))  // thigh taper
        path.addQuadCurve(to: P(62, 196), control: P(66, 176))  // calf → ankle
        path.addQuadCurve(to: P(56, 196), control: P(59, 200))  // right foot
        // Right leg inner → crotch.
        path.addQuadCurve(to: P(54, 150), control: P(54, 176))
        path.addQuadCurve(to: P(50, 108), control: P(52, 128))
        // Left leg inner → ankle.
        path.addQuadCurve(to: P(46, 150), control: P(48, 128))
        path.addQuadCurve(to: P(44, 196), control: P(46, 176))
        path.addQuadCurve(to: P(38, 196), control: P(41, 200))  // left foot
        // Left leg outer → hip.
        path.addQuadCurve(to: P(34, 150), control: P(34, 176))
        path.addQuadCurve(to: P(30, 104), control: P(30, 128))
        // Torso left: hip → waist → armpit.
        path.addQuadCurve(to: P(37, 74), control: P(30, 90))
        path.addQuadCurve(to: P(34, 50), control: P(33, 62))
        // Left arm inner → wrist.
        path.addQuadCurve(to: P(28, 78), control: P(30, 60))
        path.addQuadCurve(to: P(22, 112), control: P(26, 96))
        path.addQuadCurve(to: P(17, 112), control: P(20, 114))
        // Left arm outer edge back up to shoulder.
        path.addQuadCurve(to: P(16, 78), control: P(14, 96))
        path.addQuadCurve(to: P(28, 44), control: P(16, 58))    // left deltoid cap
        path.addQuadCurve(to: P(42, 30), control: P(30, 34))
        path.addQuadCurve(to: P(46, 20), control: P(46, 22))    // back to neck
        path.closeSubpath()
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
    /// Optional tap handler — receives the tapped region's groupKey (interactivity, task §1.1).
    var onSelect: ((String) -> Void)? = nil

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
            BodyView(
                side: side,
                levels: levels,
                muscleLevels: muscleLevels,
                baseColor: baseColor,
                onSelect: onSelect
            )
            .frame(maxWidth: .infinity)
            .frame(height: 220)
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
