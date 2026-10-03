package app.mekasa.fable.auth

import android.app.Activity
import android.content.Intent
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.emptyFlow

/** Identity handed to the session after any successful sign-in. */
data class SignedInUser(
    val uid: String,
    val idToken: String,
    val email: String?,
    val displayName: String?,
)

sealed class AuthError(message: String) : Exception(message) {
    class NotConfigured : AuthError(
        "Firebase isn't configured for this build. Drop a real google-services.json in app/, " +
            "or browse the UI offline.",
    )

    class Cancelled : AuthError("Sign-in cancelled")

    class MissingWebClientId : AuthError(
        "Google Sign-In needs a Web OAuth client (client_type 3) in google-services.json.",
    )

    class Rejected(message: String) : AuthError(message)
}

/**
 * Abstraction over Firebase Auth so the session logic can be unit-tested with a fake.
 */
interface AuthGateway {
    val isConfigured: Boolean

    /** Current Firebase uid if a user is cached on device; null otherwise. */
    val currentUid: String?

    /** Emits `false` when Firebase reports the user signed out from underneath us (REQ-022 AC4). */
    val authenticatedChanges: Flow<Boolean> get() = emptyFlow()

    suspend fun signInWithEmail(email: String, password: String): SignedInUser
    suspend fun signUpWithEmail(email: String, password: String): SignedInUser

    /** Restore a session from the cached Firebase user, refreshing the ID token. */
    suspend fun restore(): SignedInUser?

    fun googleSignInIntent(activity: Activity, webClientId: String): Intent
    suspend fun finishGoogleSignIn(data: Intent?): SignedInUser

    /** Force-refresh the ID token; null if no user or refresh failed. */
    suspend fun refreshIdToken(): String?

    fun signOut()
}

/** Gateway used when no Firebase config exists: every call reports [AuthError.NotConfigured]. */
object DisabledAuthGateway : AuthGateway {
    override val isConfigured: Boolean = false
    override val currentUid: String? = null
    override suspend fun signInWithEmail(email: String, password: String): SignedInUser = throw AuthError.NotConfigured()
    override suspend fun signUpWithEmail(email: String, password: String): SignedInUser = throw AuthError.NotConfigured()
    override suspend fun restore(): SignedInUser? = null
    override fun googleSignInIntent(activity: Activity, webClientId: String): Intent = throw AuthError.NotConfigured()
    override suspend fun finishGoogleSignIn(data: Intent?): SignedInUser = throw AuthError.NotConfigured()
    override suspend fun refreshIdToken(): String? = null
    override fun signOut() = Unit
}
