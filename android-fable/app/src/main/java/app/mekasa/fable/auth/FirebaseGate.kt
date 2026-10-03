package app.mekasa.fable.auth

import android.content.Context
import android.util.Log
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions

/**
 * Decides once per process whether Firebase is usable. The repo ships a CI stub
 * `google-services.json` (project id [STUB_PROJECT_ID]); with that file present we
 * deliberately skip `FirebaseApp.initializeApp` so Auth calls never hit fake keys.
 */
object FirebaseGate {
    private const val TAG = "FirebaseGate"
    private const val STUB_PROJECT_ID = "mekasa-ci-stub"

    @Volatile
    var isConfigured: Boolean = false
        private set

    @Volatile
    private var initialized = false

    fun initialize(context: Context) {
        if (initialized) return
        initialized = true
        val appContext = context.applicationContext
        val options = runCatching { FirebaseOptions.fromResource(appContext) }.getOrNull()
        when {
            options == null -> Log.i(TAG, "No Firebase options in resources; auth disabled")
            options.projectId == STUB_PROJECT_ID -> Log.i(TAG, "CI stub google-services.json; auth disabled")
            else -> isConfigured = runCatching {
                if (FirebaseApp.getApps(appContext).isEmpty()) {
                    FirebaseApp.initializeApp(appContext, options)
                }
                FirebaseApp.getApps(appContext).isNotEmpty()
            }.onFailure { Log.w(TAG, "Firebase init failed", it) }.getOrDefault(false)
        }
        Log.i(TAG, "Firebase configured=$isConfigured project=${options?.projectId}")
    }
}
