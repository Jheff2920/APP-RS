package com.example.hello_world_app

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.location.LocationManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Discovery Classic + createBond. El PIN lo muestra Android; la impresión
 * sigue por RFCOMM ([print_bluetooth_thermal] / PrintService).
 */
class BluetoothBondPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private var appContext: Context? = null
    private var activity: Activity? = null
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private val main = Handler(Looper.getMainLooper())
    private val pendingEvents = ArrayDeque<Map<String, Any>>()

    private var scanning = false
    private var startScanRunnable: Runnable? = null
    private var pendingStartResult: MethodChannel.Result? = null
    private var pendingBond: MethodChannel.Result? = null
    private var pendingBondAddress: String? = null
    private var pendingBondSawBonding = false
    private var pendingBondIsRemove = false
    private var bondTimeout: Runnable? = null

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                BluetoothDevice.ACTION_FOUND -> emitFound(extraDevice(intent))
                BluetoothAdapter.ACTION_DISCOVERY_FINISHED -> {
                    scanning = false
                    emit(mapOf("type" to "scanFinished"))
                }
                BluetoothDevice.ACTION_BOND_STATE_CHANGED -> onBondChanged(intent)
            }
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
        eventChannel = EventChannel(binding.binaryMessenger, EVENTS).also {
            it.setStreamHandler(this)
        }
        val filter = IntentFilter().apply {
            addAction(BluetoothDevice.ACTION_FOUND)
            addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
            addAction(BluetoothDevice.ACTION_BOND_STATE_CHANGED)
        }
        ContextCompat.registerReceiver(
            binding.applicationContext,
            receiver,
            filter,
            ContextCompat.RECEIVER_EXPORTED,
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        startScanRunnable?.let { main.removeCallbacks(it) }
        startScanRunnable = null
        cancelPendingStart(null)
        stopScanInternal()
        clearBondWait()
        try {
            binding.applicationContext.unregisterReceiver(receiver)
        } catch (_: Exception) {
        }
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        eventChannel?.setStreamHandler(null)
        eventChannel = null
        eventSink = null
        pendingEvents.clear()
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

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        emit(mapOf("type" to "ready"))
        while (pendingEvents.isNotEmpty()) {
            val next = pendingEvents.removeFirst()
            events?.success(next)
        }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        // No detener el scan: otra pantalla puede volver a escuchar.
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startScan" -> startScan(result)
            "stopScan" -> {
                cancelPendingStart("cancelled")
                stopScanInternal()
                result.success(true)
            }
            "createBond" -> createBond(call.argument<String>("address") ?: "", result)
            "removeBond" -> removeBond(call.argument<String>("address") ?: "", result)
            "listBonded" -> listBonded(result)
            "openLocationSettings" -> {
                val ctx = activity ?: appContext
                if (ctx == null) {
                    result.error("no_activity", "No hay Activity", null)
                    return
                }
                val intent = Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
                if (activity == null) {
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                ctx.startActivity(intent)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    @SuppressLint("MissingPermission")
    private fun startScan(result: MethodChannel.Result) {
        val adapter = adapter()
        if (adapter == null) {
            result.error("no_adapter", "Bluetooth no disponible", null)
            return
        }
        if (!adapter.isEnabled) {
            result.error("off", "Bluetooth esta apagado. Activalo e intenta de nuevo.", null)
            return
        }
        if (!hasConnectPermission() || !hasScanPermission()) {
            result.error("permission", "Faltan permisos de Bluetooth", null)
            return
        }
        if (!hasLocationPermission()) {
            result.error(
                "need_location",
                "Para buscar impresoras cercanas hay que permitir ubicación (Android la usa en el Bluetooth Classic).",
                null,
            )
            return
        }
        if (!isLocationEnabled()) {
            result.error(
                "location_off",
                "Activa la ubicación del teléfono (no el GPS de mapas: el interruptor de Ubicación). Sin eso Android no lista Bluetooth cercanos.",
                null,
            )
            return
        }
        try {
            cancelPendingStart(null)
            if (adapter.isDiscovering) {
                adapter.cancelDiscovery()
            }
            pendingStartResult = result
            val run = Runnable {
                startScanRunnable = null
                val pending = pendingStartResult
                pendingStartResult = null
                if (pending == null) return@Runnable
                try {
                    scanning = adapter.startDiscovery()
                    if (!scanning) {
                        pending.error(
                            "scan_failed",
                            "No se pudo iniciar la busqueda Bluetooth",
                            null,
                        )
                    } else {
                        pending.success(true)
                    }
                } catch (e: Exception) {
                    pending.error("scan_failed", e.message, null)
                }
            }
            startScanRunnable = run
            main.postDelayed(run, 350)
        } catch (e: Exception) {
            result.error("scan_failed", e.message, null)
        }
    }

    private fun cancelPendingStart(errorCode: String?) {
        startScanRunnable?.let { main.removeCallbacks(it) }
        startScanRunnable = null
        val pending = pendingStartResult
        pendingStartResult = null
        pending?.success(false)
    }

    @SuppressLint("MissingPermission")
    private fun stopScanInternal() {
        scanning = false
        try {
            val adapter = adapter() ?: return
            if (adapter.isDiscovering) {
                adapter.cancelDiscovery()
            }
        } catch (_: Exception) {
        }
    }

    @SuppressLint("MissingPermission")
    private fun createBond(address: String, result: MethodChannel.Result) {
        val mac = address.trim()
        if (mac.isEmpty()) {
            result.error("bad_args", "MAC vacia", null)
            return
        }
        if (!hasConnectPermission()) {
            result.error("permission", "Faltan permisos de Bluetooth", null)
            return
        }
        val adapter = adapter()
        if (adapter == null || !adapter.isEnabled) {
            result.error("off", "Bluetooth esta apagado", null)
            return
        }
        val device = try {
            adapter.getRemoteDevice(mac)
        } catch (e: Exception) {
            result.error("bad_args", "MAC invalida: $mac", null)
            return
        }
        if (device.bondState == BluetoothDevice.BOND_BONDED) {
            result.success(true)
            return
        }
        if (pendingBond != null) {
            result.error("busy", "Ya hay un emparejado en curso", null)
            return
        }
        stopScanInternal()
        pendingBond = result
        pendingBondAddress = device.address
        pendingBondSawBonding = device.bondState == BluetoothDevice.BOND_BONDING
        pendingBondIsRemove = false
        val started = try {
            device.createBond()
        } catch (e: Exception) {
            clearBondWait()
            result.error("bond_failed", e.message, null)
            return
        }
        if (!started) {
            clearBondWait()
            result.error("bond_failed", "No se pudo iniciar el emparejado", null)
            return
        }
        val timeout = Runnable {
            val pending = pendingBond ?: return@Runnable
            clearBondWait()
            pending.error(
                "timeout",
                "No se completo el emparejado. Revisa el PIN (0000 o 1234) e intenta de nuevo.",
                null,
            )
        }
        bondTimeout = timeout
        main.postDelayed(timeout, BOND_TIMEOUT_MS)
    }

    @SuppressLint("MissingPermission")
    private fun removeBond(address: String, result: MethodChannel.Result) {
        val mac = address.trim()
        if (mac.isEmpty()) {
            result.error("bad_args", "MAC vacia", null)
            return
        }
        if (!hasConnectPermission()) {
            result.error("permission", "Faltan permisos de Bluetooth", null)
            return
        }
        val adapter = adapter()
        if (adapter == null || !adapter.isEnabled) {
            result.error("off", "Bluetooth esta apagado", null)
            return
        }
        val device = try {
            adapter.bondedDevices?.firstOrNull { it.address.equals(mac, ignoreCase = true) }
        } catch (e: Exception) {
            result.error("unbond_failed", e.message, null)
            return
        }
        if (device == null) {
            result.success(true)
            return
        }
        if (pendingBond != null) {
            result.error("busy", "Ya hay un emparejado en curso", null)
            return
        }
        stopScanInternal()
        pendingBond = result
        pendingBondAddress = device.address
        pendingBondSawBonding = true
        pendingBondIsRemove = true
        val started = try {
            val method = device.javaClass.getMethod("removeBond")
            (method.invoke(device) as? Boolean) == true
        } catch (e: Exception) {
            clearBondWait()
            result.error("unbond_failed", e.message, null)
            return
        }
        if (!started) {
            if (device.bondState == BluetoothDevice.BOND_NONE) {
                clearBondWait()
                result.success(true)
                return
            }
            clearBondWait()
            result.error("unbond_failed", "No se pudo desvincular del Bluetooth", null)
            return
        }
        val timeout = Runnable {
            val pending = pendingBond ?: return@Runnable
            val gone = try {
                val bonded = adapter.bondedDevices ?: emptySet()
                bonded.none { it.address.equals(mac, ignoreCase = true) }
            } catch (_: Exception) {
                device.bondState == BluetoothDevice.BOND_NONE
            }
            clearBondWait()
            if (gone) {
                pending.success(true)
            } else {
                pending.error(
                    "timeout",
                    "No se completo el desvinculado Bluetooth.",
                    null,
                )
            }
        }
        bondTimeout = timeout
        main.postDelayed(timeout, UNBOND_TIMEOUT_MS)
    }

    @SuppressLint("MissingPermission")
    private fun listBonded(result: MethodChannel.Result) {
        if (!hasConnectPermission()) {
            result.error("permission", "Faltan permisos de Bluetooth", null)
            return
        }
        val adapter = adapter()
        if (adapter == null || !adapter.isEnabled) {
            result.success(emptyList<Map<String, String>>())
            return
        }
        val devices = try {
            adapter.bondedDevices ?: emptySet()
        } catch (e: Exception) {
            result.error("list_failed", e.message, null)
            return
        }
        val list = devices.mapNotNull { device ->
            val address = device.address?.trim().orEmpty()
            if (address.isEmpty()) return@mapNotNull null
            val name = try {
                device.name?.trim().orEmpty()
            } catch (_: Exception) {
                ""
            }.ifEmpty { address }
            mapOf("name" to name, "address" to address)
        }
        result.success(list)
    }

    @SuppressLint("MissingPermission")
    private fun onBondChanged(intent: Intent) {
        val device = extraDevice(intent) ?: return
        val want = pendingBondAddress ?: return
        if (!device.address.equals(want, ignoreCase = true)) return
        val state = intent.getIntExtra(BluetoothDevice.EXTRA_BOND_STATE, BluetoothDevice.BOND_NONE)
        when (state) {
            BluetoothDevice.BOND_BONDING -> {
                pendingBondSawBonding = true
            }
            BluetoothDevice.BOND_BONDED -> {
                if (pendingBondIsRemove) return
                val pending = pendingBond
                clearBondWait()
                pending?.success(true)
            }
            BluetoothDevice.BOND_NONE -> {
                if (pendingBondIsRemove) {
                    val pending = pendingBond
                    clearBondWait()
                    main.postDelayed({ pending?.success(true) }, 200)
                    return
                }
                if (!pendingBondSawBonding) return
                val pending = pendingBond
                clearBondWait()
                pending?.error("rejected", "Emparejado cancelado o PIN incorrecto", null)
            }
        }
    }

    private fun clearBondWait() {
        bondTimeout?.let { main.removeCallbacks(it) }
        bondTimeout = null
        pendingBond = null
        pendingBondAddress = null
        pendingBondSawBonding = false
        pendingBondIsRemove = false
    }

    @SuppressLint("MissingPermission")
    private fun emitFound(device: BluetoothDevice?) {
        if (device == null) return
        val address = device.address ?: return
        val name = try {
            device.name?.trim().orEmpty()
        } catch (_: Exception) {
            ""
        }.ifEmpty { address }
        emit(
            mapOf(
                "type" to "found",
                "name" to name,
                "address" to address,
                "bonded" to (device.bondState == BluetoothDevice.BOND_BONDED),
            ),
        )
    }

    private fun emit(payload: Map<String, Any>) {
        main.post {
            val sink = eventSink
            if (sink == null) {
                pendingEvents.addLast(payload)
                while (pendingEvents.size > 64) {
                    pendingEvents.removeFirst()
                }
            } else {
                sink.success(payload)
            }
        }
    }

    private fun extraDevice(intent: Intent): BluetoothDevice? {
        return if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
        }
    }

    private fun adapter(): BluetoothAdapter? {
        val ctx = appContext ?: return null
        val manager = ctx.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        return manager?.adapter ?: BluetoothAdapter.getDefaultAdapter()
    }

    private fun hasConnectPermission(): Boolean {
        val ctx = appContext ?: return false
        if (Build.VERSION.SDK_INT < 31) return true
        return ContextCompat.checkSelfPermission(ctx, Manifest.permission.BLUETOOTH_CONNECT) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun hasScanPermission(): Boolean {
        val ctx = appContext ?: return false
        if (Build.VERSION.SDK_INT < 31) return true
        return ContextCompat.checkSelfPermission(ctx, Manifest.permission.BLUETOOTH_SCAN) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun hasLocationPermission(): Boolean {
        val ctx = appContext ?: return false
        val fine = ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
        val coarse = ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_COARSE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
        return fine || coarse
    }

    private fun isLocationEnabled(): Boolean {
        val ctx = appContext ?: return false
        val lm = ctx.getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return false
        return if (Build.VERSION.SDK_INT >= 28) {
            lm.isLocationEnabled
        } else {
            @Suppress("DEPRECATION")
            lm.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
                lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
        }
    }

    companion object {
        const val CHANNEL = "boleta_print/bt_bond"
        const val EVENTS = "boleta_print/bt_bond_events"
        private const val BOND_TIMEOUT_MS = 45_000L
        private const val UNBOND_TIMEOUT_MS = 12_000L
    }
}
