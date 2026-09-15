import SwiftUI

// Body muscle map: front + back stylised human silhouettes with muscle groups highlighted by how
// much they were trained in the last 7 days. Built entirely with SwiftUI Shapes/Canvas — no third
// party framework, no external asset. Designed to be extended: each muscle group is one entry in
// `MuscleShapeLibrary`, so adding/refining a region is a local change.
//
// Input is a `[groupKey: level]` map (level = "high" | "medium" | "low" | "none"), matching the
// backend muscle-summary group keys. Groups not present, or "none", render neutral.

enum MuscleIntensity: String {
    case none, low, medium, high

    init(level: String?) {
        self = MuscleIntensity(rawValue: level ?? "none") ?? .none
    }

    /// Fill colour for a region at this intensity. Neutral (muted) when untrained.
    func color(base: Color) -> Color {
        switch self {
        case .none: return Color.white.opacity(0.06)
        case .low: return base.opacity(0.35)
        case .medium: return base.opacity(0.62)
        case .high: return base.opacity(0.95)
        }
    }
}

// A muscle region drawn on a normalized 100 (w) × 220 (h) canvas, per body side.
private struct MuscleShape {
    let groupKey: String
    let side: BodySide
    let path: (CGRect) -> Path
}

enum BodySide {
    case front, back
}

// MARK: - Shape library (normalized 100×220 coordinate space)

private enum MuscleShapeLibrary {
    static let W: CGFloat = 100
    static let H: CGFloat = 220

    // Helper builders on the normalized canvas.
    private static func ellipse(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> (CGRect) -> Path {
        { rect in
            let sx = rect.width / W
            let sy = rect.height / H
            return Path(ellipseIn: CGRect(x: x * sx, y: y * sy, width: w * sx, height: h * sy))
        }
    }

    private static func roundedRect(
        _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat = 4
    ) -> (CGRect) -> Path {
        { rect in
            let sx = rect.width / W
            let sy = rect.height / H
            return Path(
                roundedRect: CGRect(x: x * sx, y: y * sy, width: w * sx, height: h * sy),
                cornerRadius: r * min(sx, sy)
            )
        }
    }

    // FRONT view regions.
    static let front: [MuscleShape] = [
        // Shoulders (front delts) — two caps at the top of the arms.
        MuscleShape(groupKey: "shoulders", side: .front, path: ellipse(24, 44, 16, 14)),
        MuscleShape(groupKey: "shoulders", side: .front, path: ellipse(60, 44, 16, 14)),
        // Chest — two pecs.
        MuscleShape(groupKey: "chest", side: .front, path: roundedRect(34, 52, 14, 16, 5)),
        MuscleShape(groupKey: "chest", side: .front, path: roundedRect(52, 52, 14, 16, 5)),
        // Arms (biceps) — upper arms.
        MuscleShape(groupKey: "arms", side: .front, path: roundedRect(20, 60, 8, 26, 4)),
        MuscleShape(groupKey: "arms", side: .front, path: roundedRect(72, 60, 8, 26, 4)),
        // Forearms.
        MuscleShape(groupKey: "forearms", side: .front, path: roundedRect(18, 88, 7, 22, 3)),
        MuscleShape(groupKey: "forearms", side: .front, path: roundedRect(75, 88, 7, 22, 3)),
        // Core — abs.
        MuscleShape(groupKey: "core", side: .front, path: roundedRect(40, 72, 20, 30, 5)),
        // Legs (quads) — thighs front.
        MuscleShape(groupKey: "legs", side: .front, path: roundedRect(34, 116, 13, 44, 6)),
        MuscleShape(groupKey: "legs", side: .front, path: roundedRect(53, 116, 13, 44, 6)),
    ]

    // BACK view regions.
    static let back: [MuscleShape] = [
        // Shoulders (rear delts) + traps hint.
        MuscleShape(groupKey: "shoulders", side: .back, path: ellipse(24, 44, 16, 14)),
        MuscleShape(groupKey: "shoulders", side: .back, path: ellipse(60, 44, 16, 14)),
        // Back — lats/upper back as one big region.
        MuscleShape(groupKey: "back", side: .back, path: roundedRect(34, 52, 32, 34, 7)),
        // Arms (triceps).
        MuscleShape(groupKey: "arms", side: .back, path: roundedRect(20, 60, 8, 26, 4)),
        MuscleShape(groupKey: "arms", side: .back, path: roundedRect(72, 60, 8, 26, 4)),
        // Forearms.
        MuscleShape(groupKey: "forearms", side: .back, path: roundedRect(18, 88, 7, 22, 3)),
        MuscleShape(groupKey: "forearms", side: .back, path: roundedRect(75, 88, 7, 22, 3)),
        // Glutes.
        MuscleShape(groupKey: "glutes", side: .back, path: roundedRect(34, 100, 32, 18, 7)),
        // Legs (hamstrings + calves) — thighs + lower legs back.
        MuscleShape(groupKey: "legs", side: .back, path: roundedRect(34, 120, 13, 40, 6)),
        MuscleShape(groupKey: "legs", side: .back, path: roundedRect(53, 120, 13, 40, 6)),
        MuscleShape(groupKey: "legs", side: .back, path: roundedRect(35, 162, 11, 30, 5)),
        MuscleShape(groupKey: "legs", side: .back, path: roundedRect(54, 162, 11, 30, 5)),
    ]
}

// MARK: - Single body silhouette

private struct BodyView: View {
    let side: BodySide
    let levels: [String: String] // groupKey -> level
    let baseColor: Color

