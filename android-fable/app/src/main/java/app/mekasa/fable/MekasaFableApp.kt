package app.mekasa.fable

import android.app.Application
import android.os.Build
import android.util.Log
import app.mekasa.fable.auth.FirebaseGate
import app.mekasa.fable.diagnostics.AppLog
import app.mekasa.fable.diagnostics.ClientApp
import app.mekasa.fable.diagnostics.CrashReporting
import app.mekasa.fable.diagnostics.ErrorReporter
import app.mekasa.fable.diagnostics.FileLogStore
import app.mekasa.fable.diagnostics.FileReportStore
import java.io.File

class MekasaFableApp : Application() {

    override fun onCreate() {
        super.onCreate()
        FirebaseGate.initialize(this)
        installDiagnostics()
        installCameraTeardownGuard()
    }

    /** NFR-007: on-device log, error reports (never under Robolectric) and Crashlytics. */
    private fun installDiagnostics() {
        val underTest = Build.FINGERPRINT == ROBOLECTRIC
        if (underTest) return
        val dir = File(filesDir, "diagnostics")
        AppLog.install(FileLogStore(File(dir, "log.jsonl")))
        ErrorReporter.install(
            FileReportStore(File(dir, "reports.json")),
            ClientApp(
                appVersion = BuildConfig.VERSION_NAME,
                build = BuildConfig.VERSION_CODE.toString(),
                osVersion = Build.VERSION.RELEASE ?: "",
                deviceModel = "${Build.MANUFACTURER} ${Build.MODEL}".trim(),
            ),
        )
        ErrorReporter.enabled = true
        CrashReporting.start(enabled = !BuildConfig.DEBUG && FirebaseGate.isConfigured)
        AppLog.info(
            "app",
            "App started",
            mapOf("version" to BuildConfig.VERSION_NAME, "build" to BuildConfig.VERSION_CODE, "firebase" to FirebaseGate.isConfigured),
        )
    }

    /**
     * CameraX / ML Kit can throw from their worker threads while the process is
     * being torn down (surface already released). Those are not actionable, so
     * log them instead of killing the process; everything else goes to the
     * default handler.
     */
    private fun installCameraTeardownGuard() {
        val fallback = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, error ->
            val name = thread.name.lowercase()
            val isCameraWorker = BACKGROUND_WORKER_HINTS.any { name.contains(it) }
            if (isCameraWorker) {
                Log.w(TAG, "Ignoring background teardown failure on ${thread.name}", error)
            } else {
                fallback?.uncaughtException(thread, error)
            }
        }
    }

    private companion object {
        const val TAG = "MekasaFableApp"
        const val ROBOLECTRIC = "robolectric"
        val BACKGROUND_WORKER_HINTS = listOf("camerax", "camera", "mlkit", "pool-")
    }
}
