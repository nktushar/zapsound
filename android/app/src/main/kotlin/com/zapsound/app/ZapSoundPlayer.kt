package com.zapsound.app

import android.content.Context
import android.media.MediaPlayer
import android.net.Uri
import java.io.File

// Shared native playback used by ZapReceiver (charger events) and
// ZapForegroundService (battery-full alert). Sound file names come from
// FlutterSharedPreferences, written by the Dart side from ZapSoundLibrary —
// the raw resource name always matches the asset's basename.
object ZapSoundPlayer {

    fun play(context: Context, fileName: String, customPath: String?) {
        if (fileName == "custom" && customPath != null) {
            playFile(context, customPath)
            return
        }
        playRes(context, fileName)
    }

    fun playRes(context: Context, resName: String) {
        val resId = context.resources.getIdentifier(resName, "raw", context.packageName)
        if (resId == 0) return
        try {
            val mp = MediaPlayer.create(context, resId) ?: return
            mp.setOnCompletionListener { it.release() }
            mp.start()
        } catch (_: Exception) {}
    }

    fun playFile(context: Context, path: String) {
        try {
            val mp = MediaPlayer()
            mp.setDataSource(context, Uri.fromFile(File(path)))
            mp.setOnCompletionListener { it.release() }
            mp.setOnPreparedListener  { it.start()   }
            mp.prepareAsync()
        } catch (_: Exception) {}
    }
}
