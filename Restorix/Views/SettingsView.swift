import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var app: AppViewModel
    @State private var staleHours = 72
    @State private var looseMatching = false
    @State private var notificationsEnabled = false
    @State private var cliPath = ""

    var body: some View {
        Form {
            Section(app.text(.language)) {
                Picker(app.text(.language), selection: Binding(
                    get: { app.language },
                    set: { app.setLanguage($0) }
                )) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(app.text(.scanSettings)) {
                Stepper(value: $staleHours, in: 1...720) {
                    Text("\(app.text(.staleThreshold)): \(staleHours) \(app.text(.hours))")
                }
                Toggle(app.text(.looseMatching), isOn: $looseMatching)
                Toggle(app.text(.localNotifications), isOn: $notificationsEnabled)
            }

            Section(app.text(.cli)) {
                TextField(app.text(.cliPath), text: $cliPath)
                Text(app.text(.cliHint))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button(app.text(.saveSettings)) {
                    Task {
                        await save()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .formStyle(.grouped)
        .padding(24)
        .task {
            await app.loadConfig()
            syncFromSettings()
        }
        .onChange(of: app.settings?.staleHours) { _, _ in syncFromSettings() }
    }

    private func syncFromSettings() {
        guard let settings = app.settings else { return }
        staleHours = settings.staleHours
        looseMatching = settings.looseMatching
        notificationsEnabled = settings.notificationsEnabled
        cliPath = settings.cliPath
    }

    private func save() async {
        await app.setConfig(key: "stale_hours", value: String(staleHours))
        await app.setConfig(key: "loose_matching", value: looseMatching ? "true" : "false")
        await app.setConfig(key: "notifications_enabled", value: notificationsEnabled ? "true" : "false")
        await app.setConfig(key: "cli_path", value: cliPath)
    }
}
