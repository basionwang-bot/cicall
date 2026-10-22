import SwiftUI

@main
struct CatilinaApp: App {
    @State private var store: TaskStore

    init() {
        _store = State(initialValue: TaskStore())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
    }
}
