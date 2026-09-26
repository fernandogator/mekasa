package app.mekasa.android.ui.components

import android.content.Context
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext

/**
 * Audible + haptic confirmation for barcode scans (add path + trash station).
 * ToneGenerator for the beep; short VibrationEffect alongside it. No audio asset.
 * Best-effort: devices without audio/vibrator (or Robolectric) just skip.
 */
object ScanFeedback {
    /** Seconds the trash-station scanner stays disarmed after an accepted scan. */
    const val COOLDOWN_SECONDS = 5

    private const val VOLUME = 80
    private const val BEEP_MS = 150
    private const val NACK_MS = 250
    private const val HAPTIC_ACCEPTED_MS = 40L
    private const val HAPTIC_UNKNOWN_MS = 80L

    /** Classic short scanner beep + light buzz — barcode read and matched. */
    fun accepted(context: Context? = null) {
        play(ToneGenerator.TONE_PROP_BEEP, BEEP_MS)
        vibrate(context, HAPTIC_ACCEPTED_MS)
    }

    /** Lower "nack" tone + longer buzz — barcode read but not in inventory / failed. */
    fun unknown(context: Context? = null) {
        play(ToneGenerator.TONE_PROP_NACK, NACK_MS)
        vibrate(context, HAPTIC_UNKNOWN_MS)
    }

    private fun play(tone: Int, durationMs: Int) {
        runCatching {
            val generator = ToneGenerator(AudioManager.STREAM_MUSIC, VOLUME)
            generator.startTone(tone, durationMs)
            Thread {
                Thread.sleep(durationMs.toLong() + 50)
                runCatching { generator.release() }
            }.apply { isDaemon = true }.start()
        }
    }

    private fun vibrate(context: Context?, durationMs: Long) {
        val ctx = context ?: return
        runCatching {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val manager = ctx.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                manager.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                ctx.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            if (!vibrator.hasVibrator()) return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(
                    VibrationEffect.createOneShot(durationMs, VibrationEffect.DEFAULT_AMPLITUDE),
                )
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(durationMs)
            }
        }
    }
}

/** Remembers the app [Context] so composables can fire [ScanFeedback] without plumbing. */
@Composable
fun rememberScanFeedbackContext(): Context {
    val context = LocalContext.current
    return remember(context) { context.applicationContext }
}
