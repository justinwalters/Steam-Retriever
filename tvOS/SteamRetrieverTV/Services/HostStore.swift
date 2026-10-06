// Steam Retriever for Apple TV - GPL-3.0 (see tvOS/LICENSE)
// Where the Mac is (UserDefaults) and the API token (Keychain).

import Foundation
import Security

struct SavedHost: Equatable {
    /// What the user typed or what Bonjour resolved: "mini.local", "192.168.1.20:48080".
    var address: String
    /// Bonjour service name ("Steam Retriever"), if the host was picked from the list.
    var serviceName: String?
}

enum HostStore {
    private static let addressKey = "host.address"
    private static let serviceKey = "host.serviceName"

    static var host: SavedHost? {
        get {
            guard let a = UserDefaults.standard.string(forKey: addressKey), !a.isEmpty else { return nil }
            return SavedHost(address: a, serviceName: UserDefaults.standard.string(forKey: serviceKey))
        }
        set {
            UserDefaults.standard.set(newValue?.address, forKey: addressKey)
            UserDefaults.standard.set(newValue?.serviceName, forKey: serviceKey)
        }
    }

    // One Mac for now (multiple Macs are out of scope), so one token.
    private static let service = "SteamRetrieverTV.api"
    private static let account = "token"

    static var token: String? {
        get {
            let q: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
            ]
            var out: CFTypeRef?
            guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
                  let data = out as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        }
        set {
            let match: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
            ]
            SecItemDelete(match as CFDictionary)
            guard let newValue, !newValue.isEmpty else { return }
            var add = match
            add[kSecValueData as String] = Data(newValue.utf8)
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(add as CFDictionary, nil)
        }
    }
}
