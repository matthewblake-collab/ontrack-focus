import Foundation
import Supabase
import AuthenticationServices
import CryptoKit

@Observable
final class AuthViewModel {
    var email: String = ""
    var password: String = ""
    var displayName: String = ""
    var isLoading: Bool = false
    var errorMessage: String? = nil

    private var currentNonce: String?

    func signIn(appState: AppState) async {
        isLoading = true
        errorMessage = nil
        do {
            try await supabase.auth.signIn(email: email, password: password)
            let user = try await supabase.auth.user()
            await appState.fetchProfile(userId: user.id)
            appState.isLoggedIn = true
            postBiometricEnrollmentNotification(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signUp(appState: AppState) async {
        isLoading = true
        errorMessage = nil
        do {
            try await supabase.auth.signUp(
                email: email,
                password: password,
                data: ["display_name": AnyJSON.string(displayName)]
            )
            let user = try await supabase.auth.user()
            await appState.fetchProfile(userId: user.id)
            appState.isLoggedIn = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Returns the SHA256-hashed nonce to set on the Apple ID request.
    /// Stores the raw nonce internally to pass to Supabase on completion.
    func prepareAppleSignIn() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }

    func signInWithApple(result: Result<ASAuthorization, Error>, appState: AppState) async {
        isLoading = true
        errorMessage = nil
        do {
            let authorization = try result.get()
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let idTokenData = credential.identityToken,
                let idToken = String(data: idTokenData, encoding: .utf8),
                let nonce = currentNonce
            else {
                throw NSError(
                    domain: "AppleSignIn",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Unable to retrieve Apple ID credentials"]
                )
            }

            try await supabase.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .apple,
                    idToken: idToken,
                    nonce: nonce
                )
            )

            let user = try await supabase.auth.user()

            // Check if a profile row already exists for this user
            struct ProfileCheck: Decodable { let id: UUID }
            let existing: [ProfileCheck] = try await supabase
                .from("profiles")
                .select("id")
                .eq("id", value: user.id)
                .execute()
                .value

            if existing.isEmpty {
                // New user — insert profile row. Apple only provides the full name on first auth.
                let firstName = credential.fullName?.givenName ?? ""
                let lastName = credential.fullName?.familyName ?? ""
                let name = [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")

                struct NewProfile: Encodable {
                    let id: UUID
                    let display_name: String
                }
                try await supabase
                    .from("profiles")
                    .insert(NewProfile(id: user.id, display_name: name))
                    .execute()
            }

            await appState.fetchProfile(userId: user.id)
            appState.isLoggedIn = true

            // Password is empty — signInWithBiometric will call checkSession() for Apple users.
            postBiometricEnrollmentNotification(email: credential.email ?? "", password: "")
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Saves credentials to Keychain and marks biometric as enabled.
    func enableBiometric(email: String, password: String) {
        BiometricAuthManager.shared.saveCredentials(email: email, password: password)
        BiometricAuthManager.shared.isEnabled = true
    }

    /// Called from ContentView on launch (auto) or from SignInView (manual fallback).
    /// Loads stored credentials, authenticates with biometrics, then signs in.
    func signInWithBiometric(appState: AppState) async {
        let bio = BiometricAuthManager.shared
        guard let (storedEmail, storedPassword) = bio.loadCredentials() else { return }

        isLoading = true
        errorMessage = nil

        let success = await bio.authenticate()
        guard success else {
            isLoading = false
            return
        }

        do {
            if storedPassword.isEmpty {
                // Apple user — verify and refresh the existing Supabase session
                await appState.checkSession()
            } else {
                try await supabase.auth.signIn(email: storedEmail, password: storedPassword)
                let user = try await supabase.auth.user()
                await appState.fetchProfile(userId: user.id)
                appState.isLoggedIn = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func deleteAccount(appState: AppState) async -> Bool {
        isLoading = true
        errorMessage = nil
        do {
            guard let userId = appState.currentUser?.id else {
                throw NSError(domain: "DeleteAccount", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user found"])
            }
            let uid = userId.uuidString
            _ = try? await supabase.from("habit_logs").delete().eq("user_id", value: uid).execute()
            _ = try? await supabase.from("daily_checkins").delete().eq("user_id", value: uid).execute()
            _ = try? await supabase.from("supplement_logs").delete().eq("user_id", value: uid).execute()
            _ = try? await supabase.from("attendance").delete().eq("user_id", value: uid).execute()
            _ = try? await supabase.from("habits").delete().eq("created_by", value: uid).execute()
            _ = try? await supabase.from("supplements").delete().eq("user_id", value: uid).execute()
            _ = try? await supabase.from("group_members").delete().eq("user_id", value: uid).execute()
            _ = try? await supabase.from("friendships").delete().eq("requester_id", value: uid).execute()
            _ = try? await supabase.from("friendships").delete().eq("receiver_id", value: uid).execute()
            _ = try? await supabase.from("profiles").delete().eq("id", value: uid).execute()
            try await supabase.rpc("delete_user").execute()
            BiometricAuthManager.shared.isEnabled = false
            UserDefaults.standard.removeObject(forKey: "checkin_completed_date")
            appState.isLoggedIn = false
            appState.currentUser = nil
            isLoading = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    // MARK: - Private helpers

    /// Posts a notification that ContentView observes to present the biometric enrollment sheet.
    /// ContentView owns the gate logic (UserDefaults + availability check) so the sheet
    /// survives the navigation away from SignInView.
    private func postBiometricEnrollmentNotification(email: String, password: String) {
        NotificationCenter.default.post(
            name: .biometricEnrollmentNeeded,
            object: nil,
            userInfo: ["email": email, "password": password]
        )
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if status != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(status)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

extension Notification.Name {
    static let biometricEnrollmentNeeded = Notification.Name("BiometricEnrollmentNeeded")
}
