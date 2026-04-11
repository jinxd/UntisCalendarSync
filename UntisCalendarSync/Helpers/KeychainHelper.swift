import Foundation
import Security

enum KeychainHelper {
    private static let service = "com.nagel.UntisCalendarSync"

    static func save(credentials: UntisCredentials) throws {
        try save(value: credentials.server, key: "server")
        try save(value: credentials.username, key: "username")
        try save(value: credentials.password, key: "password")
    }

    static func loadCredentials() throws -> UntisCredentials {
        let server   = try load(key: "server")
        let username = try load(key: "username")
        let password = try load(key: "password")
        return UntisCredentials(server: server, username: username, password: password)
    }

    static func deleteCredentials() {
        delete(key: "server")
        delete(key: "username")
        delete(key: "password")
    }

    static func hasCredentials() -> Bool {
        (try? loadCredentials()) != nil
    }

    // MARK: - Private

    private static func save(value: String, key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData] = data
            let addStatus = SecItemAdd(add as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.saveFailed(addStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.saveFailed(status)
        }
    }

    private static func load(key: String) throws -> String {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.notFound
        }
        return string
    }

    private static func delete(key: String) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum KeychainError: LocalizedError {
    case encodingFailed
    case saveFailed(OSStatus)
    case notFound

    var errorDescription: String? {
        switch self {
        case .encodingFailed:      return "Failed to encode credential."
        case .saveFailed(let s):   return "Keychain save failed (OSStatus \(s))."
        case .notFound:            return "Credential not found in Keychain."
        }
    }
}
