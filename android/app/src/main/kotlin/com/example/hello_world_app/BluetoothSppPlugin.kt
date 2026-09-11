package com.example.hello_world_app

import android.os.Handler
import android.os.Looper
import com.example.hello_world_app.printservice.EscPosTransport
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * RFCOMM propio: el ticket se vuelca de corrido. El plugin de Flutter
 * hace flush cada 16 KB y la 803B imprime a trompicones.
 */
class BluetoothSppPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private var channel: MethodChannel? = null
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        io.execute { EscPosTransport.closeHeld() }
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "connect" -> {
                val mac = call.argument<String>("address")?.trim().orEmpty()
                if (mac.isEmpty()) {
                    result.error("bad_addr", "MAC vacia", null)
                    return
                }
                runIo(result) { EscPosTransport.openHeld(mac); null }
            }
            "write" -> {
                val raw = readBytes(call)
                if (raw == null) {
                    result.error("no_bytes", "Sin datos", null)
                    return
                }
                runIo(result) { EscPosTransport.writeHeld(raw); null }
            }
            "close" -> runIo(result) { EscPosTransport.closeHeld(); null }
            else -> result.notImplemented()
        }
    }

    private fun runIo(result: MethodChannel.Result, block: () -> Any?) {
        io.execute {
            try {
                val value = block()
                main.post { result.success(value) }
            } catch (e: Exception) {
                main.post { result.error("bt", e.message, null) }
            }
        }
    }

    private fun readBytes(call: MethodCall): ByteArray? {
        val raw = call.argument<ByteArray>("bytes")
        if (raw != null) return raw
        val list = call.argument<List<Int>>("bytes") ?: return null
        val out = ByteArray(list.size)
        for (i in list.indices) out[i] = (list[i] and 0xff).toByte()
        return out
    }

    companion object {
        const val CHANNEL = "boleta_print/bt_spp"
    }
}
