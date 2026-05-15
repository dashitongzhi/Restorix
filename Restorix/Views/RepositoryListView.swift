import SwiftUI

struct RepositoryListView: View {
    @EnvironmentObject private var app: AppViewModel
    @State private var showingAddRepository = false

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
                List(app.repositories) { repo in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(repo.name)
                                .font(.body.weight(.medium))
                            Spacer()
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
                    .padding(.vertical, 6)
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
    }
}
