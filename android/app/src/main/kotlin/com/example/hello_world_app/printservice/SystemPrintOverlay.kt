package com.example.hello_world_app.printservice

import android.content.Context
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.ProgressBar
import android.widget.TextView
import com.example.hello_world_app.R

/**
 * Recuadro flotante sobre la app actual (SYSTEM_ALERT_WINDOW),
 * para no saltar a Boleta Print al imprimir desde el sistema.
 */
class SystemPrintOverlay(private val context: Context) {

    private val main = Handler(Looper.getMainLooper())
    private val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private var root: View? = null
    private var title: TextView? = null
    private var message: TextView? = null
    private var printer: TextView? = null
    private var progress: ProgressBar? = null

    val canShow: Boolean
        get() = Build.VERSION.SDK_INT < 23 || Settings.canDrawOverlays(context)

    fun show(printerName: String) {
        main.post {
            if (root != null) return@post
            if (!canShow) return@post
            val view = LayoutInflater.from(context).inflate(R.layout.print_overlay, null)
            title = view.findViewById(R.id.overlay_title)
            message = view.findViewById(R.id.overlay_message)
            printer = view.findViewById(R.id.overlay_printer)
            progress = view.findViewById(R.id.overlay_progress)
            printer?.text = printerName
            message?.text = "Preparando..."
            progress?.visibility = View.VISIBLE

            val type = if (Build.VERSION.SDK_INT >= 26) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }
            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                type,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT,
            ).apply {
                gravity = Gravity.CENTER
            }
            try {
                wm.addView(view, params)
                root = view
            } catch (e: Exception) {
                root = null
            }
        }
    }

    fun setStatus(text: String, spinning: Boolean = true) {
        main.post {
            message?.text = text
            progress?.visibility = if (spinning) View.VISIBLE else View.GONE
        }
    }

    fun dismiss(afterMs: Long = 0) {
        main.postDelayed({
            val view = root ?: return@postDelayed
            try {
                wm.removeView(view)
            } catch (_: Exception) {
            }
            root = null
        }, afterMs)
    }
}
