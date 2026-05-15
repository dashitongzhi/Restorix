import SwiftUI

struct RootView: View {
    @EnvironmentObject private var app: AppViewModel

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            Group {
                switch app.selectedSidebarItem {
                case .dashboard:
                    DashboardView()
                case .volumes:
                    VolumeListView()
                case .repositories:
                    RepositoryListView()
                case .reports:
                    ReportView()
                case .settings:
                    SettingsView()
                }
            }
            .navigationTitle(app.selectedSidebarItem.title(language: app.language))
        }
        .task {
            await app.refreshInitialData()
        }
    }
}
