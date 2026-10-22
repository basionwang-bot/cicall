import SwiftUI

struct RosterView: View {
    @Environment(TaskStore.self) private var store
    @State private var showingCredentials = false

    var body: some View {
        @Bindable var store = store
        let _ = store.credentialRevision
        let _ = store.selected
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(AgentCopy.rosterIntro)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 32)
                        .padding(.top, 8)

                    ForEach(AgentKind.allCases) { agent in
                        let client = store.registry.client(for: agent)
                        CatilinaCard {
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(agent.displayName)
                                        .font(.system(size: 17, weight: .semibold))
                                    Text(agent.blurb)
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 8)
                                Toggle(agent.displayName, isOn: selection(agent))
                                    .labelsHidden()
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 14)
                            .padding(.bottom, 8)

                            Text(client.availability.reason)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 16)
                                .padding(.bottom, agent == .claudeCode ? 8 : 14)

                            if agent == .claudeCode {
                                Button("Claude Code 凭证") {
                                    showingCredentials = true
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .padding(.horizontal, 16)
                                .padding(.bottom, 14)
                            }
                        }
                    }
                }
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("引擎")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color(.systemGroupedBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showingCredentials) {
                CredentialSheet()
            }
        }
    }

    private func selection(_ agent: AgentKind) -> Binding<Bool> {
        Binding(
            get: { store.selected.contains(agent) },
            set: { isOn in
                if isOn {
                    store.selected.insert(agent)
                } else {
                    store.selected.remove(agent)
                }
            }
        )
    }
}
