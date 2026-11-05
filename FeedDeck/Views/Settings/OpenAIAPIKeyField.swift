import SwiftUI

struct OpenAIAPIKeyField: View {
    @State private var store = OpenAIAPIKeyStore()

    var body: some View {
        SecureField("OpenAI API Key", text: $store.key)
            .autocorrectionDisabled()
            #if !os(macOS)
            .textInputAutocapitalization(.never)
            #endif

        if let errorMessage = store.errorMessage {
            Text(errorMessage)
                .foregroundStyle(.red)
        }
    }
}
