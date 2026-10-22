import SwiftUI

struct SessionsView: View {
    @Environment(TaskStore.self) private var store
    @State private var path = NavigationPath()

    var body: some View {
        @Bindable var store = store
        NavigationStack(path: $path) {
            ScrollView {
                if store.tasks.isEmpty {
                    Text(AgentCopy.emptySessions)
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 48)
                } else {
                    VStack(spacing: 12) {
                        ForEach(store.tasks) { task in
                            NavigationLink(value: task.id) {
                                CatilinaCard {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(task.title)
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundStyle(.primary)
                                        Text(store.listSubtitle(for: task))
                                            .font(.system(size: 13))
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(16)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("会话")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color(.systemGroupedBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationDestination(for: UUID.self) { id in
                SessionView(taskID: id)
            }
        }
        .onAppear(perform: openPending)
        .onChange(of: store.pendingSessionID) { _, _ in
            openPending()
        }
    }

    private func openPending() {
        guard let id = store.pendingSessionID else { return }
        store.pendingSessionID = nil
        path.append(id)
    }
}

struct SessionView: View {
    @Environment(TaskStore.self) private var store
    let taskID: UUID
    @State private var confirmSend = false
    @State private var approvalAck: [AgentKind: String] = [:]

    private var task: PublishedTask? {
        store.tasks.first { $0.id == taskID }
    }

    var body: some View {
        @Bindable var store = store
        Group {
            if let task {
                session(task)
            } else {
                ContentUnavailableView("找不到这条任务", systemImage: "questionmark.circle")
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(task?.title ?? "会话")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(.systemGroupedBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .alert("发送远程指令？", isPresented: $confirmSend) {
            Button("发送") {
                Task { await store.send(taskID: taskID) }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(store.confirmMessage(taskID: taskID))
        }
    }

    @ViewBuilder
    private func session(_ task: PublishedTask) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                CatilinaCard {
                    VStack(alignment: .leading, spacing: 8) {
                        FieldLabel(text: "远程指令")
                        TextField(
                            "发给所选引擎的指令",
                            text: instructionBinding,
                            axis: .vertical
                        )
                        .lineLimit(3...8)
                        .font(.system(size: 17))
                        Text(audienceLine)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                }
                .padding(.top, 12)

                PrimaryButton(
                    title: store.isSending ? "正在发送…" : (task.attempts.isEmpty ? "发送到所选引擎" : "再次发送"),
                    enabled: !store.isSending
                ) {
                    if let error = store.prepareSend(taskID: taskID) {
                        store.sendError = error
                    } else {
                        store.sendError = nil
                        confirmSend = true
                    }
                }
                .padding(.top, 16)

                if !task.attempts.isEmpty {
                    Footnote(text: AgentCopy.retryCaption)
                }
                if let sendError = store.sendError {
                    Footnote(text: sendError, danger: true)
                }
                Footnote(text: AgentCopy.discriminationNote)

                SectionLabel(text: "各引擎")
                VStack(spacing: 12) {
                    ForEach(store.agentsToShow(for: task)) { agent in
                        agentCard(agent, task: task)
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var audienceLine: String {
        if store.selectedInOrder.isEmpty {
            return "还没有选引擎。"
        }
        return "发给：" + store.selectedInOrder.map(\.displayName).joined(separator: "、")
    }

    private var instructionBinding: Binding<String> {
        Binding(
            get: { store.tasks.first { $0.id == taskID }?.instruction ?? "" },
            set: { store.updateInstruction(taskID, $0) }
        )
    }

    private func agentCard(_ agent: AgentKind, task: PublishedTask) -> some View {
        let client = store.registry.client(for: agent)
        let result = task.attempt(for: agent)?.result
        return CatilinaCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    Text(agent.displayName)
                        .font(.system(size: 17, weight: .semibold))
                    Spacer(minLength: 8)
                    StatusCapsule(result: result)
                }
                block(title: "状态", text: client.statusDetail(for: result))
                block(title: "审批", text: client.approvalNote(for: result))
                Button("批准") {
                    approvalAck[agent] = "没有批准。\(client.approvalNote(for: result))"
                }
                .font(.system(size: 15, weight: .semibold))
                .buttonStyle(.bordered)
                .tint(CatilinaColor.accent)
                if let ack = approvalAck[agent] {
                    Text(ack)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if case .sessionCreated(_, let url) = result,
                   let link = ClaudeCodeEndpoint.acceptedSessionURL(url) {
                    Link("打开会话", destination: link)
                        .font(.system(size: 15, weight: .semibold))
                }
                block(title: "结果", text: client.resultSummary(for: result))
            }
            .padding(16)
        }
    }

    private func block(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
