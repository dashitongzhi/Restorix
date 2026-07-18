import Foundation
import Security

protocol CredentialStoring {
    func save(_ password: String, for environmentKey: String) throws
    func password(for environmentKey: String) throws -> String?
}

struct KeychainCredentialStore: CredentialStoring {
    private static let service = "Kral.Restorix.restic"

    func save(_ password: String, for environmentKey: String) throws {
        let account = environmentKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !account.isEmpty else { return }
        let data = Data(password.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.service,
            kSecAttrAccount: account
        ]
        let attributes: [CFString: Any] = [kSecValueData: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var item = query
            item[kSecValueData] = data
            let addStatus = SecItemAdd(item as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError.status(addStatus) }
        } else if updateStatus != errSecSuccess {
            throw KeychainError.status(updateStatus)
        }
    }

    func password(for environmentKey: String) throws -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.service,
            kSecAttrAccount: environmentKey,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            throw KeychainError.status(status)
        }
        return password
    }
}

enum KeychainError: LocalizedError {
    case status(OSStatus)

    var errorDescription: String? {
        switch self {
        case .status(let status):
            return "Could not access the macOS Keychain: \(SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)")"
        }
    }
}
