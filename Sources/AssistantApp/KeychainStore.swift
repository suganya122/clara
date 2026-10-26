import Core
import Foundation
import Security

/// The Anthropic API key lives in the Keychain only. Never in config, logs or the repo.
enum KeychainStore {
    private static func query() -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: AppConfig.keychainService,
         kSecAttrAccount as String: AppConfig.keychainAccount]
    }

    static func readKey() -> String? {
        var q = query()
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func saveKey(_ key: String) -> Bool {
        SecItemDelete(query() as CFDictionary)
        var q = query()
        q[kSecValueData as String] = Data(key.utf8)
        return SecItemAdd(q as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult
    static func deleteKey() -> Bool {
        let status = SecItemDelete(query() as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
