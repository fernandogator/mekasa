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
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        let token = try await result.user.getIDToken()
        return (token, result.user.email, result.user.displayName)
    }

    func signUp(email: String, password: String) async throws -> (token: String, email: String?, name: String?) {
        try ensureFirebaseReady()
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let token = try await result.user.getIDToken()
        return (token, result.user.email, result.user.displayName)
    }

    func signInWithGoogle(presenting viewController: UIViewController) async throws -> (token: String, email: String?, name: String?) {
        #if canImport(GoogleSignIn)
        try ensureFirebaseReady()
        guard let clientID = FirebaseAppHelper.googleClientID else {
            throw AuthServiceError.missingGoogleClientID
        }
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

    var errorDescription: String? {
        switch self {
        case .firebaseMissing:
            return "Firebase is not configured. Put GoogleService-Info.plist in ios/Mekasa/, ensure Target Membership + Copy Bundle Resources include it, run `cd ios && xcodegen generate`, then Clean + Run."
        case .missingGoogleToken:
            return "Google Sign-In did not return an ID token."
        case .missingGoogleClientID:
            return "GoogleService-Info.plist is missing CLIENT_ID. Enable Google Sign-In in Firebase and recreate the iOS OAuth client, then re-download the plist."
        }
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
