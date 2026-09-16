package com.example.hello_world_app

import android.os.Handler
import android.os.Looper
import com.example.hello_world_app.printservice.EscPosTransport
import com.example.hello_world_app.printservice.NativePdfEscPos
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * Un solo TCP :9100 nativo, compartido con PrintService/Chrome.
 * La 803L solo admite un cliente; el socket se suelta a los 3 s de inactividad.
 */
class NetworkLanPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private var channel: MethodChannel? = null
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "connect" -> {
                val host = call.argument<String>("host")?.trim().orEmpty()
                val port = call.argument<Int>("port") ?: 9100
                if (host.isEmpty()) {
                    result.error("bad_host", "IP vacia", null)
                    return
                }
                runIo(result) { EscPosTransport.openHeldNet(host, port); null }
            }
            "write" -> {
                val raw = readBytes(call)
                if (raw == null) {
                    result.error("no_bytes", "Sin datos", null)
                    return
                }
                runIo(result) { EscPosTransport.writeHeldNet(raw); null }
            }
            "rasterizePdf" -> {
                val path = call.argument<String>("path")?.trim().orEmpty()
                if (path.isEmpty()) {
                    result.error("no_pdf", "Sin PDF", null)
                    return
                }
                val paper = call.argument<String>("paper") ?: "mm58"
                val bottomMm = (call.argument<Number>("bottomMm") ?: 15).toDouble()
                val cut = call.argument<String>("cut") ?: "fullGsV0"
                val dpi = call.argument<Int>("dpi") ?: 203
                val scale = call.argument<Int>("rasterScale") ?: 1
                runIo(result) {
                    NativePdfEscPos.build(
                        File(path),
                        null,
                        null,
                        paper,
                        bottomMm,
                        cut,
                        dpi,
                        scale,
                        "network",
                    )
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun runIo(result: MethodChannel.Result, block: () -> Any?) {
        io.execute {
            try {
                val value = block()
                main.post { result.success(value) }
            } catch (e: Exception) {
                main.post { result.error("lan", e.message, null) }
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
        const val CHANNEL = "boleta_print/lan_tcp"
    }
}
