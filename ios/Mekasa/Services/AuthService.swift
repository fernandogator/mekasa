import Foundation
import AuthenticationServices
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
        do {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
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

    private func ensureFirebaseReady() throws {
        FirebaseBootstrap.configure()
        guard FirebaseBootstrap.isConfigured else {
            throw AuthServiceError.firebaseMissing
        }
    }
}

enum AuthServiceError: LocalizedError {
    case firebaseMissing
    case missingGoogleToken
    case missingGoogleClientID
    case firebaseAuthFailed(String)

    var errorDescription: String? {
        switch self {
        case .firebaseMissing:
            return "Firebase is not configured. Put GoogleService-Info.plist in ios/Mekasa/, ensure Target Membership + Copy Bundle Resources include it, run `cd ios && xcodegen generate`, then Clean + Run."
        case .missingGoogleToken:
            return "Google Sign-In did not return an ID token."
        case .missingGoogleClientID:
            return "GoogleService-Info.plist is missing CLIENT_ID. Enable Google Sign-In in Firebase and recreate the iOS OAuth client, then re-download the plist."
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

        if let authCode = AuthErrorCode(rawValue: ns.code) {
            parts.append("auth=\(authCode)")
            switch authCode {
            case .operationNotAllowed:
                parts.append("HINT: Enable Email/Password in Firebase Authentication → Sign-in method.")
            case .invalidEmail:
                parts.append("HINT: Email looks invalid.")
            case .emailAlreadyInUse:
                parts.append("HINT: Account exists — try Sign in instead.")
            case .weakPassword:
                parts.append("HINT: Use a stronger password (6+ chars).")
            case .networkError:
                parts.append("HINT: Network/API blocked — check Identity Toolkit API + API key restrictions.")
            case .internalError:
                parts.append("HINT: Often Identity Toolkit API disabled, API key restricted, or Email/Password not enabled.")
            default:
                break
            }
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
        guard
            let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
            let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
            let clientID = dict["CLIENT_ID"] as? String
        else { return nil }
        return clientID
    }
}
