import SwiftUI

struct RepositoryListView: View {
    @EnvironmentObject private var app: AppViewModel
    @State private var showingAddRepository = false
    @State private var testingRepositoryIDs = Set<String>()
    @State private var repositoryToRemove: BackupRepository?
    @State private var testMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(app.text(.repositories))
                    .font(.title2.weight(.semibold))
                Spacer()
                Button {
                    showingAddRepository = true
                } label: {
                    Label(app.text(.addRepository), systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }

            if app.repositories.isEmpty {
                EmptyStateView(
                    title: app.text(.noRepositoriesConfigured),
                    message: app.text(.noRepositoriesConfiguredMessage),
                    actionTitle: app.text(.addRepository)
                ) {
                    showingAddRepository = true
                }
            } else {
                if let testMessage {
                    Text(testMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                }

                List(app.repositories) { repo in
                    repositoryRow(repo)
                }
            }
        }
        .padding(24)
        .sheet(isPresented: $showingAddRepository) {
            AddRepositoryView()
                .environmentObject(app)
        }
        .task {
            await app.loadRepositories()
        }
        .alert(app.text(.removeRepository), isPresented: Binding(
            get: { repositoryToRemove != nil },
            set: { if !$0 { repositoryToRemove = nil } }
        )) {
            Button(app.text(.cancel), role: .cancel) {}
            Button(app.text(.remove), role: .destructive) {
                guard let repo = repositoryToRemove else { return }
                Task {
                    await app.removeRepository(repo)
                    repositoryToRemove = nil
                }
            }
        } message: {
            Text(repositoryToRemove?.name ?? "")
        }
    }

    private func repositoryRow(_ repo: BackupRepository) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(repo.name)
                        .font(.body.weight(.medium))
                    Text(repo.enabled ? app.text(.enabled) : app.text(.disabled))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(repo.enabled ? .green : .secondary)
                }
                Text(repo.location)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(app.text(.passwordEnv)): \(repo.passwordEnvKey ?? app.text(.notSet))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button {
                Task { await test(repo) }
            } label: {
                Label(
                    testingRepositoryIDs.contains(repo.id) ? app.text(.testing) : app.text(.testRepository),
                    systemImage: "checkmark.seal"
                )
            }
            .disabled(testingRepositoryIDs.contains(repo.id))

            Button {
                Task {
                    await app.setRepository(repo, enabled: !repo.enabled)
                }
            } label: {
                Label(repo.enabled ? app.text(.disable) : app.text(.enable), systemImage: repo.enabled ? "pause.circle" : "play.circle")
            }

            Button(role: .destructive) {
                repositoryToRemove = repo
            } label: {
                Image(systemName: "trash")
            }
            .help(app.text(.removeRepository))
        }
        .padding(.vertical, 6)
    }

    private func test(_ repo: BackupRepository) async {
        testingRepositoryIDs.insert(repo.id)
        defer { testingRepositoryIDs.remove(repo.id) }

        if let count = await app.testRepository(repo) {
            testMessage = "\(repo.name): \(app.text(.repositoryReady)) · \(count) \(app.text(.snapshots))"
        } else {
            testMessage = "\(repo.name): \(app.text(.repositoryTestFailed))"
        }
    }
}
