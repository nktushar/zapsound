package com.zapsound.app

import android.app.Activity
import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

// Full-screen PIN pad shown over the lock screen while the anti-theft siren
// is sounding. Back is disabled; the only way out is the correct PIN.
class AlarmActivity : Activity() {

    private val entered = StringBuilder()
    private lateinit var dots: TextView
    private lateinit var subtitle: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        actionBar?.hide()
        setContentView(buildUi())
    }

    private fun buildUi(): LinearLayout {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#050508"))
            setPadding(dp(24), dp(24), dp(24), dp(24))
        }

        root.addView(TextView(this).apply {
            text = "⚡ Charger removed!"
            textSize = 24f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
        })

        subtitle = TextView(this).apply {
            text = "Enter your PIN to stop the alarm"
            textSize = 15f
            setTextColor(Color.parseColor("#9B9AB0"))
            gravity = Gravity.CENTER
            setPadding(0, dp(8), 0, dp(24))
        }
        root.addView(subtitle)

        dots = TextView(this).apply {
            textSize = 30f
            setTextColor(Color.parseColor("#7C5CFF"))
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dp(24))
            text = "· · · ·"
        }
        root.addView(dots)

        val rows = listOf(
            listOf("1", "2", "3"),
            listOf("4", "5", "6"),
            listOf("7", "8", "9"),
            listOf("", "0", "⌫"),
        )
        for (row in rows) {
            val rowLayout = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER
            }
            for (label in row) {
                rowLayout.addView(makeKey(label))
            }
            root.addView(rowLayout)
        }
        return root
    }

    private fun makeKey(label: String): Button = Button(this).apply {
        text = label
        textSize = 22f
        setTextColor(Color.WHITE)
        background = null
        isEnabled = label.isNotEmpty()
        layoutParams = LinearLayout.LayoutParams(dp(88), dp(72))
        setOnClickListener {
            when (label) {
                "" -> {}
                "⌫" -> if (entered.isNotEmpty()) entered.deleteCharAt(entered.length - 1)
                else -> if (entered.length < 4) entered.append(label)
            }
            refreshDots()
            if (entered.length == 4) checkPin()
        }
    }

    private fun refreshDots() {
        val filled = entered.length
        dots.text = (0 until 4).joinToString(" ") { if (it < filled) "●" else "·" }
    }

    private fun checkPin() {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val pin = prefs.getString("flutter.antitheft_pin", null)
        if (pin != null && entered.toString() == pin) {
            ZapAlarm.stop(this)
            // One-shot: disarm after a triggered alarm so it doesn't fire on
            // the next routine unplug.
            prefs.edit().putBoolean("flutter.antitheft_armed", false).apply()
            (getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager).cancel(2002)
            finish()
        } else {
            entered.clear()
            refreshDots()
            subtitle.text = "Wrong PIN — try again"
            subtitle.setTextColor(Color.parseColor("#FF5252"))
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // Swallow back while the siren is active; PIN is the only way out.
        if (!ZapAlarm.isActive) {
            @Suppress("DEPRECATION")
            super.onBackPressed()
        }
    }

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()
}
