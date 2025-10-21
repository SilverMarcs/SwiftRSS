import SwiftUI
import Observation

struct AddFeedSheet: View {
    @Environment(FeedStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var urlString = ""
    @State private var isAdding = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Enter feed url", text: $urlString)
                    #if !os(macOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    #endif
                } header: {
                    Text("Feed URL")
                } footer: {
                    Text("Supports RSS, XML and Atom")
                }
                
                if let err = errorText {
                    Text(err)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Add Feed")
            .toolbarTitleDisplayMode(.inline)
            .formStyle(.grouped)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        Task { await addFeed() }
                    }
                    .disabled(isAdding || URL(string: urlString) == nil)
                }
            }
        }
    }

    private func addFeed() async {
        isAdding = true
        defer { isAdding = false }
        
        guard let url = URL(string: urlString) else { return }
        errorText = nil
        do {
            try await store.addFeed(url: url)
            await store.refreshAll()
            dismiss()
        } catch {
            errorText = "Failed to add feed: \(error.localizedDescription)"
        }
    }
}
