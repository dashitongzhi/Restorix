<p align="center">
  <img src="Restorix/Assets.xcassets/RestorixIconDimensional.imageset/RestorixIconDimensional.png" width="104" height="104" alt="Restorix app icon" />
</p>

<h1 align="center">Restorix</h1>

<p align="center">
  <strong>Backup confidence for self-hosted Docker volumes on macOS.</strong>
</p>

<p align="center">
  Restorix compares real Docker volume mountpoints with real restic snapshots, then tells you which data is protected, stale, unknown, or exposed.
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-111827?style=for-the-badge" alt="MIT license" /></a>
  <img src="https://img.shields.io/badge/platform-macOS-0f766e?style=for-the-badge" alt="macOS" />
  <img src="https://img.shields.io/badge/core-Rust-b45309?style=for-the-badge" alt="Rust core" />
  <img src="https://img.shields.io/badge/app-SwiftUI%20%2B%20AppKit-2563eb?style=for-the-badge" alt="SwiftUI and AppKit" />
  <img src="https://img.shields.io/badge/backups-restic-7c3aed?style=for-the-badge" alt="restic" />
</p>

<p align="center">
  <a href="README.md">English</a> ·
  <a href="README.zh-CN.md">简体中文</a>
</p>

<p align="center">
  <a href="#why-restorix">Why</a> ·
  <a href="#how-it-works">How it works</a> ·
  <a href="#quick-start">Quick start</a> ·
  <a href="#macos-app">macOS app</a> ·
  <a href="#release-verification">Release verification</a>
</p>

## Why Restorix

Running backups is not the same as knowing your production data is restorable. Docker volumes drift, snapshot paths change, restic repositories move, and the failure usually stays invisible until restore day.

Restorix is a focused trust layer for that gap. It does not try to become another backup scheduler. It inspects the backup state you already have and turns it into an operator-grade answer:

> Are my Docker volumes backed up recently enough that I could restore them?

## What It Replaces

| Workflow | What usually happens | What Restorix gives you |
| --- | --- | --- |
| Manual Docker and restic checks | Shell history, fragile path matching, no durable report | One scan that joins containers, volumes, repositories, snapshots, and restore hints |
| Generic backup tools | Great at copying data, weak at proving app-specific Docker volume coverage | Volume-by-volume confidence against the actual Docker mountpoints on this Mac |
| README runbooks | Human-readable, but quickly stale | Markdown reports generated from the latest machine state |
| "It probably backed up" | Hope | `Protected`, `Unprotected`, `Stale`, `Unknown`, and `Error` statuses with reasons |

## Product Shape

Restorix is deliberately narrow:

- It scans Docker containers and Docker volumes.
- It reads restic repositories and snapshots.
- It matches snapshot paths against Docker volume mountpoints.
- It produces a health model that is usable by both CLI automation and the macOS app.
- It exports Markdown reports for audit trails, incident notes, or handoff.
- It surfaces safe restore commands when it can infer them.

Restorix does not currently perform backups, restore data, schedule jobs, or replace restic. That boundary is intentional: the product is strongest as an independent verification layer.

## How It Works

```mermaid
flowchart LR
  Docker["Docker containers and volumes"] --> Core["Rust core"]
  Restic["restic snapshots"] --> Core
  Config["Local Restorix config"] --> Core
  Core --> Health["Volume health model"]
  Health --> CLI["JSON CLI"]
  Health --> Report["Markdown report"]
  Health --> App["macOS menu bar app"]
```

The SwiftUI app does not reimplement Docker or restic parsing. It launches the bundled `restorix` CLI through `Process`, decodes stable JSON models, and presents the same health model the CLI uses.

## Health Model

| Status | Meaning | Operator action |
| --- | --- | --- |
| `Protected` | A recent restic snapshot from the repository's configured hostname covers the Docker volume. This proves path and recency only, not restore or data-integrity testing. | Monitor, run periodic restic integrity checks, and rehearse restores. |
| `Unprotected` | No usable snapshot was matched for the volume. | Add or repair the restic repository path, then rescan. |
| `Stale` | A snapshot exists, but it is older than the configured threshold. | Run the backup job and verify the next scan. |
| `Unknown` | Docker or restic data was incomplete, the repository has no configured snapshot hostname, or confidence was too low. | Review paths, repository access, hostname selection, and matching assumptions. |
| `Error` | The scanner hit a hard failure. | Fix the reported dependency, permission, or command issue. |

## Quick Start

Prerequisites:

- macOS
- Docker or OrbStack running
- `restic` installed
- Rust toolchain for local development

Build and test the Rust workspace:

```bash
cargo build
cargo test
```

Add a restic repository without storing the password in Restorix config:

```bash
export RESTIC_PASSWORD="replace-with-your-local-secret"

cargo run -p restorix-cli -- repo add \
  --tool restic \
  --name "Local Restic" \
  --location "/path/to/restic/repo" \
  --password-env-key RESTIC_PASSWORD \
  --expected-hostname "$(hostname)"
```

`--expected-hostname` must exactly match the `hostname` recorded by the snapshots that belong to this Mac. Repositories imported from older Restorix versions remain readable, but they report `Unknown` until this value is configured.

