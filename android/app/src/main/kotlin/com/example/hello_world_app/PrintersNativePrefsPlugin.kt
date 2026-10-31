package com.example.hello_world_app

import android.content.Context
import android.util.Log
import android.os.Handler
import android.os.Looper
import com.example.hello_world_app.printservice.PrinterJobCoordinator
import java.util.concurrent.Executors
import java.util.concurrent.ConcurrentHashMap
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
    private val leases = ConcurrentHashMap.newKeySet<String>()
    @Volatile private var detached = false
    private val main = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        detached = false
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        detached = true
        val abandoned = leases.toList()
        jobWaiters.execute { abandoned.forEach { PrinterJobCoordinator.abandon(it) } }
        leases.clear()
        channel?.setMethodCallHandler(null)
        channel = null
        appContext = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "acquirePrintJob" -> jobWaiters.execute {
                try {
                    val token = PrinterJobCoordinator.acquire()
                    leases.add(token)
                    main.post {
                        if (detached) {
                            leases.remove(token)
                            PrinterJobCoordinator.release(token)
                            result.error("detached", "Servicio desconectado", null)
                        } else result.success(token)
                    }
                } catch (e: InterruptedException) {
                    main.post { result.error("cancelled", "Espera cancelada", null) }
                }
            }
            "releasePrintJob" -> {
                val token = call.arguments as? String
                if (token != null && leases.remove(token)) PrinterJobCoordinator.release(token)
                result.success(null)
            }
            "syncPrintersJson" -> {
                val json = call.arguments as? String ?: ""
                val ctx = appContext
                if (ctx == null) {
                    result.error("no_ctx", "Sin contexto", null)
                    return
                }
                val saved = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    .edit()
                    .putString(KEY, json)
                    .commit()
                if (!saved) {
                    result.error("save_failed", "No se pudo actualizar el servicio de impresión", null)
                    return
                }
                Log.i(TAG, "Synced printers json len=${json.length}")
                result.success(null)
            }
            "syncAdsFree" -> {
                val adsFree = call.arguments as? Boolean ?: false
                val ctx = appContext
                if (ctx == null) {
                    result.error("no_ctx", "Sin contexto", null)
                    return
                }
                ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    .edit()
                    .putBoolean(ADS_FREE_KEY, adsFree)
                    .commit()
                Log.i(TAG, "Synced adsFree=$adsFree")
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    companion object {
        private const val TAG = "PrintersNativePrefs"
        private val jobWaiters = Executors.newCachedThreadPool()
        const val CHANNEL = "boleta_print/printers_prefs"
        const val PREFS = "boleta_print"
        const val KEY = "saved_printers_v2"
        const val ADS_FREE_KEY = "ads_free"
    }
}
