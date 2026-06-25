import SwiftUI

@main
struct LumenApp: App {
    @State private var model = LumenModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
    }
}
