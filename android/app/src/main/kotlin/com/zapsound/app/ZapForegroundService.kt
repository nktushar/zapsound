package com.zapsound.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

// Minimal foreground service whose only job is to (a) keep the process alive
// and (b) hold a *dynamically* registered receiver for
// ACTION_POWER_CONNECTED/DISCONNECTED. These two actions are not in Android's
// implicit-broadcast exemption list, so a manifest-declared <receiver> for
// them never fires on API 26+ — only a runtime-registered receiver works.
class ZapForegroundService : Service() {

    companion object {
        private const val CHANNEL_ID = "zapsound_keepalive"
        private const val NOTIFICATION_ID = 1001

        fun start(context: Context) {
            val intent = Intent(context, ZapForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
    }

    private val chargerReceiver = ZapReceiver()
    private var chargerReceiverRegistered = false

    // Battery-full alert: ACTION_BATTERY_CHANGED fires repeatedly while
    // charging, so a latch ensures the sound plays once per charge session.
    private var batteryFullFired = false
    private val batteryReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val level  = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
            val scale  = intent.getIntExtra(BatteryManager.EXTRA_SCALE, 100)
            val pct = if (scale > 0 && level >= 0) level * 100 / scale else -1
            // EXTRA_PLUGGED rather than EXTRA_STATUS: at 100% many devices
            // report NOT_CHARGING while still on power.
            val plugged = intent.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) != 0
            if (!plugged || pct < 100) {
                batteryFullFired = false
                return
            }
            if (batteryFullFired) return
            batteryFullFired = true

            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            if (!prefs.getBoolean("flutter.zapsound_enabled", true)) return
            if (!prefs.getBoolean("flutter.battery_full_enabled", false)) return
            if (ZapSoundPlayer.isQuietNow(prefs)) return
            ZapSoundPlayer.playRes(
                context,
                prefs.getString("flutter.battery_full_file", "ding") ?: "ding",
            )
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
        if (!chargerReceiverRegistered) {
            val filter = IntentFilter().apply {
                addAction(Intent.ACTION_POWER_CONNECTED)
                addAction(Intent.ACTION_POWER_DISCONNECTED)
            }
            registerReceiver(chargerReceiver, filter)
            registerReceiver(batteryReceiver, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            chargerReceiverRegistered = true
        }
    }

    override fun onDestroy() {
        if (chargerReceiverRegistered) {
            unregisterReceiver(chargerReceiver)
            unregisterReceiver(batteryReceiver)
            chargerReceiverRegistered = false
        }
        super.onDestroy()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "ZapSound background service",
                NotificationManager.IMPORTANCE_MIN,
            ).apply {
                description = "Keeps ZapSound listening for charger plug/unplug"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("ZapSound is active")
            .setContentText("Listening for charger plug/unplug")
            .setSmallIcon(R.drawable.ic_stat_zap)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setOngoing(true)
            .build()
}
