# macOS Architecture

The macOS app is a SwiftUI + AppKit menu bar application.

The app does not parse Docker or restic output directly. It calls the bundled `restorix` CLI through `Process`, decodes stable JSON into Swift models, and displays dashboard, volume, repository, report, and settings views.
