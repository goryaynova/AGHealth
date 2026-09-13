import SwiftUI

enum AGContentColors {
    static let background = Color.black

    static let card = Color(
        red: 0.075,
        green: 0.075,
        blue: 0.085
    )

    static let cardSecondary = Color(
        red: 0.11,
        green: 0.11,
        blue: 0.12
    )

    static let separator = Color.white.opacity(0.08)

    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.58)
    static let tertiaryText = Color.white.opacity(0.36)

    static let accent = Color.blue
    static let green = Color.green
    static let orange = Color.orange
    static let red = Color.red
    static let purple = Color.purple
}

struct ProgressBar: View {
    let progress: Double
    let color: Color
    var height: CGFloat = 7

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))

                Capsule()
                    .fill(color)
                    .frame(
                        width: max(
                            0,
                            geometry.size.width
                                * min(
                                    max(progress, 0),
                                    1
                                )
                        )
                    )
            }
        }
        .frame(height: height)
    }
}

func formattedDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ru_RU")
    formatter.dateFormat = "d MMMM"
    return formatter.string(from: date)
}

func formattedWeekday(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ru_RU")
    formatter.dateFormat = "EEEE"
    return formatter.string(from: date).capitalized
}
