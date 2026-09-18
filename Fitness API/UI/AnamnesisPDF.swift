import UIKit

// Генератор красивого PDF-шаблона медицинской карты (анамнеза). Возвращает URL временного файла.
enum AnamnesisPDF {
    static func build(
        a: APIClient.Anamnesis,
        weightKg: Double?,
        heightCm: Double?,
        visionText: String?,
        medsById: [String: String]
    ) -> URL {
        let pageW: CGFloat = 595.2   // A4 @72dpi
        let pageH: CGFloat = 841.8
        let margin: CGFloat = 48
        let contentW = pageW - margin * 2

        let format = UIGraphicsPDFRendererFormat()
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH), format: format)

        let accent = UIColor(red: 0.20, green: 0.48, blue: 0.96, alpha: 1)
        let dark = UIColor(red: 0.10, green: 0.12, blue: 0.16, alpha: 1)
        let gray = UIColor(red: 0.42, green: 0.45, blue: 0.50, alpha: 1)
        let lightBg = UIColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Анамнез.pdf")

        try? renderer.writePDF(to: url) { ctx in
            ctx.beginPage()
            let cg = ctx.cgContext
            var y: CGFloat = margin

            // Шапка
            let headerRect = CGRect(x: 0, y: 0, width: pageW, height: 96)
            cg.setFillColor(accent.cgColor)
            cg.fill(headerRect)
            drawText("Медицинская карта", at: CGPoint(x: margin, y: 30), font: .boldSystemFont(ofSize: 24), color: .white)
            drawText(a.fullName ?? "Пациент", at: CGPoint(x: margin, y: 62), font: .systemFont(ofSize: 15), color: UIColor(white: 1, alpha: 0.9))
            let df = DateFormatter(); df.locale = Locale(identifier: "ru_RU"); df.dateFormat = "d MMMM yyyy"
            let dateStr = "Сформировано: \(df.string(from: Date()))"
            drawText(dateStr, at: CGPoint(x: pageW - margin - 200, y: 66), font: .systemFont(ofSize: 10), color: UIColor(white: 1, alpha: 0.85), width: 200, align: .right)
            y = 120

            func section(_ title: String, rows: [(String, String)]) {
                let visible = rows.filter { !$0.1.isEmpty }
                guard !visible.isEmpty else { return }
                // Заголовок секции
                drawText(title.uppercased(), at: CGPoint(x: margin, y: y), font: .boldSystemFont(ofSize: 11), color: accent)
                y += 20
                // Плашка со строками
                let rowH: CGFloat = 22
                let boxH = rowH * CGFloat(visible.count) + 12
                let box = CGRect(x: margin, y: y, width: contentW, height: boxH)
                let path = UIBezierPath(roundedRect: box, cornerRadius: 10)
                cg.setFillColor(lightBg.cgColor); cg.addPath(path.cgPath); cg.fillPath()
                var ry = y + 8
                for (k, v) in visible {
                    drawText(k, at: CGPoint(x: margin + 14, y: ry), font: .systemFont(ofSize: 12), color: gray, width: 170)
                    drawText(v, at: CGPoint(x: margin + 190, y: ry), font: .systemFont(ofSize: 12), color: dark, width: contentW - 200)
                    ry += rowH
                }
                y += boxH + 16
            }

            func textBlock(_ title: String, lines: [String]) {
                let visible = lines.filter { !$0.isEmpty }
                guard !visible.isEmpty else { return }
                drawText(title.uppercased(), at: CGPoint(x: margin, y: y), font: .boldSystemFont(ofSize: 11), color: accent)
                y += 20
                for line in visible {
                    // маркер
                    cg.setFillColor(accent.cgColor)
                    cg.fillEllipse(in: CGRect(x: margin + 2, y: y + 5, width: 4, height: 4))
                    let h = drawText(line, at: CGPoint(x: margin + 16, y: y), font: .systemFont(ofSize: 12), color: dark, width: contentW - 20)
                    y += max(h, 16) + 6
                }
                y += 10
            }

            section("Общее", rows: [
                ("ФИО", a.fullName ?? ""),
                ("Пол", a.sex ?? ""),
                ("Возраст", a.age.map { "\($0)" } ?? ""),
            ])
            section("Кровь", rows: [
                ("Группа крови", [a.bloodGroup, a.rhFactor].compactMap { $0 }.joined(separator: " ")),
                ("ВИЧ/СПИД", a.hivStatus ?? ""),
            ])
            section("Тело", rows: [
                ("Вес", weightKg.map { "\(fmt($0)) кг" } ?? ""),
                ("Рост", heightCm.map { "\(fmt($0)) см" } ?? ""),
                ("Зрение", visionText ?? ""),
            ])
            section("Образ жизни", rows: [
                ("Активность", a.lifestyle ?? ""),
                ("Вредные привычки", habits(a)),
            ])

            if let chronic = a.chronic?.filter({ !$0.name.isEmpty }), !chronic.isEmpty {
                textBlock("Хронические заболевания", lines: chronic.map { c in
                    var s = c.name
                    if let d = c.date, !d.isEmpty { s += " · с \(d)" }
                    if let t = c.treatment, !t.isEmpty { s += " · \(t)" }
                    if let mid = c.medicationId, let name = medsById[mid] { s += " · препарат: \(name)" }
                    return s
                })
            }
            if let sports = a.sports?.filter({ !$0.isEmpty }), !sports.isEmpty {
                textBlock("Спорт", lines: [sports.joined(separator: ", ")])
            }
            if let surgeries = a.surgeries?.filter({ !$0.name.isEmpty }), !surgeries.isEmpty {
                textBlock("Перенесённые операции", lines: surgeries.map { s in
                    var t = s.name
                    if let d = s.date, !d.isEmpty { t += " · \(d)" }
                    if let ds = s.description, !ds.isEmpty { t += " · \(ds)" }
                    return t
                })
            }

            // Футер
            drawText("AGHealth · личная медицинская карта", at: CGPoint(x: margin, y: pageH - 40),
                     font: .systemFont(ofSize: 9), color: gray, width: contentW, align: .center)
        }

        return url
    }

    private static func habits(_ a: APIClient.Anamnesis) -> String {
        guard let h = a.habits else { return "" }
        var parts: [String] = []
        if h.alcohol == true { parts.append("алкоголь") }
        if h.smoking == true { parts.append("курение") }
        if h.drugs == true { parts.append("наркотики") }
        return parts.isEmpty ? "нет" : parts.joined(separator: ", ")
    }

    private static func fmt(_ v: Double) -> String {
        String(format: "%g", v).replacingOccurrences(of: ".", with: ",")
    }

    // Рисует текст, возвращает высоту нарисованного блока.
    @discardableResult
    private static func drawText(_ text: String, at point: CGPoint, font: UIFont, color: UIColor,
                                 width: CGFloat = 400, align: NSTextAlignment = .left) -> CGFloat {
        let para = NSMutableParagraphStyle(); para.alignment = align
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: para]
        let rect = CGRect(x: point.x, y: point.y, width: width, height: 1000)
        let bounding = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs, context: nil)
        (text as NSString).draw(with: CGRect(x: point.x, y: point.y, width: width, height: ceil(bounding.height)),
                                options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs, context: nil)
        _ = rect
        return ceil(bounding.height)
    }
}
