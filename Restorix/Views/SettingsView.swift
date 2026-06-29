import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var app: AppViewModel
    @State private var staleHours = 72
    @State private var looseMatching = false
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
            VStack(spacing: 9) {
                ZStack(alignment: .topTrailing) {
                    iconPreview
                        .frame(width: 68, height: 68)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.accentColor)
                            .background(Circle().fill(Color(nsColor: .windowBackgroundColor)))
                            .offset(x: 7, y: -7)
                    }
                }

                Text(title)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 116)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.07))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.16), lineWidth: isSelected ? 2 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private var iconPreview: some View {
        if let image = icon.image {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(1, contentMode: .fit)
        } else {
            Image(systemName: "app.dashed")
                .resizable()
                .aspectRatio(1, contentMode: .fit)
                .foregroundStyle(.secondary)
                .padding(12)
        }
    }
}
