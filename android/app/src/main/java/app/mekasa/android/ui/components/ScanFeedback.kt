package app.mekasa.android.ui.components

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.SoundPool
import android.media.ToneGenerator
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import app.mekasa.android.R

/**
 * Audible + haptic confirmation for barcode scans (add path + trash station).
 * Plays bundled [R.raw.scanner_beep] (synced from design/scanner-beep.mp3) plus a
 * short VibrationEffect. Honours the Family → Scan sounds toggle.
 */
object ScanFeedback {
    /** Seconds the trash-station scanner stays disarmed after an accepted scan. */
    const val COOLDOWN_SECONDS = 5

    const val PREFS_NAME = "mekasa_settings"
    const val PREF_SOUNDS_ENABLED = "scan_sounds_enabled"

    private const val VOLUME = 80
    private const val NACK_MS = 250
    private const val HAPTIC_ACCEPTED_MS = 40L
    private const val HAPTIC_UNKNOWN_MS = 80L

    @Volatile
    private var soundPool: SoundPool? = null

    @Volatile
    private var beepSoundId: Int = 0

    @Volatile
    private var beepLoaded: Boolean = false

    fun soundsEnabled(context: Context?): Boolean {
        val ctx = context ?: return true
        return ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(PREF_SOUNDS_ENABLED, true)
    }

    fun setSoundsEnabled(context: Context, enabled: Boolean) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(PREF_SOUNDS_ENABLED, enabled)
            .apply()
    }

    /** Warm the SoundPool so the first accepted scan plays the custom beep. */
    fun prepare(context: Context?) {
        val ctx = context ?: return
        if (!soundsEnabled(ctx)) return
        runCatching { ensurePool(ctx) }
    }

    /** Classic scanner beep (custom mp3) + light buzz — barcode read and matched. */
    fun accepted(context: Context? = null) {
        if (!soundsEnabled(context)) return
        playCustomBeep(context)
        vibrate(context, HAPTIC_ACCEPTED_MS)
    }

    /** Lower "nack" tone + longer buzz — barcode read but not in inventory / failed. */
    fun unknown(context: Context? = null) {
        if (!soundsEnabled(context)) return
        play(ToneGenerator.TONE_PROP_NACK, NACK_MS)
        vibrate(context, HAPTIC_UNKNOWN_MS)
    }

    private fun playCustomBeep(context: Context?) {
        val ctx = context ?: run {
            play(ToneGenerator.TONE_PROP_BEEP, 150)
            return
        }
        runCatching {
            ensurePool(ctx)
            val pool = soundPool ?: return@runCatching
            if (beepLoaded && beepSoundId != 0) {
                pool.play(beepSoundId, 1f, 1f, 1, 0, 1f)
            } else {
                play(ToneGenerator.TONE_PROP_BEEP, 150)
            }
        }.onFailure {
            play(ToneGenerator.TONE_PROP_BEEP, 150)
        }
    }

    private fun ensurePool(context: Context) {
        if (soundPool != null) return
        synchronized(this) {
            if (soundPool != null) return
            val attrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            val pool = SoundPool.Builder()
                .setMaxStreams(2)
                .setAudioAttributes(attrs)
                .build()
            pool.setOnLoadCompleteListener { _, sampleId, status ->
                if (status == 0 && sampleId == beepSoundId) {
                    beepLoaded = true
                }
            }
            beepSoundId = pool.load(context, R.raw.scanner_beep, 1)
            soundPool = pool
        }
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
