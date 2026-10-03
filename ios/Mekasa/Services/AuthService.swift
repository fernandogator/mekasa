import Foundation
import Security
import UIKit
import FirebaseCore
import FirebaseAuth
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

/// Firebase Auth (Email + Google). Falls back to a clear error if Firebase isn't ready.
/// Satisfies: REQ-001 (Household Account Creation) AC1–AC3
/// Spec version: 1.0
@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    var isFirebaseConfigured: Bool {
        FirebaseBootstrap.isConfigured
    }

    var currentUserUID: String? {
        Auth.auth().currentUser?.uid
    }

    func signIn(email: String, password: String) async throws -> (token: String, email: String?, name: String?) {
        try ensureFirebaseReady()
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            let token = try await result.user.getIDToken()
            return (token, result.user.email, result.user.displayName)
        } catch {
            throw AuthErrorFormatter.wrap(error)
        }
    }

    /// Sends Firebase's password-reset email. Also the way a Google-only account
    /// gets a password attached, so email sign-in starts working for it.
    func sendPasswordReset(email: String) async throws {
        try ensureFirebaseReady()
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            throw AuthErrorFormatter.wrap(error)
        }
    }

    func signUp(email: String, password: String) async throws -> (token: String, email: String?, name: String?) {
        try ensureFirebaseReady()
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let token = try await result.user.getIDToken()
            return (token, result.user.email, result.user.displayName)
        } catch {
            throw AuthErrorFormatter.wrap(error)
        }
    }

    func signInWithGoogle(presenting viewController: UIViewController) async throws -> (token: String, email: String?, name: String?) {
        #if canImport(GoogleSignIn)
        try ensureFirebaseReady()
        guard let clientID = FirebaseAppHelper.googleClientID else {
            throw AuthServiceError.missingGoogleClientID
        }
        let expectedScheme = FirebaseAppHelper.reversedClientID(from: clientID)
        let registered = FirebaseAppHelper.registeredURLSchemes()
        print("[Mekasa] Google Sign-In clientID=\(clientID)")
        print("[Mekasa] Expected URL scheme=\(expectedScheme)")
        print("[Mekasa] Registered URL schemes=\(registered)")
        guard registered.contains(expectedScheme) else {
            throw AuthServiceError.missingGoogleURLScheme
        }
        do {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
            // GIDSignIn raises NSException (not Swift Error) when the scheme is missing.
            // Catch it so a stale Info.plist cannot terminate the process.
            let result: GIDSignInResult = try await withCheckedThrowingContinuation { continuation in
                do {
                    try MekasaExceptionCatcher.perform {
                        GIDSignIn.sharedInstance.signIn(withPresenting: viewController) { signInResult, error in
                            if let error {
                                continuation.resume(throwing: error)
                            } else if let signInResult {
                                continuation.resume(returning: signInResult)
                            } else {
                                continuation.resume(throwing: AuthServiceError.missingGoogleToken)
                            }
                        }
                    }
                } catch {
                    print("[Mekasa] Google Sign-In NSException caught: \(error.localizedDescription)")
                    continuation.resume(throwing: AuthServiceError.missingGoogleURLScheme)
                }
            }
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthServiceError.missingGoogleToken
            }
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            let authResult = try await Auth.auth().signIn(with: credential)
            let token = try await authResult.user.getIDToken()
            return (token, authResult.user.email, authResult.user.displayName)
        } catch let error as AuthServiceError {
            throw error
        } catch {
            throw AuthErrorFormatter.wrap(error)
        }
        #else
        throw AuthServiceError.firebaseMissing
        #endif
    }

    func signOut() throws {
        if FirebaseBootstrap.isConfigured {
            try Auth.auth().signOut()
        }
        #if canImport(GoogleSignIn)
        GIDSignIn.sharedInstance.signOut()
        #endif
    }

    /// Force-refresh the Firebase ID token used as the Cloud Run bearer.
    /// Satisfies: REQ-022 AC2
    /// Spec version: 1.0
    func refreshIDToken(forcingRefresh: Bool = true) async throws -> String {
        try ensureFirebaseReady()
        guard let user = Auth.auth().currentUser else {
            throw AuthServiceError.sessionExpired
        }
        do {
            return try await user.getIDToken(forcingRefresh: forcingRefresh)
        } catch {
            throw AuthErrorFormatter.wrap(error)
        }
    }

    /// Observe Firebase Auth user changes (nil ⇒ signed out / session ended).
    @discardableResult
    func addAuthStateListener(_ handler: @escaping @MainActor (Bool) -> Void) -> AuthStateDidChangeListenerHandle? {
        guard FirebaseBootstrap.isConfigured || {
            FirebaseBootstrap.configure()
            return FirebaseBootstrap.isConfigured
        }() else {
            return nil
        }
        return Auth.auth().addStateDidChangeListener { _, user in
            Task { @MainActor in
                handler(user != nil)
            }
        }
    }

    func removeAuthStateListener(_ handle: AuthStateDidChangeListenerHandle?) {
        guard let handle, FirebaseBootstrap.isConfigured else { return }
        Auth.auth().removeStateDidChangeListener(handle)
    }

    private func ensureFirebaseReady() throws {
        FirebaseBootstrap.configure()
        guard FirebaseBootstrap.isConfigured else {
            throw AuthServiceError.firebaseMissing
        }
    }
}

enum AuthServiceError: LocalizedError, Equatable {
    case firebaseMissing
    case missingGoogleToken
    case missingGoogleClientID
    case missingGoogleURLScheme
    case cancelled
    case sessionExpired
    case firebaseAuthFailed(String)

