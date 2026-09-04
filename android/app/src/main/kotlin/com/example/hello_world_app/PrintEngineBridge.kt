package com.example.hello_world_app

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

/**
 * FlutterEngine headless solo para rasterizar PDF → ESC/POS (sin UI).
 */
object PrintEngineBridge {

    private const val TAG = "PrintEngineBridge"
    const val CHANNEL = "boleta_print/system_print"

    @Volatile
    private var engine: FlutterEngine? = null

    @Volatile
    private var dartReady = false

    private val main = Handler(Looper.getMainLooper())
    private val lock = Any()

    fun rasterize(
        context: Context,
        filePath: String,
        printerId: String,
    ): String {
        ensureEngine(context.applicationContext)

        val latch = CountDownLatch(1)
        val resultPath = AtomicReference<String?>(null)
        val error = AtomicReference<String?>(null)

        main.post {
            try {
                val eng = engine ?: run {
                    error.set("Engine no listo")
                    latch.countDown()
                    return@post
                }
                MethodChannel(eng.dartExecutor.binaryMessenger, CHANNEL)
                    .invokeMethod(
                        "rasterize",
                        mapOf(
                            "filePath" to filePath,
                            "printerId" to printerId,
                        ),
                        object : MethodChannel.Result {
                            override fun success(result: Any?) {
                                resultPath.set(result as? String)
                                latch.countDown()
                            }

                            override fun error(code: String, msg: String?, details: Any?) {
                                error.set(msg ?: code)
                                latch.countDown()
                            }

                            override fun notImplemented() {
                                error.set("rasterize no implementado")
                                latch.countDown()
                            }
                        },
                    )
            } catch (e: Exception) {
                Log.e(TAG, "rasterize invoke failed", e)
                error.set(e.message)
                latch.countDown()
            }
        }

        if (!latch.await(120, TimeUnit.SECONDS)) {
            throw IllegalStateException("Tiempo agotado preparando el ticket")
        }
        error.get()?.let { throw IllegalStateException(it) }
        return resultPath.get()
            ?: throw IllegalStateException("Sin archivo ESC/POS")
    }

    private fun ensureEngine(appContext: Context) {
        if (engine != null && dartReady) return
        synchronized(lock) {
            if (engine != null && dartReady) return

            val readyLatch = CountDownLatch(1)
            val initError = AtomicReference<String?>(null)

            main.post {
                try {
                    if (engine != null && dartReady) {
                        readyLatch.countDown()
                        return@post
                    }
                    val loader = FlutterInjector.instance().flutterLoader()
                    if (!loader.initialized()) {
                        loader.startInitialization(appContext)
                        loader.ensureInitializationComplete(appContext, null)
                    }
                    val eng = FlutterEngine(appContext)
                    io.flutter.plugins.GeneratedPluginRegistrant.registerWith(eng)

                    MethodChannel(eng.dartExecutor.binaryMessenger, CHANNEL)
                        .setMethodCallHandler { call, result ->
                            if (call.method == "engineReady") {
                                dartReady = true
                                readyLatch.countDown()
                                result.success(null)
                            } else {
                                result.notImplemented()
                            }
                        }

                    val entry = DartExecutor.DartEntrypoint(
                        loader.findAppBundlePath(),
                        "package:hello_world_app/system_print_main.dart",
                        "systemPrintMain",
                    )
                    eng.dartExecutor.executeDartEntrypoint(entry)
                    engine = eng
                } catch (e: Exception) {
                    Log.e(TAG, "Engine init failed", e)
                    initError.set(e.message)
                    readyLatch.countDown()
                }
            }

            if (!readyLatch.await(20, TimeUnit.SECONDS)) {
                throw IllegalStateException("Flutter headless no arranco a tiempo")
            }
            initError.get()?.let { throw IllegalStateException(it) }
            if (!dartReady) {
                throw IllegalStateException("Dart headless no señalizo listo")
            }

            // Tras engineReady, el handler nativo solo escuchaba eso.
            // Reemplazar no hace falta: rasterize usa invokeMethod, no el handler.
            // Pero hay que poner el handler Dart en system_print_main para rasterize.
        }
    }
}
