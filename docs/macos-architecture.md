# macOS Architecture

The macOS app is a SwiftUI + AppKit menu bar application.

The app does not parse Docker or restic output directly. It calls the bundled `restorix` CLI through `Process`, decodes stable JSON into Swift models, and displays dashboard, volume, repository, report, and settings views.

`CoreBridge` owns typed CLI operations and decoding through the `CoreBridging` interface. Keychain access sits behind `CredentialStoring`, so command workflows can be tested without the real macOS Keychain. `CLICommandRunner` owns the process lifecycle, environment, output collection, and timeout behavior. `CLIExecutableLocator` owns configured-path lookup, bundled CLI staging, and fallback discovery. The runner returns stdout, stderr, and the exit code without deciding whether a command succeeded; each typed operation declares the exit codes it accepts.

`scan --json` and `report markdown` accept exit codes `0` and `2`. Exit code `2` means the CLI produced a valid result containing hard diagnostics, so the macOS app must preserve and display that payload instead of discarding it as a transport failure.

Diagnostics cross the CLI interface as a stable `code`, structured `context`, and fallback `message`. Rust health policy owns diagnostic identity; Markdown and Swift are rendering adapters. Wording changes therefore do not change diagnostic behavior. The Swift decoder accepts legacy string diagnostics and maps unknown future codes to `generic`, allowing a configured older or newer CLI to degrade without breaking the full scan payload.

`SettingsCoordinator` exposes one typed settings commit. It validates and persists all settings through one Rust config transaction, applies launch-at-login and Dock preferences, and rolls back launch-at-login when persistence fails. New CLIs retain a hidden `config set` adapter for older clients; `CoreBridge` uses that legacy path only when a configured older CLI explicitly rejects `config commit`, with best-effort rollback of already-applied legacy fields.

`AppWorkflow` owns scan/repository sequencing and post-mutation refresh. `AppViewModel` owns observable state and forwards user intent through that interface. `NotificationPolicy` and `VolumeRiskPolicy` are pure rules; delivery, history and time are adapters. `MarkdownReportRenderer`, dashboard recommendations, and menu-bar presentation are pure rendering modules.

Release scripts keep orchestration short. Packaged-app and launch-at-login checks live in `script/lib/app_bundle_smoke.sh`; signing, notarization and Gatekeeper checks live in `script/lib/package_security.sh`.
