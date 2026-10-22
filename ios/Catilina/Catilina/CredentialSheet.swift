import SwiftUI

struct CredentialSheet: View {
    @Environment(TaskStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var routineField = ""
    @State private var tokenField = ""
    @State private var existingToken: String?
    @State private var errorMessage: String?
    @State private var savedNote: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Footnote(text: AgentCopy.credentialHelp)
                        .padding(.top, 8)
                    SectionLabel(text: "Routine")
                    CatilinaCard {
                        TextField("trig_… 或完整 fire URL", text: $routineField)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(size: 17))
                            .padding(16)
                    }
                    SectionLabel(text: "Bearer token")
                    CatilinaCard {
                        SecureField(tokenPlaceholder, text: $tokenField)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(size: 17))
                            .padding(16)
                    }
                    if let savedNote {
                        Footnote(text: savedNote)
                    }
                    if let errorMessage {
                        Footnote(text: errorMessage, danger: true)
                    }
                    PrimaryButton(title: "保存到钥匙串") {
                        save()
                    }
                    .padding(.top, 16)
                    Button("删除凭证", role: .destructive) {
                        deleteCredentials()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Claude Code 凭证")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .onAppear(perform: loadExisting)
    }

    private var tokenPlaceholder: String {
        existingToken == nil ? "sk-ant-oat01-…" : "留空则不修改"
    }

    private func loadExisting() {
        let client = ClaudeCodeClient()
        switch client.loadCredentials() {
        case .loaded(let routineID, let token):
            routineField = routineID
            existingToken = token
            savedNote = "已保存，末四位 \(suffix(token))。留空则不修改。"
        case .tokenMissing:
            savedNote = AgentCopy.claudeTokenMissing
        case .routineMissing:
            savedNote = AgentCopy.claudeRoutineMissing
            if let token = try? KeychainStore.get(account: KeychainStore.tokenAccount) {
                existingToken = token
            }
        case .unavailable(let message):
            errorMessage = message
        case .missing:
            savedNote = "尚未保存凭证。"
        }
        if routineField.isEmpty,
           let routine = try? KeychainStore.get(account: KeychainStore.routineAccount) {
            routineField = routine
        }
    }

    private func save() {
        let routine = routineField.trimmingCharacters(in: .whitespacesAndNewlines)
        if routine.localizedCaseInsensitiveContains("sk-ant-") {
            errorMessage = "这看起来像 token。token 要填在下一栏。没有保存。"
            return
        }
        guard ClaudeCodeEndpoint.fireURL(from: routine) != nil else {
            errorMessage = AgentCopy.claudeBadRoutine
            return
        }
        let typed = tokenField.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokenToStore: String
        if typed.isEmpty {
            guard let existingToken, !existingToken.isEmpty else {
                errorMessage = "还没有 token。没有保存。"
                return
            }
            tokenToStore = existingToken
        } else {
            guard ClaudeCodeEndpoint.isRoutineToken(typed) else {
                errorMessage = AgentCopy.claudeBadToken
                return
            }
            tokenToStore = typed
        }
        do {
            try KeychainStore.set(routine, account: KeychainStore.routineAccount)
            try KeychainStore.set(tokenToStore, account: KeychainStore.tokenAccount)
            existingToken = tokenToStore
            tokenField = ""
            errorMessage = nil
            savedNote = "已保存，末四位 \(suffix(tokenToStore))。留空则不修改。"
            store.credentialRevision += 1
        } catch let error as KeychainError {
            errorMessage = error.message
        } catch {
            errorMessage = AgentCopy.claudeKeychainUnavailable
        }
    }

    private func deleteCredentials() {
        do {
            try KeychainStore.remove(account: KeychainStore.routineAccount)
            try KeychainStore.remove(account: KeychainStore.tokenAccount)
            routineField = ""
            tokenField = ""
            existingToken = nil
            errorMessage = nil
            savedNote = "已从钥匙串删除。"
            store.credentialRevision += 1
        } catch let error as KeychainError {
            errorMessage = error.message
        } catch {
            errorMessage = AgentCopy.claudeKeychainUnavailable
        }
    }

    private func suffix(_ token: String) -> String {
        token.count >= 4 ? String(token.suffix(4)) : "••••"
    }
}
