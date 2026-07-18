import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var app: AppViewModel
    @State private var staleHours = 72
    @State private var looseMatching = false
    @State private var showDockIcon = true
    @State private var launchAtLogin = false
    @State private var notificationsEnabled = false
    @State private var cliPath = ""

    private let iconColumns = [
        GridItem(.adaptive(minimum: 112, maximum: 128), spacing: 12)
    ]

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

            Section(app.text(.appIcon)) {
                LazyVGrid(columns: iconColumns, alignment: .leading, spacing: 12) {
                    ForEach(AppIconChoice.chooserChoices) { icon in
                        IconChoiceButton(
                            icon: icon,
                            isSelected: app.selectedAppIcon == icon,
                            title: app.text(icon.titleKey)
                        ) {
                            app.selectAppIcon(icon)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section(app.text(.scanSettings)) {
                Stepper(value: $staleHours, in: 1...720) {
                    Text("\(app.text(.staleThreshold)): \(staleHours) \(app.text(.hours))")
                }
                Toggle(app.text(.looseMatching), isOn: $looseMatching)
                Toggle(app.text(.localNotifications), isOn: $notificationsEnabled)
                Toggle(app.text(.showDockIcon), isOn: $showDockIcon)
                Toggle(app.text(.launchAtLogin), isOn: $launchAtLogin)
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
                .disabled(app.isCommittingSettings)
            }
        }
        .formStyle(.grouped)
        .padding(24)
        .task {
            await app.loadConfig()
            syncFromSettings()
        }
        .onChange(of: app.settings?.staleHours) { _, _ in syncFromSettings() }
        .onChange(of: app.settings?.launchAtLogin) { _, _ in syncFromSettings() }
    }

    private func syncFromSettings() {
        guard let settings = app.settings else { return }
        staleHours = settings.staleHours
        looseMatching = settings.looseMatching
        showDockIcon = settings.showDockIcon
        launchAtLogin = settings.launchAtLogin
        notificationsEnabled = settings.notificationsEnabled
        cliPath = settings.cliPath
    }

    private func save() async {
        let saved = await app.commitSettings(
            SettingsDraft(
                staleHours: staleHours,
                looseMatching: looseMatching,
                showDockIcon: showDockIcon,
                launchAtLogin: launchAtLogin,
                notificationsEnabled: notificationsEnabled,
                cliPath: cliPath
            )
        )
        if saved {
            syncFromSettings()
        }
    }
}
