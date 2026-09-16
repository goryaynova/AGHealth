import Foundation

// Shared client-side muscle catalog: body part → its specific muscles, plus human labels.
// Mirrors the backend muscle-model (fitness/muscle-model.js): same canonical group keys and the
// same specific-muscle vocabulary the v2 catalog uses. This is the ONE place the create/edit forms
// and any muscle-name display read from — the picker "Часть тела → Мышца" is driven by it.

struct MusclePart: Identifiable, Hashable {
    let key: String          // canonical group key: chest/back/...
    let label: String        // human label: «Грудь»
    let muscles: [String]    // specific muscles within this part

    var id: String { key }
}

enum MuscleCatalog {
    // Order matches the analytics display order.
    static let parts: [MusclePart] = [
        MusclePart(key: "back", label: "Спина", muscles: [
            "широчайшие", "середина спины", "трапеция", "ромбовидные",
            "верх спины", "разгибатели позвоночника",
        ]),
        MusclePart(key: "chest", label: "Грудь", muscles: [
            "большая грудная", "верх груди", "низ груди",
        ]),
        MusclePart(key: "legs", label: "Ноги", muscles: [
            "квадрицепс", "бицепс бедра", "приводящие", "икроножная", "камбаловидная",
        ]),
        MusclePart(key: "glutes", label: "Ягодицы", muscles: [
            "большая ягодичная", "средняя ягодичная",
        ]),
        MusclePart(key: "shoulders", label: "Плечи", muscles: [
            "передняя дельта", "средняя дельта", "задняя дельта",
        ]),
        MusclePart(key: "arms", label: "Руки", muscles: [
            "бицепс", "трицепс", "брахиалис",
        ]),
        MusclePart(key: "core", label: "Кор", muscles: [
            "прямая мышца живота", "косые мышцы", "мышцы-стабилизаторы", "глубокие мышцы",
        ]),
        MusclePart(key: "forearms", label: "Предплечья", muscles: [
            "сгибатели", "разгибатели", "хват",
        ]),
    ]

    static func part(forKey key: String) -> MusclePart? {
        parts.first { $0.key == key }
    }

    static func label(forKey key: String) -> String {
        part(forKey: key)?.label ?? key
    }

    static func muscles(forKey key: String) -> [String] {
        part(forKey: key)?.muscles ?? []
    }
}
