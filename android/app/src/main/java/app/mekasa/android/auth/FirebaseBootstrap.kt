package app.mekasa.android.auth

import android.content.Context
import android.util.Log
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions

/**
 * Initializes Firebase when a real `google-services.json` is present.
 * The committed CI stub (`project_id` = mekasa-ci-stub) skips configure so
 * builds and offline preview never crash on placeholder credentials.
 */
object FirebaseBootstrap {
    @Volatile
    var isConfigured: Boolean = false
        private set

    private var didRun = false

    fun configure(context: Context) {
        if (didRun) return
        didRun = true
        val appContext = context.applicationContext
        val options = runCatching { FirebaseOptions.fromResource(appContext) }.getOrNull()
        if (options == null) {
            Log.i(TAG, "Firebase not configured — google-services.json missing from the app")
            return
        }
        if (options.projectId == STUB_PROJECT_ID) {
            Log.i(TAG, "Firebase skipped — CI stub google-services.json")
            return
        }
        try {
            if (FirebaseApp.getApps(appContext).isEmpty()) {
                FirebaseApp.initializeApp(appContext, options)
            }
            isConfigured = FirebaseApp.getApps(appContext).isNotEmpty()
            Log.i(TAG, "Firebase configured OK (project=${options.projectId})")
        } catch (e: Exception) {
            Log.w(TAG, "Firebase configure failed: ${e.message}")
            isConfigured = false
        }
    }

    private const val STUB_PROJECT_ID = "mekasa-ci-stub"
    private const val TAG = "MekasaFirebase"
}
