package com.example.hello_world_app.printservice

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.widget.Button
import android.widget.TextView
import com.example.hello_world_app.MainActivity
import com.example.hello_world_app.R

/**
 * Ajustes del PrintService (debe tener BIND_PRINT_SERVICE, como RawBT).
 * En Android 10+ hace falta "mostrar sobre otras apps" para abrir la UI al imprimir.
 */
class PrintSettingsActivity : Activity() {

    private lateinit var status: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.print_settings)
        status = findViewById(R.id.status_text)
        findViewById<Button>(R.id.btn_overlay).setOnClickListener {
            openOverlaySettings()
        }
        findViewById<Button>(R.id.btn_open_app).setOnClickListener {
            startActivity(
                Intent(this, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                },
            )
        }
        refresh()
    }

    override fun onResume() {
        super.onResume()
        refresh()
    }

    private fun refresh() {
        val overlayOk = Build.VERSION.SDK_INT < 29 || Settings.canDrawOverlays(this)
        status.text = if (overlayOk) {
            "Listo: al imprimir desde otra app verás un recuadro flotante " +
                "(sin saltar a Boleta Print)."
        } else {
            "Falta permiso «Mostrar sobre otras apps»: sin él no se puede mostrar " +
                "el aviso de impresión sobre la app actual."
        }
    }

    private fun openOverlaySettings() {
        try {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName"),
                ),
            )
        } catch (_: Exception) {
            startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            })
        }
    }
}
