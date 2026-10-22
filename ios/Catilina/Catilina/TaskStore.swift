import Foundation
import Observation

@MainActor
@Observable
final class TaskStore {
    private static let tasksKey = "bot.basionwang.catilina.tasks"
    private static let selectedKey = "bot.basionwang.catilina.selected"

    let registry = AgentRegistry()
    private let persists: Bool
    private let defaults: UserDefaults

    var tasks: [PublishedTask] = [] {
        didSet { persistTasks() }
    }

    var selected: Set<AgentKind> = [] {
        didSet { persistSelected() }
    }

    var draftTitle = ""
    var draftBody = ""
    var tab: AppTab = .compose
    var pendingSessionID: UUID?
    var composeError: String?
    var sendError: String?
    var isSending = false
    var credentialRevision = 0

    init(persists: Bool = true, defaults: UserDefaults = .standard) {
        self.persists = persists
        self.defaults = defaults
        if persists {
            load()
        }
    }

    var canPublish: Bool {
        !draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draftBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var selectedInOrder: [AgentKind] {
        AgentKind.allCases.filter { selected.contains($0) }
    }

    func selectionSummary() -> String {
        let names = selectedInOrder.map(\.displayName)
        if names.isEmpty {
            return "还没选。到「引擎」页选择一个或多个。"
        }
        return names.joined(separator: "、")
    }

    @discardableResult
    func publish() -> UUID? {
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = draftBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !body.isEmpty else {
            composeError = "先写标题和说明。"
            return nil
        }
        composeError = nil
        let task = PublishedTask(
            id: UUID(),
            title: title,
            instruction: body,
            createdAt: Date(),
            attempts: [:]
        )
        tasks.insert(task, at: 0)
        draftTitle = ""
        draftBody = ""
        pendingSessionID = task.id
        tab = .sessions
        return task.id
    }

    func updateInstruction(_ taskID: UUID, _ instruction: String) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        var task = tasks[index]
        task.instruction = instruction
        tasks[index] = task
    }

    func prepareSend(taskID: UUID) -> String? {
        guard let task = tasks.first(where: { $0.id == taskID }) else {
            return "找不到这条任务。"
        }
        if task.instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "先写远程指令。"
        }
        if selected.isEmpty {
            return "先在引擎页选择至少一个引擎。"
        }
        return nil
    }

    func willCallNetwork(taskID: UUID) -> Bool {
        guard let task = tasks.first(where: { $0.id == taskID }) else { return false }
        let instruction = RemoteInstruction(taskTitle: task.title, text: task.instruction)
        return selectedInOrder.contains { registry.client(for: $0).preflight(instruction) == nil }
    }

    func confirmMessage(taskID: UUID) -> String {
        willCallNetwork(taskID: taskID) ? AgentCopy.confirmNetwork : AgentCopy.confirmLocal
    }

    func send(taskID: UUID, allowNetwork: Bool = true) async {
        guard !isSending else { return }
        guard prepareSend(taskID: taskID) == nil else { return }
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        let instruction = RemoteInstruction(taskTitle: tasks[index].title, text: tasks[index].instruction)
        isSending = true
        defer { isSending = false }
        for agent in selectedInOrder {
            let client = registry.client(for: agent)
            let result: RemoteAttempt
            if let local = client.preflight(instruction) {
                result = local
            } else if !allowNetwork {
                result = .failed(message: AgentCopy.previewBlockedNetwork)
            } else {
                result = await client.send(instruction)
            }
            guard let current = tasks.firstIndex(where: { $0.id == taskID }) else { return }
            var task = tasks[current]
            task.attempts.removeAll { $0.agent == agent }
            task.attempts.append(
                AgentAttempt(
                    agent: agent,
                    instruction: instruction.trimmedText,
                    sentAt: Date(),
                    result: result
                )
            )
            tasks[current] = task
        }
    }

    func agentsToShow(for task: PublishedTask) -> [AgentKind] {
        AgentKind.allCases.filter { selected.contains($0) || task.attempt(for: $0) != nil }
    }

    func listSubtitle(for task: PublishedTask) -> String {
        if task.attempts.isEmpty {
            return AgentCopy.statusNotSent
        }
        let results = AgentKind.allCases.compactMap { task.attempt(for: $0)?.result }
        let created = results.reduce(into: 0) { count, result in
            if case .sessionCreated = result { count += 1 }
        }
        let failed = results.reduce(into: 0) { count, result in
            if case .failed = result { count += 1 }
        }
        let offline = results.reduce(into: 0) { count, result in
            if case .notConnected = result { count += 1 }
        }
        var parts: [String] = []
        if created > 0 { parts.append("已创建会话 \(created)") }
        if offline > 0 { parts.append("未连接 \(offline)") }
        if failed > 0 { parts.append("发送失败 \(failed)") }
        return parts.isEmpty ? AgentCopy.statusNotSent : parts.joined(separator: " · ")
    }

    private func load() {
        if let data = defaults.data(forKey: Self.tasksKey),
           let decoded = try? JSONDecoder().decode([PublishedTask].self, from: data) {
            tasks = decoded
        }
        if let raw = defaults.stringArray(forKey: Self.selectedKey) {
            selected = Set(raw.compactMap(AgentKind.init(rawValue:)))
        }
    }

    private func persistTasks() {
        guard persists, let data = try? JSONEncoder().encode(tasks) else { return }
        defaults.set(data, forKey: Self.tasksKey)
    }

    private func persistSelected() {
        guard persists else { return }
        defaults.set(selectedInOrder.map(\.rawValue), forKey: Self.selectedKey)
    }
}
