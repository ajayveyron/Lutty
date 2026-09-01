import SwiftUI

@main
struct LuttyApp: App {
    @State private var lutStore = LUTStore()
    @State private var presetStore = PresetStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(lutStore)
                .environment(presetStore)
        }
    }
}
