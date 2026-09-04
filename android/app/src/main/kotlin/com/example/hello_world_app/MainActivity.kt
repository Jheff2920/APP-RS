package com.example.hello_world_app

import android.content.Intent
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Activity principal. También recibe trabajos del PrintService del sistema
 * (necesita Activity para Bluetooth; el motor headless no basta).
 */
class MainActivity : FlutterActivity() {

    private var systemChannel: MethodChannel? = null
    private var pendingSystemPrint: Map<String, String>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(PrintersNativePrefsPlugin())
        systemChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_SYSTEM,
        ).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "notifyPrintResult" -> {
                        val ok = call.argument<Boolean>("ok") == true
                        val token = call.argument<String>("token") ?: ""
                        val message = call.argument<String>("message")
                        sendBroadcast(
                            Intent(ACTION_PRINT_RESULT).apply {
                                setPackage(packageName)
                                putExtra(EXTRA_TOKEN, token)
                                putExtra(EXTRA_OK, ok)
                                putExtra(EXTRA_MESSAGE, message)
                            },
                        )
                        result.success(null)
                    }
                    "takePendingSystemPrint" -> {
                        val pending = pendingSystemPrint
                        pendingSystemPrint = null
                        result.success(pending)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleSystemPrintIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleSystemPrintIntent(intent)
    }

    private fun handleSystemPrintIntent(intent: Intent?) {
        if (intent == null) return
        val path = intent.getStringExtra(EXTRA_SYSTEM_PRINT_PATH) ?: return
        val printerId = intent.getStringExtra(EXTRA_SYSTEM_PRINT_PRINTER_ID) ?: ""
        val token = intent.getStringExtra(EXTRA_SYSTEM_PRINT_TOKEN) ?: ""
        // Consumir extras para no reimprimir al rotar.
        intent.removeExtra(EXTRA_SYSTEM_PRINT_PATH)
        intent.removeExtra(EXTRA_SYSTEM_PRINT_PRINTER_ID)
        intent.removeExtra(EXTRA_SYSTEM_PRINT_TOKEN)

        val payload = mapOf(
            "filePath" to path,
            "printerId" to printerId,
            "token" to token,
        )
        Log.i(TAG, "System print intent path=$path printerId=$printerId")
        // Siempre dejar pending: Dart puede aún no haber registrado el handler.
        pendingSystemPrint = payload
        systemChannel?.invokeMethod("runSystemPrint", payload)
    }

    companion object {
        private const val TAG = "BoletaMain"
        const val CHANNEL_SYSTEM = "boleta_print/system_print_ui"
        const val ACTION_SYSTEM_PRINT = "com.example.hello_world_app.ACTION_SYSTEM_PRINT"
        const val ACTION_PRINT_RESULT = "com.example.hello_world_app.PRINT_RESULT"
        const val EXTRA_OPEN_FROM_PRINT_SETTINGS = "open_from_print_settings"
        const val EXTRA_SYSTEM_PRINT_PATH = "system_print_path"
        const val EXTRA_SYSTEM_PRINT_PRINTER_ID = "system_print_printer_id"
        const val EXTRA_SYSTEM_PRINT_TOKEN = "system_print_token"
        const val EXTRA_TOKEN = "token"
        const val EXTRA_OK = "ok"
        const val EXTRA_MESSAGE = "message"
    }
}
