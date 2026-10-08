import SwiftUI

@main
struct PlantCareApp: App {
    @StateObject private var history = HistoryStore()
    @StateObject private var rooms = RoomStore()
    @StateObject private var lang = LanguageManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(history)
                .environmentObject(rooms)
                .environmentObject(lang)
                .tint(Theme.leafDeep)
        }
    }
}
