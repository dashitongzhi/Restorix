# macOS Architecture

The macOS app is a SwiftUI + AppKit menu bar application.

The app does not parse Docker or restic output directly. It calls the bundled `restorix` CLI through `Process`, decodes stable JSON into Swift models, and displays dashboard, volume, repository, report, and settings views.

`CoreBridge` owns typed CLI operations and decoding. `CLICommandRunner` owns the process lifecycle, environment, output collection, and timeout behavior. `CLIExecutableLocator` owns configured-path lookup, bundled CLI staging, and fallback discovery. The runner returns stdout, stderr, and the exit code without deciding whether a command succeeded; each typed operation declares the exit codes it accepts.

`scan --json` and `report markdown` accept exit codes `0` and `2`. Exit code `2` means the CLI produced a valid result containing hard diagnostics, so the macOS app must preserve and display that payload instead of discarding it as a transport failure.

`AppViewModel` owns observable application state and user workflows. `MarkdownReportRenderer` is a pure rendering module so report formatting can be verified without constructing AppKit state or launching the CLI.
