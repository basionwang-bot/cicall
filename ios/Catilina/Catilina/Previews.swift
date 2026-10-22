import SwiftUI

@MainActor
private struct ComposerPreview: View {
    @State private var store: TaskStore

    init() {
        let store = TaskStore(persists: false)
        store.selected = Set(AgentKind.allCases)
        store.draftTitle = PreviewData.title
        store.draftBody = PreviewData.instruction
        store.tab = .compose
        _store = State(initialValue: store)
    }

    var body: some View {
        RootView().environment(store)
    }
}

@MainActor
private struct RosterPreview: View {
    @State private var store: TaskStore

    init() {
        let store = TaskStore(persists: false)
        store.selected = Set(AgentKind.allCases)
        store.tab = .roster
        _store = State(initialValue: store)
    }

    var body: some View {
        RootView().environment(store)
    }
}

@MainActor
private struct SessionPreview: View {
    @State private var store: TaskStore
    private let taskID: UUID

    init() {
        let store = TaskStore(persists: false)
        store.selected = Set(AgentKind.allCases)
        store.draftTitle = PreviewData.title
        store.draftBody = PreviewData.instruction
        let id = store.publish() ?? UUID()
        _store = State(initialValue: store)
        taskID = id
    }

    var body: some View {
        RootView()
            .environment(store)
            .task { await store.send(taskID: taskID, allowNetwork: false) }
    }
}

#Preview("Composer") {
    ComposerPreview()
}

#Preview("Roster") {
    RosterPreview()
}

#Preview("Session") {
    SessionPreview()
}
