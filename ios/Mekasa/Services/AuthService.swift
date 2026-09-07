import Foundation
import AuthenticationServices
import UIKit
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

/// Firebase Auth (Email + Google). Falls back to a clear error if Firebase isn't linked.
/// Satisfies: REQ-001 (Household Account Creation) AC1–AC3
/// Spec version: 1.0
@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    var isFirebaseConfigured: Bool {
        #if canImport(FirebaseCore)
        return Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
        #else
        return false
        #endif
    }

    func signIn(email: String, password: String) async throws -> (token: String, email: String?, name: String?) {
        #if canImport(FirebaseAuth)
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        let token = try await result.user.getIDToken()
        return (token, result.user.email, result.user.displayName)
        #else
        throw AuthServiceError.firebaseMissing
        #endif
    }

    func signUp(email: String, password: String) async throws -> (token: String, email: String?, name: String?) {
        #if canImport(FirebaseAuth)
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let token = try await result.user.getIDToken()
        return (token, result.user.email, result.user.displayName)
        #else
        throw AuthServiceError.firebaseMissing
        #endif
    }

    func signInWithGoogle(presenting viewController: UIViewController) async throws -> (token: String, email: String?, name: String?) {
        #if canImport(GoogleSignIn) && canImport(FirebaseAuth)
        guard let clientID = FirebaseAppHelper.googleClientID else {
            throw AuthServiceError.firebaseMissing
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
        #if canImport(FirebaseAuth)
        try Auth.auth().signOut()
        #endif
        #if canImport(GoogleSignIn)
        GIDSignIn.sharedInstance.signOut()
        #endif
    }
}

enum AuthServiceError: LocalizedError {
    case firebaseMissing
    case missingGoogleToken

    var errorDescription: String? {
        switch self {
        case .firebaseMissing:
            return "Add GoogleService-Info.plist and Firebase SPM packages (see ios/README.md)."
        case .missingGoogleToken:
            return "Google Sign-In did not return an ID token."
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
