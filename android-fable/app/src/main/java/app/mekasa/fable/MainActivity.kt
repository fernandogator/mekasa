package app.mekasa.fable

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import app.mekasa.fable.auth.FirebaseAuthGateway
import app.mekasa.fable.auth.FirebaseGate
import app.mekasa.fable.data.remote.KtorMekasaApi
import app.mekasa.fable.session.PrefsEmailMemory
import app.mekasa.fable.session.SessionViewModel
import app.mekasa.fable.ui.MekasaRoot
import app.mekasa.fable.ui.theme.MekasaTheme

class MainActivity : ComponentActivity() {

    private val session: SessionViewModel by viewModels {
        object : ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST")
            override fun <T : ViewModel> create(modelClass: Class<T>): T {
                val api = KtorMekasaApi(BuildConfig.API_BASE_URL, enableLogging = BuildConfig.DEBUG)
                return SessionViewModel(
                    api = api,
                    auth = FirebaseAuthGateway(configured = FirebaseGate.isConfigured),
                    emailMemory = PrefsEmailMemory(applicationContext),
                    allowTestTokenSignIn = BuildConfig.ALLOW_TEST_TOKEN_SIGN_IN,
                ) as T
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        session.onInviteLink(intent?.dataString)
        setContent {
            MekasaTheme {
                MekasaRoot(session = session)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        session.onInviteLink(intent.dataString)
    }
}
