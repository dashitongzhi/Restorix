import SwiftUI

struct AddRepositoryView: View {
    @EnvironmentObject private var app: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var location = ""
    @State private var passwordEnvKey = "RESTIC_PASSWORD"
    @State private var enabled = true

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(app.text(.addRepository))
                .font(.title2.weight(.semibold))

            Form {
                TextField(app.text(.name), text: $name)
                TextField(app.text(.repositoryLocation), text: $location)
                TextField(app.text(.passwordEnv), text: $passwordEnvKey)
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
                    Task {
                        await app.addRepository(
                            name: name,
                            location: location,
                            passwordEnvKey: passwordEnvKey,
                            enabled: enabled
                        )
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 520)
    }
}
