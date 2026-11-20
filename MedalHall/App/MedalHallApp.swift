import SwiftUI

@main
struct MedalHallApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
                .tint(Theme.blue)
        }
    }
}
