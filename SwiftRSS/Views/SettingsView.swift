//
//  SettingsView.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 06/09/2025.
//

import SwiftUI
import CachedAsyncImage
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var context
    @State private var deleteAlertPresented = false
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
                    Button {
                        deleteAlertPresented = true
                    } label: {
                        HStack {
                            Label {
                                Text("Clear Image Cache")
                                
                            } icon: {
                                Image(systemName: "trash")
                            }
                            
//                            Spacer()
//                            
//                            Text("{Cache Size}")
                        }
                        .contentShape(.rect)
                    }
                    .alert("Clear Image Cache", isPresented: $deleteAlertPresented) {
                        Button("Clear", role: .destructive) {
                            Task {
                                await MemoryCache.shared.clearCache()
                                await DiskCache.shared.clearCache()
                            }
                        }
                        Button("Cancel", role: .cancel) { }
                    } message: {
                        Text("This will clear all cached images, freeing up storage space.")
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .toolbarTitleDisplayMode(.inline)
            #if !os(macOS)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        dismiss()
                    }) {
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
                                    _ = try await FeedService.importOPML(data: data, context: context)
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
    SettingsView()
}