    private var shapes: [MuscleShape] {
        side == .front ? MuscleShapeLibrary.front : MuscleShapeLibrary.back
    }

    var body: some View {
        GeometryReader { geo in
            let rect = CGRect(origin: .zero, size: geo.size)
            ZStack {
                // Base silhouette.
                silhouette(in: rect)
                    .fill(Color.white.opacity(0.05))
                silhouette(in: rect)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)

                // Muscle regions.
                ForEach(Array(shapes.enumerated()), id: \.offset) { _, shape in
                    let intensity = MuscleIntensity(level: levels[shape.groupKey])
                    shape.path(rect)
                        .fill(intensity.color(base: baseColor))
                }
            }
        }
        .aspectRatio(MuscleShapeLibrary.W / MuscleShapeLibrary.H, contentMode: .fit)
    }

    // A simple humanoid outline on the same normalized canvas.
    private func silhouette(in rect: CGRect) -> Path {
        let sx = rect.width / MuscleShapeLibrary.W
        let sy = rect.height / MuscleShapeLibrary.H

        var path = Path()
        // Head.
        path.addEllipse(in: CGRect(x: 42 * sx, y: 8 * sy, width: 16 * sx, height: 18 * sy))
        // Torso + limbs as a rounded blob built from a few rects (kept simple/robust).
        path.addRoundedRect(
            in: CGRect(x: 30 * sx, y: 40 * sy, width: 40 * sx, height: 70 * sy),
            cornerSize: CGSize(width: 12 * sx, height: 12 * sy)
        )
        // Arms.
        path.addRoundedRect(
            in: CGRect(x: 16 * sx, y: 42 * sy, width: 12 * sx, height: 70 * sy),
            cornerSize: CGSize(width: 6 * sx, height: 6 * sy)
        )
        path.addRoundedRect(
            in: CGRect(x: 72 * sx, y: 42 * sy, width: 12 * sx, height: 70 * sy),
            cornerSize: CGSize(width: 6 * sx, height: 6 * sy)
        )
        // Legs.
        path.addRoundedRect(
            in: CGRect(x: 32 * sx, y: 112 * sy, width: 16 * sx, height: 96 * sy),
            cornerSize: CGSize(width: 7 * sx, height: 7 * sy)
        )
        path.addRoundedRect(
            in: CGRect(x: 52 * sx, y: 112 * sy, width: 16 * sx, height: 96 * sy),
            cornerSize: CGSize(width: 7 * sx, height: 7 * sy)
        )
        return path
    }
}

// MARK: - Public muscle map (front + back side by side)

struct MuscleMapView: View {
    /// groupKey -> level ("high"/"medium"/"low"/"none").
    let levels: [String: String]
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
            BodyView(side: side, levels: levels, baseColor: baseColor)
                .frame(maxWidth: .infinity)
                .frame(height: 200)
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
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 12, height: 12)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(AGContentColors.secondaryText)
        }
    }
}
