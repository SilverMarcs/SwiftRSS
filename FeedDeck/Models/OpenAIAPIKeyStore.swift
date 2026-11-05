import Foundation
import Observation
import Security

@Observable
@MainActor
final class OpenAIAPIKeyStore {
    var key = "" {
        didSet {
            do {
                try Self.save(key)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    private(set) var errorMessage: String?

    init() {
        do {
            key = try Self.load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    static func load() throws -> String {
        var query = itemQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound { return "" }
        guard status == errSecSuccess else { throw KeychainError(status: status) }
        guard let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else { throw KeychainError(status: errSecDecode) }

        return key
    }

    private static func save(_ key: String) throws {
        let key = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let query = itemQuery
        if key.isEmpty {
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw KeychainError(status: status)
            }
        } else {
            let attributes = [kSecValueData as String: Data(key.utf8)]
            var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            if status == errSecItemNotFound {
                var item = query
                item[kSecValueData as String] = Data(key.utf8)
                item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
                status = SecItemAdd(item as CFDictionary, nil)
            }
            guard status == errSecSuccess else { throw KeychainError(status: status) }
        }
    }

    private static let account = "openAIApiKey"

    private static var itemQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.SilverMarcs.SwiftRSS",
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true
        ]
    }
}
