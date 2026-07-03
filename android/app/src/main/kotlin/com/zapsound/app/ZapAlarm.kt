package com.zapsound.app

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer

// Anti-theft siren: loops the alarm sound at max alarm-stream volume until
// dismissed with the PIN in AlarmActivity. The sound is driven from here (not
// the activity) so it starts instantly from ZapReceiver even if the
// full-screen activity launch is delayed or blocked.
object ZapAlarm {

    @Volatile
    var isActive = false
        private set

    private var player: MediaPlayer? = null
    private var previousVolume = -1

    @Synchronized
    fun start(context: Context) {
        if (isActive) return
        isActive = true
        try {
            val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            previousVolume = am.getStreamVolume(AudioManager.STREAM_ALARM)
            am.setStreamVolume(AudioManager.STREAM_ALARM, am.getStreamMaxVolume(AudioManager.STREAM_ALARM), 0)

            val attrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            player = MediaPlayer.create(context, R.raw.siren, attrs, 0)?.apply {
                isLooping = true
                start()
            }
        } catch (_: Exception) {}
    }

    @Synchronized
    fun stop(context: Context) {
        if (!isActive) return
        isActive = false
        try {
            player?.stop()
            player?.release()
        } catch (_: Exception) {}
        player = null
        if (previousVolume >= 0) {
            try {
                val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
                am.setStreamVolume(AudioManager.STREAM_ALARM, previousVolume, 0)
            } catch (_: Exception) {}
            previousVolume = -1
        }
    }
}
