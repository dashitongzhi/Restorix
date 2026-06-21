# Restorix

Restorix checks whether Docker volumes on this Mac are backed up and restorable.

The first milestone includes a Rust CLI that:

- scans Docker containers and volumes
- reads restic snapshots
- matches Docker volume mountpoints to snapshot paths
- reports `Protected`, `Unprotected`, `Stale`, `Unknown`, and `Error`
- exports a Markdown health report

The macOS SwiftUI menu bar app calls this CLI through `Process`.

## CLI

```bash
cargo build
cargo test
cargo run -p restorix-cli -- scan --json
cargo run -p restorix-cli -- repo add --tool restic --name "Local Restic" --location "/path/to/repo" --password-env-key RESTIC_PASSWORD
cargo run -p restorix-cli -- report markdown
```

Configuration is stored as JSON under:

```text
~/Library/Application Support/Restorix/config.json
```

Set `RESTORIX_CONFIG` to use a different config path in tests or local experiments.
