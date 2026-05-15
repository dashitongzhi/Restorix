import SwiftUI

struct ReportView: View {
    @EnvironmentObject private var app: AppViewModel
    @State private var markdown = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(app.text(.markdownReport))
                    .font(.title2.weight(.semibold))
                Spacer()
                Button {
                    Task { await generateReport() }
                } label: {
                    Label(app.text(.generate), systemImage: "doc.text.magnifyingglass")
                }
                Button {
                    Pasteboard.copy(markdown)
                } label: {
                    Label(app.text(.copy), systemImage: "doc.on.doc")
                }
                .disabled(markdown.isEmpty)
                Button {
                    ReportExportService.save(markdown: markdown)
                } label: {
                    Label(app.text(.save), systemImage: "square.and.arrow.down")
                }
                .disabled(markdown.isEmpty)
            }

            if markdown.isEmpty {
                EmptyStateView(
                    title: app.text(.noReportGenerated),
                    message: app.text(.noReportGeneratedMessage),
                    actionTitle: app.text(.generateReport)
                ) {
                    Task { await generateReport() }
                }
            } else {
                ScrollView {
                    Text(markdown)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                }
                .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(24)
    }

    private func generateReport() async {
        if let report = await app.exportMarkdownReport() {
            markdown = report
        }
    }
}
