import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeSectionView()
                .tabItem {
                    Label("Главная", systemImage: "house.fill")
                }

            WorkoutsSectionView()
                .tabItem {
                    Label("Тренировки", systemImage: "figure.strengthtraining.traditional")
                }

            NutritionSectionView()
                .tabItem {
                    Label("Питание", systemImage: "fork.knife")
                }

            HealthSectionView()
                .tabItem {
                    Label("Здоровье", systemImage: "heart.text.square.fill")
                }

            MoreSectionView()
                .tabItem {
                    Label("Ещё", systemImage: "ellipsis")
                }
        }
        .tint(AGContentColors.accent)
        .preferredColorScheme(.dark)
    }
}
