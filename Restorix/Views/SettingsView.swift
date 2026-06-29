import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var app: AppViewModel
    @State private var staleHours = 72
    @State private var looseMatching = false
    @State private var showDockIcon = true
    @State private var launchAtLogin = false
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

            Section(app.text(.appIcon)) {
                HStack(spacing: 12) {
                    ForEach(AppIconChoice.allCases) { icon in
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
        let nextStaleHours = staleHours
        let nextLooseMatching = looseMatching
        let nextNotificationsEnabled = notificationsEnabled
        let nextShowDockIcon = showDockIcon
        let nextLaunchAtLogin = launchAtLogin
        let nextCLIPath = cliPath

        await app.setConfig(key: "stale_hours", value: String(nextStaleHours))
        await app.setConfig(key: "loose_matching", value: nextLooseMatching ? "true" : "false")
        await app.setConfig(key: "notifications_enabled", value: nextNotificationsEnabled ? "true" : "false")
        await app.setConfig(key: "show_dock_icon", value: nextShowDockIcon ? "true" : "false")
        await app.setLaunchAtLogin(nextLaunchAtLogin)
        await app.setConfig(key: "cli_path", value: nextCLIPath)
        syncFromSettings()
    }
}

private struct IconChoiceButton: View {
    let icon: AppIconChoice
    let isSelected: Bool
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(icon.assetName)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 4, y: 2)

                Text(title)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(.primary)
            .frame(width: 96, height: 96)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
