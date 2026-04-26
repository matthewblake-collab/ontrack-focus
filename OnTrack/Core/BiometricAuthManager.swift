import Foundation
import LocalAuthentication
import Security

@MainActor
final class BiometricAuthManager {
    static let shared = BiometricAuthManager()
    private init() {}

    private let service = "com.blakeMatt.OnTrack"
    private let account = "userCredentials"

    var isBiometricAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    var biometricType: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID:  return "Face ID"
        case .touchID: return "Touch ID"
        default:       return "Biometrics"
        }
    }

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "biometric_auth_enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "biometric_auth_enabled") }
    }

    func authenticate() async -> Bool {
        let context = LAContext()
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Sign in to OnTrack"
            ) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }

    // MARK: - Keychain

    private struct StoredCredentials: Codable {
        let email: String
        let password: String
    }

    func saveCredentials(email: String, password: String) {
        guard let data = try? JSONEncoder().encode(StoredCredentials(email: email, password: password)) else { return }
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    func loadCredentials() -> (email: String, password: String)? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let creds = try? JSONDecoder().decode(StoredCredentials.self, from: data)
        else { return nil }
        return (creds.email, creds.password)
    }

    func clearCredentials() {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        isEnabled = false
    }
}
