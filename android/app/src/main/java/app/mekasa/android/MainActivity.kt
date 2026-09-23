package app.mekasa.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import app.mekasa.android.session.AppSession
import app.mekasa.android.ui.RootScreen
import app.mekasa.android.ui.theme.MekasaTheme

class MainActivity : ComponentActivity() {
    private val session: AppSession by viewModels {
        object : ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST")
            override fun <T : ViewModel> create(modelClass: Class<T>): T {
                return AppSession() as T
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            MekasaTheme {
                RootScreen(
                    session = session,
                )
            }
        }
    }
}
