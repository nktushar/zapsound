package com.zapsound.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.MediaPlayer
import android.net.Uri
import com.zapsound.zapsound_fresh.MainActivity
import java.io.File

class ZapReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            ZapForegroundService.start(context)
            return
        }

        // While the app is foregrounded, MainActivity's MethodChannel handles
        // playback via AudioService instead, to avoid playing the sound twice.
        if (MainActivity.isForeground) return

        ZapForegroundService.start(context)

        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        if (!prefs.getBoolean("flutter.zapsound_enabled", true)) return

        when (intent.action) {
            Intent.ACTION_POWER_CONNECTED -> play(
                context,
                soundId    = prefs.getString("flutter.plug_in_sound",  "s1") ?: "s1",
                customPath = prefs.getString("flutter.custom_in_path",  null),
            )
            Intent.ACTION_POWER_DISCONNECTED -> play(
                context,
                soundId    = prefs.getString("flutter.plug_out_sound", "s2") ?: "s2",
                customPath = prefs.getString("flutter.custom_out_path", null),
            )
        }
    }

    private fun play(context: Context, soundId: String, customPath: String?) {
        if (soundId == "custom" && customPath != null) {
            playFile(context, customPath)
            return
        }
        val resName = soundIdToResName(soundId)
        val resId   = context.resources.getIdentifier(resName, "raw", context.packageName)
        if (resId != 0) playRaw(context, resId)
    }

    private fun playRaw(context: Context, resId: Int) {
        try {
            val mp = MediaPlayer.create(context, resId) ?: return
            mp.setOnCompletionListener { it.release() }
            mp.start()
        } catch (_: Exception) {}
    }

    private fun playFile(context: Context, path: String) {
        try {
            val mp = MediaPlayer()
            mp.setDataSource(context, Uri.fromFile(File(path)))
            mp.setOnCompletionListener { it.release() }
            mp.setOnPreparedListener  { it.start()   }
            mp.prepareAsync()
        } catch (_: Exception) {}
    }

    // Mirrors ZapSoundLibrary IDs in sound_model.dart
    private fun soundIdToResName(id: String): String = when (id) {
        "s1"  -> "power_up"
        "s2"  -> "coin"
        "s3"  -> "beep"
        "s4"  -> "ding"
        "s5"  -> "pop"
        "p1"  -> "cash_register"
        "p2"  -> "level_up"
        "p3"  -> "lightsaber"
        "p4"  -> "fart"
        "p5"  -> "tada"
        "p6"  -> "error"
        "p7"  -> "airhorn"
        "p8"  -> "sword"
        "p9"  -> "laser"
        "p10" -> "notif"
        else  -> "power_up"
    }
}
