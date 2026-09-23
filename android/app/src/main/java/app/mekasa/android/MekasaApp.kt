package app.mekasa.android

import android.app.Application
import app.mekasa.android.auth.FirebaseBootstrap

class MekasaApp : Application() {
    override fun onCreate() {
        super.onCreate()
        FirebaseBootstrap.configure(this)
    }
}