    var errorDescription: String? {
        switch self {
        case .firebaseMissing:
            return "Firebase is not configured. Put GoogleService-Info.plist in ios/Mekasa/, ensure Target Membership + Copy Bundle Resources include it, run `cd ios && xcodegen generate`, then Clean + Run."
        case .missingGoogleToken:
            return "Google Sign-In did not return an ID token."
        case .missingGoogleClientID:
            return "GoogleService-Info.plist is missing CLIENT_ID. Enable Google Sign-In in Firebase and recreate the iOS OAuth client, then re-download the plist."
        case .missingGoogleURLScheme:
            return "Info.plist is missing the Google URL scheme (com.googleusercontent.apps.…). Run ios/scripts/sync_google_signin_config.sh, then xcodegen generate, Clean + Run."
        case .cancelled:
            return "Sign-in was cancelled."
        case .sessionExpired:
            return "Your session expired. Please sign in again."
        case let .firebaseAuthFailed(detail):
            return detail
        }
    }
}

/// Digs into Firebase's nested NSError / HTTP JSON so alerts aren't just "internal error".
enum AuthErrorFormatter {
    static func wrap(_ error: Error) -> AuthServiceError {
        let detail = detailString(from: error)
        print("[Mekasa] Auth NSError detail: \(detail)")
        return .firebaseAuthFailed(detail)
    }

    private static func detailString(from error: Error) -> String {
        let ns = error as NSError
        var parts: [String] = [
            "code=\(ns.code)",
            ns.localizedDescription,
        ]

        if let name = ns.userInfo["FIRAuthErrorUserInfoNameKey"] as? String
            ?? ns.userInfo["error_name"] as? String {
            parts.append(name)
        }

        // Common FIRAuthErrorDomain codes (see Firebase Auth iOS errors docs).
        switch ns.code {
        case 17004, 17009, 17011: // invalidCredential (enumeration-protected), wrongPassword, userNotFound
            parts.append(
                "HINT: Wrong password — or this account signs in with Google and has no password yet. "
                    + "Use that button, or tap Forgot password? to set one."
            )
        case 17025: // operationNotAllowed
            parts.append("HINT: Enable Email/Password and Google in Firebase Authentication → Sign-in method.")
        case 17008: // invalidEmail
            parts.append("HINT: Email looks invalid.")
        case 17007: // emailAlreadyInUse
            parts.append("HINT: Account exists — try Sign in instead.")
        case 17026: // weakPassword
            parts.append("HINT: Use a stronger password (6+ chars).")
        case 17020: // networkError
            parts.append("HINT: Network/API blocked — check Identity Toolkit API + API key restrictions.")
        case 17999: // internalError
            parts.append("HINT: Enable Identity Toolkit API; ensure Email/Password and Google are ON; loosen API key restrictions or re-download GoogleService-Info.plist.")
        default:
            break
        }

        var underlying: NSError? = ns.userInfo[NSUnderlyingErrorKey] as? NSError
        var depth = 0
        while let current = underlying, depth < 5 {
            parts.append("u[\(depth)]=\(current.domain)#\(current.code)")
            if let data = current.userInfo["data"] as? Data,
               let body = String(data: data, encoding: .utf8),
               !body.isEmpty {
                parts.append("body=\(body)")
            }
            if let deserialized = current.userInfo["FIRAuthErrorUserInfoDeserializedResponseKey"] {
                parts.append("response=\(deserialized)")
            }
            if let nested = current.userInfo[NSUnderlyingErrorKey] as? NSError,
               let data = nested.userInfo["data"] as? Data,
               let body = String(data: data, encoding: .utf8) {
                parts.append("httpBody=\(body)")
            }
            underlying = current.userInfo[NSUnderlyingErrorKey] as? NSError
            depth += 1
        }

        if let deserialized = ns.userInfo["FIRAuthErrorUserInfoDeserializedResponseKey"] {
            parts.append("response=\(deserialized)")
        }

        return parts.joined(separator: " | ")
    }
}

enum FirebaseAppHelper {
    static var googleClientID: String? {
        if let fromPlist = clientIDFromPlist(), !fromPlist.isEmpty {
            return fromPlist
        }
        // FirebaseOptions.clientID is populated from CLIENT_ID when configure() succeeded.
        if let fromOptions = FirebaseApp.app()?.options.clientID, !fromOptions.isEmpty {
            return fromOptions
        }
        return nil
    }

    /// GIDSignIn crashes if Info.plist lacks the *exact* reversed client ID URL scheme.
    static func hasGoogleURLScheme(forClientID clientID: String) -> Bool {
        registeredURLSchemes().contains(reversedClientID(from: clientID))
    }

    static func registeredURLSchemes() -> [String] {
        let types = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
        return types.flatMap { ($0["CFBundleURLSchemes"] as? [String]) ?? [] }
    }

    static func reversedClientID(from clientID: String) -> String {
        // 123-abc.apps.googleusercontent.com → com.googleusercontent.apps.123-abc
        let trimmed = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("com.googleusercontent.apps.") { return trimmed }
        let core = trimmed.replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
        return "com.googleusercontent.apps.\(core)"
    }

    private static func clientIDFromPlist() -> String? {
        guard
            let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
            let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
            let clientID = dict["CLIENT_ID"] as? String,
            !clientID.isEmpty,
            !clientID.contains("ci-stub")
        else { return nil }
        return clientID
    }
}