Scan Docker volume coverage:

```bash
cargo run -p restorix-cli -- scan --json
```

Generate an audit-ready Markdown report:

```bash
cargo run -p restorix-cli -- report markdown --language en
cargo run -p restorix-cli -- report markdown --language zh-Hans
```

## CLI Surface

| Command | Purpose |
| --- | --- |
| `restorix docker check --json` | Verify Docker availability signals. |
| `restorix docker containers --json` | Inspect Docker containers. |
| `restorix docker volumes --json` | Inspect Docker volumes. |
| `restorix repo add ...` | Register a restic repository. |
| `restorix repo list --json` | List configured repositories. |
| `restorix repo test <repo_id> --json` | Confirm repository access and snapshot visibility. |
| `restorix repo enable <repo_id>` | Include a repository in scans. |
| `restorix repo disable <repo_id>` | Temporarily remove a repository from scan results. |
| `restorix scan --json` | Produce the full health model. |
| `restorix report markdown --language en` | Export a Markdown report. |
| `restorix config get --json` | Read local settings. |
| `restorix config commit '<json>'` | Validate and update all local settings in one transaction. |

## macOS App

The app is a SwiftUI + AppKit menu bar utility for daily visibility:

- Dashboard summary for protected and at-risk volumes.
- Volume detail views with reasons, confidence, and restore commands.
- Repository management, enable/disable controls, and repository testing.
- Markdown report export.
- English and Simplified Chinese UI.
- Local notifications.
- Optional dock icon.
- Open at login through `SMAppService.mainApp`.
- Multiple app icon choices.

Run the app verification helper:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  bash script/build_and_run.sh --verify
```

## Release Verification

Restorix has a single local shipping path for the packaged app:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  bash script/verify_release_package.sh
```

That wrapper packages `Restorix.app`, stages the bundled CLI, and runs the packaged smoke flow against `dist/Restorix.app`.

Release outputs are generated under `dist/`:

```text
dist/Restorix.app
dist/Restorix-macos-standalone.zip
dist/Restorix-macos-standalone.dmg
```

The GitHub release workflow reuses the same verification script instead of maintaining a parallel release path. Public `v*` tag releases are allowed to publish GitHub release assets only when Developer ID signing and notarization are configured. The workflow fails before packaging unsigned public release artifacts if any of these secrets are missing:

```text
MACOS_DEVELOPER_ID_APPLICATION_CERTIFICATE_BASE64
MACOS_DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD
MACOS_DEVELOPER_ID_APPLICATION
MACOS_NOTARY_APPLE_ID
MACOS_NOTARY_PASSWORD
MACOS_NOTARY_TEAM_ID or MACOS_DEVELOPMENT_TEAM
```

Unsigned artifacts are reserved for explicit maintainer smoke runs: start `workflow_dispatch` with `unsigned_ci_artifacts=true`. That path uses local signing, disables notarization and Gatekeeper release checks, uploads only workflow artifacts, and never publishes GitHub release assets.

## Maintainer Automation

Codex PR review runs automatically on non-draft pull requests. Repository owners, members, and collaborators can also retrigger it from a non-draft pull request comment by posting exactly:

```text
/codex-review
```

The comment trigger is ignored outside pull requests, on draft pull requests, and for untrusted author associations.

## Configuration

Default configuration path:

```text
~/Library/Application Support/Restorix/config.json
```

For tests and isolated experiments, set:

```bash
export RESTORIX_CONFIG="/tmp/restorix-config.json"
```

Repository passwords are referenced by environment variable name, for example `RESTIC_PASSWORD`, instead of being stored directly in the Restorix config file. The macOS app stores a password entered while adding a repository in the user's Keychain and injects it only into the corresponding CLI subprocess; CLI automation can continue to provide the named environment variable itself.

## Repository Layout

```text
Restorix/
  App/                 macOS app entry points, menu bar, launch-at-login verifier
  Components/          SwiftUI reusable UI pieces
  Models/              Swift models and localization
  Services/            CLI bridge, report export, notifications, pasteboard
  ViewModels/          App state and orchestration
  Views/               Dashboard, volumes, repositories, reports, settings
crates/
  restorix-core/       Docker/restic parsing, scanning, matching, reporting, config
  restorix-cli/        Clap CLI over the core model
docs/                  Product notes, architecture, MVP roadmap
script/                Build, run, package, and smoke verification scripts
```

## Development Gates

Use this ladder before treating a branch as shippable:

```bash
cargo test

cargo clippy --workspace --all-targets -- -D warnings

shellcheck script/*.sh script/lib/*.sh script/fixtures/*.sh

bash script/smoke_cli_command_runner.sh
bash script/smoke_app_workflow.sh
bash script/smoke_notification_policy.sh
bash script/smoke_settings_coordinator.sh
bash script/smoke_package_security.sh

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project Restorix.xcodeproj -scheme Restorix \
    -configuration Debug CODE_SIGNING_ALLOWED=NO build

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  bash script/verify_release_package.sh
```

## License

Restorix is released under the [MIT License](LICENSE).
