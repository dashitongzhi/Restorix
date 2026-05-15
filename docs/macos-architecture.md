# macOS Architecture

The macOS app will be a SwiftUI + AppKit menu bar application.

The app must not parse Docker or restic output directly. It should call the bundled `restorix` CLI through `Process`, decode stable JSON into Swift models, and display dashboard, volume, repository, report, and settings views.

