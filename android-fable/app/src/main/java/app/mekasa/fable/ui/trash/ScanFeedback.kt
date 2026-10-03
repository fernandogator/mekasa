package app.mekasa.fable.ui.trash

import android.media.AudioManager
import android.media.ToneGenerator

/**
 * Audible confirmation for trash-station scans (REQ-008). Uses the platform tone
 * generator so no audio asset ships with the app; respects the media volume.
 * Every call is best-effort: devices without audio hardware (or Robolectric) just skip it.
 */
object ScanFeedback {
    /** Seconds the scanner stays disarmed after an accepted scan. */
    const val COOLDOWN_SECONDS = 5

    private const val VOLUME = 80
    private const val BEEP_MS = 150
    private const val NACK_MS = 250

    /** Classic short scanner beep — barcode read and matched. */
    fun accepted() = play(ToneGenerator.TONE_PROP_BEEP, BEEP_MS)

    /** Lower "nack" tone — barcode read but not in inventory. */
    fun unknown() = play(ToneGenerator.TONE_PROP_NACK, NACK_MS)

    private fun play(tone: Int, durationMs: Int) {
        runCatching {
            val generator = ToneGenerator(AudioManager.STREAM_MUSIC, VOLUME)
            generator.startTone(tone, durationMs)
            // Release after the tone finishes; ToneGenerator holds an audio track.
            Thread {
                Thread.sleep(durationMs.toLong() + 50)
                runCatching { generator.release() }
            }.apply { isDaemon = true }.start()
        }
    }
}
