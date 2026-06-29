import AppKit
import SwiftUI

struct AddRepositoryView: View {
    @EnvironmentObject private var app: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var location = ""
    @State private var passwordEnvKey = "RESTIC_PASSWORD"
    @State private var enabled = true
    @FocusState private var focusedField: Field?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(app.text(.addRepository))
                .font(.title2.weight(.semibold))

            Form {
                TextField(app.text(.name), text: $name)
                    .focused($focusedField, equals: .name)
                HStack {
                    TextField(app.text(.repositoryLocation), text: $location)
                        .focused($focusedField, equals: .location)
                    Button(app.text(.chooseFolder)) {
                        chooseRepositoryLocation()
                    }
                }
                TextField(app.text(.passwordEnv), text: $passwordEnvKey)
                    .focused($focusedField, equals: .passwordEnvKey)
                Toggle(app.text(.enabled), isOn: $enabled)
            }
            .formStyle(.grouped)

            Text(app.text(.envNameOnly))
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button(app.text(.cancel)) {
                    dismiss()
                }
                Button(app.text(.add)) {
                    addRepository()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canAdd)
            }
        }
        .padding(24)
        .frame(width: 520)
        .onAppear {
            focusedField = .name
        }
        .onSubmit {
            if canAdd {
                addRepository()
            }
        }
    }

    private var canAdd: Bool {
        !trimmedName.isEmpty && !trimmedLocation.isEmpty
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedLocation: String {
        location.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedPasswordEnvKey: String? {
        let value = passwordEnvKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func addRepository() {
        Task {
            await app.addRepository(
                name: trimmedName,
                location: trimmedLocation,
                passwordEnvKey: trimmedPasswordEnvKey,
                enabled: enabled
            )
            dismiss()
        }
    }

    private func chooseRepositoryLocation() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = app.text(.chooseFolder)

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        location = url.path
    }
}

private enum Field {
    case name
    case location
    case passwordEnvKey
}
