package app.mekasa.fable.diagnostics

import com.google.firebase.crashlytics.FirebaseCrashlytics
import java.security.MessageDigest

/**
 * Firebase Crashlytics for crashes, with the recent [AppLog] entries attached as
 * Crashlytics logs. Collection starts off (manifest) and is turned on only for
 * release builds with a real Firebase project.
 *
 * Satisfies: NFR-007 (App Error Reports and Diagnostics) AC6
 * Spec version: 1.0
 */
object CrashReporting {
    private const val ATTACHED_ENTRIES = 64

    @Volatile var isActive: Boolean = false
        private set

    fun start(enabled: Boolean) {
        if (!enabled || isActive) return
        runCatching {
            val crashlytics = FirebaseCrashlytics.getInstance()
            crashlytics.setCrashlyticsCollectionEnabled(true)
            AppLog.recent(ATTACHED_ENTRIES).forEach { crashlytics.log(AppLog.line(it)) }
            AppLog.addSink { entry -> crashlytics.log(AppLog.line(entry)) }
            isActive = true
        }.onFailure { AppLog.warning("app", "Crashlytics unavailable", mapOf("error_type" to it::class.simpleName)) }
    }

    /** The user appears only as [userRef] (NFR-006 AC6). */
    fun setUser(uid: String?) {
        if (!isActive) return
        runCatching { FirebaseCrashlytics.getInstance().setUserId(uid?.let(::userRef) ?: "") }
    }
}

/** First 12 hex characters of SHA-256(uid), the same `user_ref` the API logs. */
fun userRef(uid: String): String =
    MessageDigest.getInstance("SHA-256").digest(uid.toByteArray()).joinToString("") { "%02x".format(it) }.take(12)
