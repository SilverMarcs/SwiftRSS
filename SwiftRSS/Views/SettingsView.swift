//
//  SettingsView.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 06/09/2025.
//

import SwiftUI
import SwiftMediaViewer
import UniformTypeIdentifiers
import Observation

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(FeedStore.self) private var store
    @State private var showFileImporter = false
    @State private var importError: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Import") {
                    Button {
                        showFileImporter = true
                    } label: {
                        HStack {
                            Label {
                                Text("Import OPML")
                            } icon: {
                                Image(systemName: "square.and.arrow.down")
                            }
                        }
                        .contentShape(.rect)
                    }
                }
                
                Section("Images") {
                    CacheManagerView()
                }
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
                allowedContentTypes: [UTType.xml],
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
                                    _ = try await store.importOPML(data: data)
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
            .alert("Import Error", isPresented: .init(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
                Button("OK") { }
            } message: {
                Text(importError ?? "")
            }
        }
    }
}

#Preview {
    SettingsView().environment(FeedStore())
}
