import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var app: AppViewModel

    var body: some View {
        List(selection: $app.selectedSidebarItem) {
            Section("Restorix") {
                ForEach(SidebarItem.allCases) { item in
                    Label(item.title(language: app.language), systemImage: item.systemImage)
                        .tag(item)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 220)
    }
}
