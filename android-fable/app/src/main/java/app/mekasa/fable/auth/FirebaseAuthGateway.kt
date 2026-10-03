package app.mekasa.fable.auth

import android.app.Activity
import android.content.Intent
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.common.api.CommonStatusCodes
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.FirebaseAuthInvalidCredentialsException
import com.google.firebase.auth.FirebaseAuthInvalidUserException
import com.google.firebase.auth.FirebaseAuthUserCollisionException
import com.google.firebase.auth.FirebaseAuthWeakPasswordException
import com.google.firebase.auth.FirebaseUser
import com.google.firebase.auth.GoogleAuthProvider
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.tasks.await

/**
 * Firebase Auth + legacy Google Sign-In (play-services-auth) implementation.
 * When [configured] is false every entry point throws [AuthError.NotConfigured]
 * instead of touching `FirebaseAuth.getInstance()`, which would crash on the stub config.
 */
class FirebaseAuthGateway(
    private val configured: Boolean,
) : AuthGateway {

    private val firebase: FirebaseAuth? by lazy { if (configured) FirebaseAuth.getInstance() else null }

    override val isConfigured: Boolean get() = configured

    override val currentUid: String? get() = firebase?.currentUser?.uid

    override val authenticatedChanges: Flow<Boolean>
        get() {
            val auth = firebase ?: return super.authenticatedChanges
            return callbackFlow {
                val listener = FirebaseAuth.AuthStateListener { trySend(it.currentUser != null) }
                auth.addAuthStateListener(listener)
                awaitClose { auth.removeAuthStateListener(listener) }
            }.distinctUntilChanged()
        }

    override suspend fun signInWithEmail(email: String, password: String): SignedInUser = guarded {
        val result = requireAuth().signInWithEmailAndPassword(email.trim(), password).await()
        result.user.toSignedInUser("Sign-in returned no user")
    }

    override suspend fun signUpWithEmail(email: String, password: String): SignedInUser = guarded {
        val result = requireAuth().createUserWithEmailAndPassword(email.trim(), password).await()
        result.user.toSignedInUser("Sign-up returned no user")
    }

    override suspend fun restore(): SignedInUser? {
        val user = firebase?.currentUser ?: return null
        return runCatching { user.toSignedInUser("No cached user", forceRefresh = true) }.getOrNull()
    }

    override fun googleSignInIntent(activity: Activity, webClientId: String): Intent {
        if (!configured) throw AuthError.NotConfigured()
        val options = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
            .requestIdToken(webClientId)
            .requestEmail()
            .build()
        return GoogleSignIn.getClient(activity, options).signInIntent
    }

    override suspend fun finishGoogleSignIn(data: Intent?): SignedInUser = guarded {
        val account = try {
            GoogleSignIn.getSignedInAccountFromIntent(data).getResult(ApiException::class.java)
        } catch (e: ApiException) {
            if (e.statusCode == GOOGLE_SIGN_IN_CANCELLED || e.statusCode == CommonStatusCodes.CANCELED) {
                throw AuthError.Cancelled()
            }
            throw AuthError.Rejected("Google sign-in failed (${e.statusCode})")
        }
        val googleToken = account.idToken ?: throw AuthError.Rejected("Google returned no ID token")
        val credential = GoogleAuthProvider.getCredential(googleToken, null)
        val result = requireAuth().signInWithCredential(credential).await()
        val user = result.user.toSignedInUser("Google sign-in returned no user")
        user.copy(
            email = user.email ?: account.email,
            displayName = user.displayName ?: account.displayName,
        )
    }

    override suspend fun refreshIdToken(): String? {
        val user = firebase?.currentUser ?: return null
        return runCatching { user.getIdToken(true).await().token }.getOrNull()
    }

    override fun signOut() {
        firebase?.signOut()
    }

    // --------------------------------------------------------------- helpers

    private fun requireAuth(): FirebaseAuth = firebase ?: throw AuthError.NotConfigured()

    private suspend fun FirebaseUser?.toSignedInUser(
        missingMessage: String,
        forceRefresh: Boolean = false,
    ): SignedInUser {
        val user = this ?: throw AuthError.Rejected(missingMessage)
        val token = user.getIdToken(forceRefresh).await().token
            ?: throw AuthError.Rejected("Firebase returned no ID token")
        return SignedInUser(
            uid = user.uid,
            idToken = token,
            email = user.email,
            displayName = user.displayName,
        )
    }

    /** Normalises Firebase exceptions into [AuthError] with copy a person can act on. */
    private suspend fun <T> guarded(block: suspend () -> T): T {
        try {
            return block()
        } catch (e: AuthError) {
            throw e
        } catch (e: FirebaseAuthWeakPasswordException) {
            throw AuthError.Rejected("Password is too weak: use at least 6 characters.")
        } catch (e: FirebaseAuthInvalidCredentialsException) {
            throw AuthError.Rejected("Email or password is incorrect.")
        } catch (e: FirebaseAuthInvalidUserException) {
            throw AuthError.Rejected("No account exists for that email. Create one instead.")
        } catch (e: FirebaseAuthUserCollisionException) {
            throw AuthError.Rejected("An account already exists for that email. Sign in instead.")
        } catch (e: Exception) {
            throw AuthError.Rejected(e.message ?: "Authentication failed")
        }
    }

    private companion object {
        /** GoogleSignInStatusCodes.SIGN_IN_CANCELLED */
        const val GOOGLE_SIGN_IN_CANCELLED = 12501
    }
}
