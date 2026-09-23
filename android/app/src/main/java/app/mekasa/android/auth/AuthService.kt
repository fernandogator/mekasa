package app.mekasa.android.auth

import android.app.Activity
import android.content.Intent
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.android.gms.common.api.ApiException
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.GoogleAuthProvider
import kotlinx.coroutines.tasks.await

data class AuthResult(
    val token: String,
    val email: String?,
    val displayName: String?,
    val uid: String,
)

sealed class AuthException(message: String) : Exception(message) {
    class NotConfigured : AuthException(
        "Firebase is not configured. Add a real google-services.json (see android/app/google-services.json.example), or use Browse UI offline.",
    )
    class Cancelled : AuthException("Sign-in cancelled")
    class MissingGoogleClient : AuthException(
        "Google Sign-In needs a Web client ID in google-services.json (OAuth client type 3).",
    )
    class Failed(message: String) : AuthException(message)
}

/**
 * Firebase Auth (email + Google). Mirrors iOS AuthService.
 */
class AuthService(
    private val auth: FirebaseAuth? = if (FirebaseBootstrap.isConfigured) FirebaseAuth.getInstance() else null,
) {
    val isFirebaseConfigured: Boolean get() = FirebaseBootstrap.isConfigured

    val currentUserUid: String? get() = auth?.currentUser?.uid

    suspend fun signIn(email: String, password: String): AuthResult {
        val firebase = requireAuth()
        return try {
            val result = firebase.signInWithEmailAndPassword(email, password).await()
            val user = result.user ?: throw AuthException.Failed("No Firebase user after sign-in")
            AuthResult(
                token = user.getIdToken(false).await().token
                    ?: throw AuthException.Failed("Missing ID token"),
                email = user.email,
                displayName = user.displayName,
                uid = user.uid,
            )
        } catch (e: AuthException) {
            throw e
        } catch (e: Exception) {
            throw AuthException.Failed(e.message ?: "Sign-in failed")
        }
    }

    suspend fun signUp(email: String, password: String): AuthResult {
        val firebase = requireAuth()
        return try {
            val result = firebase.createUserWithEmailAndPassword(email, password).await()
            val user = result.user ?: throw AuthException.Failed("No Firebase user after sign-up")
            AuthResult(
                token = user.getIdToken(false).await().token
                    ?: throw AuthException.Failed("Missing ID token"),
                email = user.email,
                displayName = user.displayName,
                uid = user.uid,
            )
        } catch (e: AuthException) {
            throw e
        } catch (e: Exception) {
            throw AuthException.Failed(e.message ?: "Sign-up failed")
        }
    }

    fun googleSignInIntent(activity: Activity, webClientId: String): Intent {
        val options = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
            .requestIdToken(webClientId)
            .requestEmail()
            .build()
        return GoogleSignIn.getClient(activity, options).signInIntent
    }

    suspend fun completeGoogleSignIn(data: Intent?): AuthResult {
        val firebase = requireAuth()
        return try {
            val task = GoogleSignIn.getSignedInAccountFromIntent(data)
            val account = task.getResult(ApiException::class.java)
            val idToken = account.idToken ?: throw AuthException.Failed("Missing Google ID token")
            val credential = GoogleAuthProvider.getCredential(idToken, null)
            val result = firebase.signInWithCredential(credential).await()
            val user = result.user ?: throw AuthException.Failed("No Firebase user after Google sign-in")
            AuthResult(
                token = user.getIdToken(false).await().token
                    ?: throw AuthException.Failed("Missing ID token"),
                email = user.email ?: account.email,
                displayName = user.displayName ?: account.displayName,
                uid = user.uid,
            )
        } catch (e: ApiException) {
            if (e.statusCode == 12501) throw AuthException.Cancelled()
            throw AuthException.Failed(e.message ?: "Google sign-in failed")
        } catch (e: AuthException) {
            throw e
        } catch (e: Exception) {
            throw AuthException.Failed(e.message ?: "Google sign-in failed")
        }
    }

    suspend fun refreshIdToken(force: Boolean = true): String? {
        val user = auth?.currentUser ?: return null
        return runCatching { user.getIdToken(force).await().token }.getOrNull()
    }

    fun signOut() {
        auth?.signOut()
    }

    private fun requireAuth(): FirebaseAuth {
        val firebase = auth
        if (!isFirebaseConfigured || firebase == null) throw AuthException.NotConfigured()
        return firebase
    }
}
