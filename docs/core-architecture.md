# Core Architecture

The Rust core keeps `scanner::engine::scan(&ConfigStore)` as the application-facing scan interface. Its implementation reads configuration, gathers Docker and restic state, applies health rules, and returns a complete `ScanResult` even when individual sources fail.

Scan environment access is isolated behind internal seams:

- `ConfigSource` loads application configuration.
- `DockerSource` provides Docker status, containers, and volumes.
- `BackupSource` provides restic status and snapshots.
- `Clock` provides the scan timestamp.

Production adapters use `ConfigStore`, `DockerClient`, `ResticClient`, and `SystemClock`. Test adapters exercise partial failures, missing dependencies, configuration errors, and successful protection without requiring Docker, restic, or the system clock.

Markdown reporting keeps its public interface in `report::markdown`. Section rendering lives in `report::markdown::sections`, while labels and diagnostic localization live in `report::markdown::localization`. This keeps output formatting and wording independently navigable without changing callers.

`ConfigStore` intentionally remains a single deep module: locking, broken-file recovery, atomic replacement, and permissions belong behind the same persistence interface.
