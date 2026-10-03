package app.mekasa.fable

import android.app.Application
import android.util.Log
import app.mekasa.fable.auth.FirebaseGate

class MekasaFableApp : Application() {

    override fun onCreate() {
        super.onCreate()
        FirebaseGate.initialize(this)
        installCameraTeardownGuard()
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
        val BACKGROUND_WORKER_HINTS = listOf("camerax", "camera", "mlkit", "pool-")
    }
}
