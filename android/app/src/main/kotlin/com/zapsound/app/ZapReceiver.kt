package com.zapsound.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class ZapReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        when (intent.action) {
            Intent.ACTION_POWER_CONNECTED    -> play(context, prefs.getString("flutter.plug_in_sound",  "s1") ?: "s1")
            Intent.ACTION_POWER_DISCONNECTED -> play(context, prefs.getString("flutter.plug_out_sound", "s2") ?: "s2")
        }
    }

    private fun play(context: Context, soundId: String) {
        // Sound files will be wired up after assets are added
    }
}
