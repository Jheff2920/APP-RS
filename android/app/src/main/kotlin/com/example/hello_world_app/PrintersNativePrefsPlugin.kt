package com.example.hello_world_app

import android.content.Context
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Escribe las impresoras en SharedPreferences nativas legibles por el PrintService.
 * (shared_preferences de Flutter a veces usa DataStore / prefijos distintos).
 */
class PrintersNativePrefsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private var channel: MethodChannel? = null
    private var appContext: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        appContext = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "syncPrintersJson" -> {
                val json = call.arguments as? String ?: ""
                val ctx = appContext
                if (ctx == null) {
                    result.error("no_ctx", "Sin contexto", null)
                    return
                }
                ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    .edit()
                    .putString(KEY, json)
                    .apply()
                Log.i(TAG, "Synced printers json len=${json.length}")
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    companion object {
        private const val TAG = "PrintersNativePrefs"
        const val CHANNEL = "boleta_print/printers_prefs"
        const val PREFS = "boleta_print"
        const val KEY = "saved_printers_v1"
    }
}
