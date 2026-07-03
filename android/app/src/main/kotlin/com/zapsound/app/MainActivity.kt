package com.zapsound.app

import android.Manifest
import android.app.AlertDialog
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        // Read by ZapReceiver to avoid playing the sound twice (once natively,
        // once via the MethodChannel) while the app is in the foreground.
        @Volatile
        var isForeground = false
    }

    private val CHANNEL = "com.zapsound.app/charger"
    private var methodChannel: MethodChannel? = null

    private val REQUEST_POST_NOTIFICATIONS = 2001
    private val REQUEST_RECORD_AUDIO = 2002

    // Backup detection while the app is in the foreground, in case the
    // manifest-registered ZapReceiver is delayed by the OS.
    private val powerStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                Intent.ACTION_POWER_CONNECTED -> methodChannel?.invokeMethod("onChargerConnected", null)
                Intent.ACTION_POWER_DISCONNECTED -> methodChannel?.invokeMethod("onChargerDisconnected", null)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ZapForegroundService.start(this)
        maybeRunFirstLaunchSetup()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestBatteryOptimizationExemption" -> {
                    requestBatteryOptimizationExemption()
                    result.success(null)
                }
                "isIgnoringBatteryOptimizations" -> {
                    val pm = getSystemService(POWER_SERVICE) as PowerManager
                    result.success(pm.isIgnoringBatteryOptimizations(packageName))
                }
                "hasOverlayPermission" -> result.success(Settings.canDrawOverlays(this))
                "requestOverlayPermission" -> {
                    startActivity(
                        Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
                            data = Uri.parse("package:$packageName")
                        },
                    )
                    result.success(null)
                }
                "showChargingAnimation" -> {
                    ChargeAnimActivity.start(this)
                    result.success(null)
                }
                "getBatteryStatus" -> {
                    // ACTION_BATTERY_CHANGED is sticky; passing a null receiver
                    // just reads the last broadcast without registering.
                    val batt = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
                    val level  = batt?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
                    val scale  = batt?.getIntExtra(BatteryManager.EXTRA_SCALE, 100) ?: 100
                    val status = batt?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
                    val plug   = batt?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0
                    val temp   = batt?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, -1) ?: -1
                    result.success(mapOf(
                        "level" to if (scale > 0 && level >= 0) level * 100 / scale else -1,
                        "isCharging" to (status == BatteryManager.BATTERY_STATUS_CHARGING ||
                            status == BatteryManager.BATTERY_STATUS_FULL),
                        "plugType" to when (plug) {
                            BatteryManager.BATTERY_PLUGGED_AC -> "AC"
                            BatteryManager.BATTERY_PLUGGED_USB -> "USB"
                            BatteryManager.BATTERY_PLUGGED_WIRELESS -> "Wireless"
                            else -> ""
                        },
                        "temperature" to if (temp >= 0) temp / 10.0 else -1.0,
                    ))
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        isForeground = true
        // If the anti-theft siren is sounding, the PIN screen is the only
        // thing the user should see.
        if (ZapAlarm.isActive) {
            startActivity(Intent(this, AlarmActivity::class.java))
        }
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_POWER_CONNECTED)
            addAction(Intent.ACTION_POWER_DISCONNECTED)
        }
        registerReceiver(powerStateReceiver, filter)
    }

    override fun onPause() {
        super.onPause()
        isForeground = false
        unregisterReceiver(powerStateReceiver)
    }

    // Runs the permission/dialog sequence (notifications -> battery -> mic)
    // exactly once, on the very first launch.
    private fun maybeRunFirstLaunchSetup() {
        val prefs = getSharedPreferences("zapsound_native", Context.MODE_PRIVATE)
        if (prefs.getBoolean("permission_setup_done", false)) return

        // Mark before showing so a crash/force-close doesn't re-trigger the sequence
        prefs.edit().putBoolean("permission_setup_done", true).apply()

        requestNotificationPermission()
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                REQUEST_POST_NOTIFICATIONS,
            )
        } else {
            showBatteryDialog()
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_POST_NOTIFICATIONS) {
            showBatteryDialog()
        }
        // REQUEST_RECORD_AUDIO is the last step in the sequence; nothing to chain.
    }

    private fun showBatteryDialog() {
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        if (pm.isIgnoringBatteryOptimizations(packageName)) {
            requestRecordAudioPermission()
            return
        }

        AlertDialog.Builder(this)
            .setTitle("Keep ZapSound alive ⚡")
            .setMessage(
                "ZapSound needs to run in the background to play sounds when your " +
                "phone is locked or the screen is off.\n\n" +
                "Tap OK to disable battery optimization for ZapSound."
            )
            .setPositiveButton("OK") { _, _ ->
                requestBatteryOptimizationExemption()
                requestRecordAudioPermission()
            }
            .setNegativeButton("Not now") { _, _ -> requestRecordAudioPermission() }
            .setCancelable(false)
            .show()
    }

    private fun requestBatteryOptimizationExemption() {
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        if (pm.isIgnoringBatteryOptimizations(packageName)) return
        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
            data = Uri.parse("package:$packageName")
        }
        startActivity(intent)
    }

    private fun requestRecordAudioPermission() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.RECORD_AUDIO),
                REQUEST_RECORD_AUDIO,
            )
        }
    }
}
