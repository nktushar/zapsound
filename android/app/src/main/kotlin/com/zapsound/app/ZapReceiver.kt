package com.zapsound.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.zapsound.zapsound_fresh.MainActivity
import com.zapsound.zapsound_fresh.R

class ZapReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            ZapForegroundService.start(context)
            return
        }

        // Anti-theft fires regardless of foreground state and replaces the
        // normal unplug sound.
        if (intent.action == Intent.ACTION_POWER_DISCONNECTED) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val armed = prefs.getBoolean("flutter.antitheft_armed", false)
            val hasPin = prefs.getString("flutter.antitheft_pin", null) != null
            if (armed && hasPin) {
                ZapAlarm.start(context)
                showAlarmScreen(context)
                return
            }
        }

        // While the app is foregrounded, MainActivity's MethodChannel handles
        // playback via AudioService instead, to avoid playing the sound twice.
        if (MainActivity.isForeground) return

        ZapForegroundService.start(context)

        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        if (!prefs.getBoolean("flutter.zapsound_enabled", true)) return

        // Sound file names are written by the Dart side on selection; the
        // defaults mirror ZapSoundLibrary's defaults (s1 = power_up, s2 = coin).
        when (intent.action) {
            Intent.ACTION_POWER_CONNECTED -> ZapSoundPlayer.play(
                context,
                fileName   = prefs.getString("flutter.plug_in_file",  "power_up") ?: "power_up",
                customPath = prefs.getString("flutter.custom_in_path",  null),
            )
            Intent.ACTION_POWER_DISCONNECTED -> ZapSoundPlayer.play(
                context,
                fileName   = prefs.getString("flutter.plug_out_file", "coin") ?: "coin",
                customPath = prefs.getString("flutter.custom_out_path", null),
            )
        }
    }

    // Launches the PIN screen over the lock screen. A full-screen-intent
    // notification is the only launch path allowed from the background on
    // Android 10+; when the app is foregrounded we start it directly.
    private fun showAlarmScreen(context: Context) {
        val alarmIntent = Intent(context, AlarmActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)

        if (MainActivity.isForeground) {
            try {
                context.startActivity(alarmIntent)
                return
            } catch (_: Exception) {}
        }

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(
                    "zapsound_alarm",
                    "Anti-theft alarm",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "Shown when the anti-theft alarm is triggered"
                    setSound(null, null) // the siren is played by ZapAlarm
                },
            )
        }
        val fullScreen = PendingIntent.getActivity(
            context, 0, alarmIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(context, "zapsound_alarm")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Charger removed!")
            .setContentText("Tap to enter your PIN and stop the alarm")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setOngoing(true)
            .setFullScreenIntent(fullScreen, true)
            .build()
        nm.notify(2002, notification)
    }
}
