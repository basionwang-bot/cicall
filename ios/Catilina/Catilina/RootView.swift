import SwiftUI

struct RootView: View {
    @Environment(TaskStore.self) private var store

    var body: some View {
        @Bindable var store = store
        TabView(selection: $store.tab) {
            ComposerView()
                .tabItem { Label("发布", systemImage: "square.and.pencil") }
                .tag(AppTab.compose)
            RosterView()
                .tabItem { Label("引擎", systemImage: "person.2") }
                .tag(AppTab.roster)
            SessionsView()
                .tabItem { Label("会话", systemImage: "bubble.left.and.bubble.right") }
                .tag(AppTab.sessions)
        }
        .tint(CatilinaColor.accent)
    }
}
