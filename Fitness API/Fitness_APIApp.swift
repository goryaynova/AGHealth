//
//  Fitness_APIApp.swift
//  Fitness API
//
//  Created by Анна Горяйнова on 08.09.2026.
//

import SwiftUI

@main
struct Fitness_APIApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Синхронизация при запуске — асинхронно, не блокирует UI (только новые данные).
                .task {
                    SyncManager.shared.syncOnLaunchIfNeeded()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            // При возвращении в активное состояние — догрузить новое (не чаще раза в 30 мин).
            if phase == .active {
                SyncManager.shared.syncOnLaunchIfNeeded()
            }
        }
    }
}
