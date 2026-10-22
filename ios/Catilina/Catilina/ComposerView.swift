import SwiftUI

struct ComposerView: View {
    @Environment(TaskStore.self) private var store

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SectionLabel(text: "任务")
                    CatilinaCard {
                        VStack(alignment: .leading, spacing: 6) {
                            FieldLabel(text: "标题")
                            TextField("这一条任务叫什么", text: $store.draftTitle)
                                .font(.system(size: 17))
                        }
                        .padding(16)
                        Divider().padding(.leading, 16)
                        VStack(alignment: .leading, spacing: 6) {
                            FieldLabel(text: "说明")
                            TextField("人要发布的任务", text: $store.draftBody, axis: .vertical)
                                .lineLimit(4...8)
                                .font(.system(size: 17))
                        }
                        .padding(16)
                    }

                    SectionLabel(text: "所选引擎")
                    CatilinaCard {
                        if store.selectedInOrder.isEmpty {
                            Text("还没选。到「引擎」页选择一个或多个。")
                                .font(.system(size: 17))
                                .foregroundStyle(.primary)
                                .padding(16)
                        } else {
                            ForEach(Array(store.selectedInOrder.enumerated()), id: \.element) { index, agent in
                                if index > 0 {
                                    Divider().padding(.leading, 16)
                                }
                                HStack(alignment: .firstTextBaseline) {
                                    Text(agent.displayName)
                                        .font(.system(size: 17))
                                    Spacer(minLength: 12)
                                    Text(store.registry.client(for: agent).availability.shortStatus)
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                        }
                    }

                    Button("去引擎页选择") {
                        store.tab = .roster
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 32)
                    .padding(.top, 10)

                    Footnote(text: AgentCopy.discriminationNote)

                    PrimaryButton(title: "发布任务", enabled: store.canPublish) {
                        store.publish()
                    }
                    .padding(.top, 16)

                    if let composeError = store.composeError {
                        Footnote(text: composeError, danger: true)
                    }

                    Footnote(text: AgentCopy.publishFootnote)
                        .padding(.bottom, 24)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("发布")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color(.systemGroupedBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}
