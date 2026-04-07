//
//  SettingsView.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 06/09/2025.
//

import SwiftUI
import SwiftData
import SwiftMediaViewer
import UniformTypeIdentifiers

struct OPMLDocument: FileDocument {
    static var readableContentTypes: [UTType] { [UTType(filenameExtension: "opml") ?? .xml] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(FeedStore.self) private var store
    @AppStorage("geminiApiKey") private var geminiApiKey: String = ""
    @AppStorage("openLinksInReaderView") private var openLinksInReaderView = true
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showFileImporter = false
    @State private var showFileExporter = false
    @State private var exportData: Data?
    @State private var importError: String?
    @State private var showDeleteOldArticlesAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section("OPML") {
                    Button {
                        showFileImporter = true
                    } label: {
                        Label("Import OPML", systemImage: "square.and.arrow.down")
                            .contentShape(.rect)
                    }

                    Button {
                        exportData = generateOPML()
                        showFileExporter = true
                    } label: {
                        Label("Export OPML", systemImage: "square.and.arrow.up")
                            .contentShape(.rect)
                    }
                }

                Section("Reading") {
                    Toggle("Open links in in-app reader view", isOn: $openLinksInReaderView)
                }
                
                Section("AI Summary") {
                    SecureField("Gemini API Key", text: $geminiApiKey)
                    #if !os(macOS)
                        .textInputAutocapitalization(.never)
                    #endif
                        .autocorrectionDisabled()
                }
                
                Section("Cache") {
                    CacheManagerView()

                    Button {
                        showDeleteOldArticlesAlert = true
                    } label: {
                        Label("Remove Articles Older Than a Week", systemImage: "clock.badge.xmark")
                            .contentShape(.rect)
                    }
                    .alert("Remove Old Articles", isPresented: $showDeleteOldArticlesAlert) {
                        Button("Remove", role: .destructive) {
                            deleteOldArticles()
                        }
                        Button("Cancel", role: .cancel) { }
                    } message: {
                        Text("This will permanently delete all articles published more than 7 days ago that are not starred.")
                    }
                }
                #if DEBUG
                Section("Debug") {
                    Button("Reset Onboarding") {
                        hasCompletedOnboarding = false
                    }
                }
                #endif
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .toolbarTitleDisplayMode(.inline)
            #if !os(macOS)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
            #else
            .buttonStyle(.plain)
            #endif
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [UTType.xml, UTType(filenameExtension: "opml") ?? .xml],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        Task {
                            do {
                                if url.startAccessingSecurityScopedResource() {
                                    defer { url.stopAccessingSecurityScopedResource() }
                                    let data = try Data(contentsOf: url)
                                    try await store.importOPML(data: data)
                                } else {
                                    importError = "Unable to access the selected file"
                                }
                            } catch {
                                importError = error.localizedDescription
                            }
                        }
                    }
                case .failure(let error):
                    importError = error.localizedDescription
                }
            }
            .fileExporter(
                isPresented: $showFileExporter,
                document: OPMLDocument(data: exportData ?? Data()),
                contentType: UTType(filenameExtension: "opml") ?? .xml,
                defaultFilename: "FeedDeck Feeds.opml"
            ) { _ in }
            .alert("Import Error", isPresented: .init(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
                Button("OK") { }
            } message: {
                Text(importError ?? "")
            }
        }
    }

    private func generateOPML() -> Data {
        let feeds = (try? modelContext.fetch(FetchDescriptor<Feed>())) ?? []
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="2.0">
        <head><title>FeedDeck Feeds</title></head>
        <body>\n
        """
        for feed in feeds {
            guard let url = feed.url else { continue }
            let escapedTitle = feed.title
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "\"", with: "&quot;")
                .replacingOccurrences(of: "<", with: "&lt;")
            xml += "    <outline type=\"rss\" text=\"\(escapedTitle)\" title=\"\(escapedTitle)\" xmlUrl=\"\(url.absoluteString)\" />\n"
        }
        xml += "</body>\n</opml>"
        return Data(xml.utf8)
    }

    private func deleteOldArticles() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now)!
        let predicate = #Predicate<Article> { $0.publishedAt < cutoff && !$0.isStarred }
        try? modelContext.delete(model: Article.self, where: predicate)
        try? modelContext.save()
    }
}
