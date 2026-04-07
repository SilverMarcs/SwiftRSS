//
//  AddFeedByURLSheet.swift
//  SwiftRSS
//
//  Created by Zabir Raihan on 07/04/2026.
//

import SwiftUI

struct AddFeedByURLSheet: View {
    @Environment(FeedStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var urlString = ""
    @State private var isAdding = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Enter URL", text: $urlString)
                        #if !os(macOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                } header: {
                    Text("Feed URL")
                } footer: {
                    Text("Supports RSS, Atom, and XML feeds")
                }

                if let err = errorText {
                    Text(err)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Add Feed by URL")
            .toolbarTitleDisplayMode(.inline)
            .formStyle(.grouped)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    if isAdding {
                        ProgressView()
                    } else {
                        Button("Add") {
                            Task { await addFeed() }
                        }
                        .disabled(URL(string: urlString) == nil)
                    }
                }
            }
        }
    }

    private func addFeed() async {
        guard let url = URL(string: urlString) else { return }
        isAdding = true
        errorText = nil
        defer { isAdding = false }

        do {
            try await store.addFeed(url: url)
            await store.refreshAll()
            dismiss()
        } catch {
            errorText = "Failed to add feed: \(error.localizedDescription)"
        }
    }
}
