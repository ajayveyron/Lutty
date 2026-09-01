import SwiftUI

@main
struct LuttyApp: App {
    @State private var lutStore = LUTStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(lutStore)
        }
    }
}
