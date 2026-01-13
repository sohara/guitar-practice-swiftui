import Foundation
import Security

enum KeychainError: LocalizedError {
    case unableToSave
    case unableToRead
    case unableToDelete
    case unexpectedData
    case notFound

    var errorDescription: String? {
        switch self {
        case .unableToSave: return "Unable to save to Keychain"
        case .unableToRead: return "Unable to read from Keychain"
        case .unableToDelete: return "Unable to delete from Keychain"
        case .unexpectedData: return "Unexpected data format in Keychain"
        case .notFound: return "Item not found in Keychain"
        }
    }
}

enum KeychainService {
    // MARK: - API Key

    static func saveAPIKey(_ apiKey: String) throws {
        guard let data = apiKey.data(using: .utf8) else {
            throw KeychainError.unexpectedData
        }

        // Delete existing key first
        try? deleteAPIKey()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Config.Keychain.service,
            kSecAttrAccount as String: Config.Keychain.apiKeyAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unableToSave
        }
    }

    static func getAPIKey() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Config.Keychain.service,
            kSecAttrAccount as String: Config.Keychain.apiKeyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status != errSecItemNotFound else {
            throw KeychainError.notFound
        }

        guard status == errSecSuccess else {
            throw KeychainError.unableToRead
        }

        guard let data = result as? Data,
              let apiKey = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedData
        }

        return apiKey
    }

    static func deleteAPIKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Config.Keychain.service,
            kSecAttrAccount as String: Config.Keychain.apiKeyAccount
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unableToDelete
        }
    }

    static var hasAPIKey: Bool {
        (try? getAPIKey()) != nil
    }
}
