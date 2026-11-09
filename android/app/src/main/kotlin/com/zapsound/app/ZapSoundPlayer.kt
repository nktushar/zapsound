package com.zapsound.app

import android.content.Context
import android.content.SharedPreferences
import android.media.MediaPlayer
import android.net.Uri
import java.io.File
import java.util.Calendar

// Shared native playback used by ZapReceiver (charger events) and
// ZapForegroundService (battery-full alert). Sound file names come from
// FlutterSharedPreferences, written by the Dart side from ZapSoundLibrary —
// the raw resource name always matches the asset's basename.
object ZapSoundPlayer {

    // shared_preferences stores Dart ints as Long under the "flutter." prefix.
    private fun volume(context: Context): Float {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        return prefs.getLong("flutter.volume_pct", 100L).coerceIn(0L, 100L) / 100f
    }

    // Quiet hours window may wrap past midnight (e.g. 22:00 → 07:00).
    // Mirrors PrefsService.isQuietNow() on the Dart side.
    fun isQuietNow(prefs: SharedPreferences): Boolean {
        if (!prefs.getBoolean("flutter.quiet_hours_enabled", false)) return false
        val start = prefs.getLong("flutter.quiet_start_min", 22 * 60L).toInt()
        val end   = prefs.getLong("flutter.quiet_end_min", 7 * 60L).toInt()
        if (start == end) return false
        val cal = Calendar.getInstance()
        val now = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
        return if (start < end) now in start until end else (now >= start || now < end)
    }

    fun play(context: Context, fileName: String, customPath: String?) {
        if (fileName == "custom" && customPath != null) {
            playFile(context, customPath)
            return
        }
        playRes(context, fileName)
    }

    // Players must stay strongly referenced until they finish: a MediaPlayer
    // held only by a local is garbage-collected mid-sound ("finalized without
    // being released"), cutting the sound off.
    private val active = mutableSetOf<MediaPlayer>()

    private fun track(mp: MediaPlayer, context: Context) {
        val v = volume(context)
        mp.setVolume(v, v)
        synchronized(active) { active.add(mp) }
        val done = { p: MediaPlayer ->
            synchronized(active) { active.remove(p) }
            p.release()
        }
        mp.setOnCompletionListener { done(it) }
        mp.setOnErrorListener { p, _, _ -> done(p); true }
    }

    fun playRes(context: Context, resName: String) {
        val resId = context.resources.getIdentifier(resName, "raw", context.packageName)
        if (resId == 0) return
        try {
            val mp = MediaPlayer.create(context, resId) ?: return
            track(mp, context)
            mp.start()
        } catch (_: Exception) {}
    }

    fun playFile(context: Context, path: String) {
        try {
            val mp = MediaPlayer()
            mp.setDataSource(context, Uri.fromFile(File(path)))
            track(mp, context)
            mp.setOnPreparedListener { it.start() }
            mp.prepareAsync()
        } catch (_: Exception) {}
    }
}
