import SwiftUI
import SwiftData

struct AddFeedSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var urlString = ""
    @State private var isAdding = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Enter feed url", text: $urlString)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
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
            _ = try await FeedService.subscribe(url: url, modelContainer: context.container)
            dismiss()
        } catch {
            errorText = "Failed to add feed: \(error.localizedDescription)"
        }
    }
}
