package app.mekasa.android

import android.app.Application
import android.util.Log
import app.mekasa.android.auth.FirebaseBootstrap

class MekasaApp : Application() {
    override fun onCreate() {
        super.onCreate()
        setupUncaughtExceptionHandler()
        FirebaseBootstrap.configure(this)
    }

    private fun setupUncaughtExceptionHandler() {
        val defaultHandler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            Log.e(TAG, "Uncaught exception on thread ${thread.name}", throwable)
            // Catch background teardown exceptions so the app process doesn't crash during exit/teardown
            if (thread.name.contains("executor", ignoreCase = true) ||
                thread.name.contains("camera", ignoreCase = true) ||
                thread.name.contains("mlkit", ignoreCase = true)
            ) {
                Log.w(TAG, "Swallowed background teardown exception on ${thread.name}")
                return@setDefaultUncaughtExceptionHandler
            }
            defaultHandler?.uncaughtException(thread, throwable)
        }
    }

    companion object {
        private const val TAG = "MekasaApp"
    }
}

