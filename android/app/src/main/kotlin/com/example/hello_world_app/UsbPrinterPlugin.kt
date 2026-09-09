package com.example.hello_world_app

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbManager
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import com.example.hello_world_app.printservice.IminCashBox
import com.example.hello_world_app.printservice.UsbEscPos
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class UsbPrinterPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {

    private var channel: MethodChannel? = null
    private var appContext: Context? = null
    private var activity: Activity? = null
    private var pendingPermission: MethodChannel.Result? = null
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    private val usbReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != UsbEscPos.ACTION_USB_PERMISSION) return
            val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
            val result = pendingPermission
            pendingPermission = null
            result?.success(granted)
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
        ContextCompat.registerReceiver(
            binding.applicationContext,
            usbReceiver,
            IntentFilter(UsbEscPos.ACTION_USB_PERMISSION),
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        try {
            binding.applicationContext.unregisterReceiver(usbReceiver)
        } catch (_: Exception) {
        }
        io.execute { UsbEscPos.closeHeld() }
        channel?.setMethodCallHandler(null)
        channel = null
        appContext = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val ctx = appContext
        if (ctx == null) {
            result.error("no_ctx", "Sin contexto", null)
            return
        }
        when (call.method) {
            "listDevices" -> result.success(UsbEscPos.listDevices(ctx))
            "requestPermission" -> requestPermission(ctx, call, result)
            "open" -> {
                val address = call.argument<String>("address") ?: ""
                runIo(result) { UsbEscPos.openHeld(ctx, address); null }
            }
            "write" -> {
                val raw = readBytes(call)
                if (raw == null) {
                    result.error("no_bytes", "Sin datos", null)
                    return
                }
                runIo(result) { UsbEscPos.writeHeld(raw); null }
            }
            "close" -> runIo(result) { UsbEscPos.closeHeld(); null }
            "openCashBox" -> runIo(result) { IminCashBox.open() }
            else -> result.notImplemented()
        }
    }

    private fun requestPermission(
        ctx: Context,
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val address = call.argument<String>("address") ?: ""
        val mgr = ctx.getSystemService(Context.USB_SERVICE) as UsbManager
        val device = try {
            UsbEscPos.findDevice(mgr, address)
        } catch (e: Exception) {
            result.error("bad_addr", e.message, null)
            return
        }
        if (device == null) {
            result.error("missing", "USB no encontrado", null)
            return
        }
        if (mgr.hasPermission(device)) {
            result.success(true)
            return
        }
        pendingPermission?.success(false)
        pendingPermission = result
        mgr.requestPermission(device, UsbEscPos.permissionIntent(ctx))
    }

    private fun runIo(result: MethodChannel.Result, block: () -> Any?) {
        io.execute {
            try {
                val value = block()
                main.post { result.success(value) }
            } catch (e: Exception) {
                main.post { result.error("usb", e.message, null) }
            }
        }
    }

    private fun readBytes(call: MethodCall): ByteArray? {
        val raw = call.argument<ByteArray>("bytes")
        if (raw != null) return raw
        val list = call.argument<List<Int>>("bytes") ?: return null
        return list.toByteArray()
    }

    companion object {
        const val CHANNEL = "boleta_print/usb"
    }
}

private fun List<Int>.toByteArray(): ByteArray {
    val out = ByteArray(size)
    for (i in indices) out[i] = (this[i] and 0xff).toByte()
    return out
}
