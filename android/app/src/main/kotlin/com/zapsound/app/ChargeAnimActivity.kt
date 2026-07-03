package com.zapsound.app

import android.animation.ValueAnimator
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RadialGradient
import android.graphics.Shader
import android.graphics.Typeface
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.animation.LinearInterpolator
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView

// Full-screen charging animation shown over the lock screen when the charger
// is plugged in while the app is in the background. Launched by ZapReceiver;
// requires the "Display over other apps" permission (SYSTEM_ALERT_WINDOW),
// which also exempts the background activity start. Tap anywhere or wait
// ~5 s to dismiss.
class ChargeAnimActivity : Activity() {

    companion object {
        private const val AUTO_DISMISS_MS = 5200L

        fun start(context: Context) {
            context.startActivity(
                Intent(context, ChargeAnimActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            )
        }
    }

    private val dismissHandler = Handler(Looper.getMainLooper())
    private var animView: ChargeAnimView? = null

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
        dismissHandler.postDelayed({ finish() }, AUTO_DISMISS_MS)
    }

    override fun onDestroy() {
        dismissHandler.removeCallbacksAndMessages(null)
        animView?.stop()
        super.onDestroy()
    }

    private fun batteryLevel(): Int {
        val batt = registerReceiver(null, android.content.IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val level = batt?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = batt?.getIntExtra(BatteryManager.EXTRA_SCALE, 100) ?: 100
        return if (scale > 0 && level >= 0) level * 100 / scale else -1
    }

    private fun buildUi(): FrameLayout {
        val level = batteryLevel()
        val root = FrameLayout(this).apply {
            setBackgroundColor(Color.parseColor("#050508"))
            setOnClickListener { finish() }
        }

        animView = ChargeAnimView(this, level).also {
            root.addView(it, FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT)
        }

        val texts = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
        }
        texts.addView(TextView(this).apply {
            text = if (level >= 0) "$level%" else "⚡"
            textSize = 44f
            setTextColor(Color.WHITE)
            typeface = Typeface.create("sans-serif", Typeface.BOLD)
            gravity = Gravity.CENTER
        })
        texts.addView(TextView(this).apply {
            text = if (level >= 100) "Fully charged" else "Charging"
            textSize = 16f
            setTextColor(Color.parseColor("#9B9AB0"))
            gravity = Gravity.CENTER
            setPadding(0, dp(4), 0, 0)
        })
        root.addView(texts, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
            Gravity.CENTER_HORIZONTAL or Gravity.BOTTOM,
        ).apply { bottomMargin = dp(120) })

        return root
    }

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()
}

// Ripple rings expanding from a glowing gradient bolt, drawn in the brand
// palette (violet #7C5CFF → cyan #4CC9FF). One ValueAnimator drives all
// phases; rings are staggered by phase offset.
private class ChargeAnimView(context: Context, private val level: Int) : View(context) {

    private val violet = Color.parseColor("#7C5CFF")
    private val cyan = Color.parseColor("#4CC9FF")

    private val ringPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
    }
    private val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val corePaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val boltPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE }
    private val arcPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
    }
    private val trackPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        color = Color.parseColor("#26FFFFFF")
    }

    // Same bolt polygon as the launcher icon, in unit space.
    private val boltPoints = listOf(
        0.575f to 0.08f, 0.28f to 0.55f, 0.46f to 0.55f,
        0.425f to 0.92f, 0.72f to 0.45f, 0.54f to 0.45f,
    )
    private val boltPath = Path()

    private var phase = 0f // 0..1 looping
    private var appear = 0f // 0..1 one-shot entrance
    private val animator = ValueAnimator.ofFloat(0f, 1f).apply {
        duration = 2400
        repeatCount = ValueAnimator.INFINITE
        interpolator = LinearInterpolator()
        addUpdateListener {
            phase = it.animatedValue as Float
            if (appear < 1f) appear = (appear + 0.05f).coerceAtMost(1f)
            invalidate()
        }
    }

    init { animator.start() }

    fun stop() = animator.cancel()

    override fun onDraw(canvas: Canvas) {
        val cx = width / 2f
        val cy = height / 2f - height * 0.06f
        val coreR = minOf(width, height) * 0.16f * (0.85f + 0.15f * appear)
        val maxR = minOf(width, height) * 0.46f

        // Expanding ripple rings, staggered thirds.
        for (i in 0 until 3) {
            val p = (phase + i / 3f) % 1f
            val r = coreR + (maxR - coreR) * p
            val alpha = ((1f - p) * 110).toInt()
            ringPaint.strokeWidth = 3f + 5f * (1f - p)
            ringPaint.color = Color.argb(alpha, 124 + ((76 - 124) * p).toInt(), 92 + ((201 - 92) * p).toInt(), 255)
            canvas.drawCircle(cx, cy, r, ringPaint)
        }

        // Soft glow behind the core, breathing with the phase.
        val breathe = 0.85f + 0.15f * kotlin.math.sin(phase * 2f * Math.PI.toFloat())
        glowPaint.shader = RadialGradient(
            cx, cy, coreR * 2.2f * breathe,
            Color.argb(90, 124, 92, 255), Color.TRANSPARENT, Shader.TileMode.CLAMP,
        )
        canvas.drawCircle(cx, cy, coreR * 2.2f, glowPaint)

        // Gradient core circle.
        corePaint.shader = LinearGradient(
            cx - coreR, cy - coreR, cx + coreR, cy + coreR,
            violet, cyan, Shader.TileMode.CLAMP,
        )
        canvas.drawCircle(cx, cy, coreR, corePaint)

        // Battery-level arc around the core (skipped when level unknown).
        if (level >= 0) {
            val arcR = coreR * 1.35f
            val stroke = coreR * 0.10f
            arcPaint.strokeWidth = stroke
            trackPaint.strokeWidth = stroke
            canvas.drawCircle(cx, cy, arcR, trackPaint)
            arcPaint.shader = LinearGradient(
                cx - arcR, cy, cx + arcR, cy, violet, cyan, Shader.TileMode.CLAMP,
            )
            canvas.drawArc(
                cx - arcR, cy - arcR, cx + arcR, cy + arcR,
                -90f, 360f * level / 100f, false, arcPaint,
            )
        }

        // White bolt inside the core.
        val boltSize = coreR * 1.1f
        boltPath.reset()
        boltPoints.forEachIndexed { i, (x, y) ->
            val px = cx - boltSize / 2 + x * boltSize
            val py = cy - boltSize / 2 + y * boltSize
            if (i == 0) boltPath.moveTo(px, py) else boltPath.lineTo(px, py)
        }
        boltPath.close()
        canvas.drawPath(boltPath, boltPaint)
    }

    override fun onDetachedFromWindow() {
        animator.cancel()
        super.onDetachedFromWindow()
    }
}
