package com.example.hello_world_app.printservice

import android.app.PendingIntent
import android.content.Context
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.os.Build
import android.util.Log

/**
 * ESC/POS por USB host (impresora integrada IMIN/Falcon, clase impresora o bulk OUT).
 */
object UsbEscPos {

    private const val TAG = "UsbEscPos"
    const val ACTION_USB_PERMISSION = "com.example.hello_world_app.USB_PERMISSION"

    private val lock = Any()
    private var held: Held? = null

    private class Held(
        val conn: UsbDeviceConnection,
        val iface: UsbInterface,
        val ep: UsbEndpoint,
    )

    fun listDevices(context: Context): List<Map<String, Any>> {
        val mgr = usbManager(context)
        val out = ArrayList<Map<String, Any>>()
        for (device in mgr.deviceList.values) {
            val ep = findBulkOut(device) ?: continue
            val name = device.productName?.trim().orEmpty().ifEmpty {
                device.deviceName
            }
            out.add(
                mapOf(
                    "name" to name,
                    "address" to addressOf(device),
                    "vendorId" to device.vendorId,
                    "productId" to device.productId,
                    "hasPermission" to mgr.hasPermission(device),
                    "endpoint" to ep.endpointNumber,
                ),
            )
        }
        return out
    }

    fun send(
        context: Context,
        address: String,
        data: ByteArray,
        drawer: ByteArray,
        drawerWaitMs: Long,
        jobId: String,
    ) {
        closeHeld()
        val mgr = usbManager(context)
        val device = findDevice(mgr, address)
            ?: throw IllegalStateException("USB no encontrado ($address)")
        if (!mgr.hasPermission(device)) {
            throw IllegalStateException(
                "Sin permiso USB. Abre Boleta Print y vuelve a elegir el dispositivo.",
            )
        }
        val ifaceEp = findInterfaceAndOut(device)
            ?: throw IllegalStateException("USB sin endpoint de salida")
        val conn = mgr.openDevice(device)
            ?: throw IllegalStateException("No se pudo abrir USB")
        val writeStartedAt = PrintTiming.now()
        try {
            if (!conn.claimInterface(ifaceEp.first, true)) {
                throw IllegalStateException("No se pudo reclamar la interfaz USB")
            }
            try {
                writeBulk(conn, ifaceEp.second, data)
                PrintTiming.phase(
                    jobId,
                    "usb_write",
                    writeStartedAt,
                    mapOf("bytes" to data.size),
                )
                if (drawer.isNotEmpty()) {
                    try {
                        Thread.sleep(drawerWaitMs.coerceAtLeast(80))
                        val gpio = IminCashBox.open()
                        PrintTiming.event(
                            jobId,
                            "usb_drawer",
                            mapOf("gpio" to gpio),
                        )
                        if (!gpio) {
                            writeBulk(conn, ifaceEp.second, drawer)
                            Thread.sleep(80)
                        }
                        Log.i(TAG, "USB drawer gpio=$gpio")
                    } catch (e: Exception) {
                        Log.w(TAG, "Gaveta USB falló; el ticket ya salió", e)
                        IminCashBox.open()
                    }
                }
            } finally {
                conn.releaseInterface(ifaceEp.first)
            }
        } finally {
            conn.close()
        }
        Log.i(TAG, "Sent ${data.size} bytes USB $address")
    }

    /** Abre bulk OUT y lo deja abierto para ticket + gaveta. */
    fun openHeld(context: Context, address: String) {
        closeHeld()
        val mgr = usbManager(context)
        val device = findDevice(mgr, address)
            ?: throw IllegalStateException("USB no encontrado ($address)")
        if (!mgr.hasPermission(device)) {
            throw IllegalStateException(
                "Sin permiso USB. Abre Boleta Print y vuelve a elegir el dispositivo.",
            )
        }
        val ifaceEp = findInterfaceAndOut(device)
            ?: throw IllegalStateException("USB sin endpoint de salida")
        val conn = mgr.openDevice(device)
            ?: throw IllegalStateException("No se pudo abrir USB")
        if (!conn.claimInterface(ifaceEp.first, true)) {
            conn.close()
            throw IllegalStateException("No se pudo reclamar la interfaz USB")
        }
        synchronized(lock) {
            held = Held(conn, ifaceEp.first, ifaceEp.second)
        }
    }

    fun writeHeld(data: ByteArray) {
        val session = synchronized(lock) { held }
            ?: throw IllegalStateException("USB no esta abierto")
        writeBulk(session.conn, session.ep, data)
    }

    fun closeHeld() {
        val session = synchronized(lock) {
            val current = held
            held = null
            current
        } ?: return
        try {
            session.conn.releaseInterface(session.iface)
        } catch (_: Exception) {
        }
        try {
            session.conn.close()
        } catch (_: Exception) {
        }
    }

    fun findDevice(mgr: UsbManager, address: String): UsbDevice? {
        val (vid, pid) = parseAddress(address)
        return mgr.deviceList.values.firstOrNull {
            it.vendorId == vid && it.productId == pid
        }
    }

    fun permissionIntent(context: Context): PendingIntent {
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0
        return PendingIntent.getBroadcast(
            context,
            0,
            android.content.Intent(ACTION_USB_PERMISSION).setPackage(context.packageName),
            flags,
        )
    }

    fun addressOf(device: UsbDevice): String = "${device.vendorId}:${device.productId}"

    fun parseAddress(address: String): Pair<Int, Int> {
        val p = address.trim().split(':')
        if (p.size < 2) throw IllegalStateException("USB invalido: $address")
        val vid = p[0].toIntOrNull() ?: throw IllegalStateException("USB vid")
        val pid = p[1].toIntOrNull() ?: throw IllegalStateException("USB pid")
        return vid to pid
    }

    private fun usbManager(context: Context): UsbManager {
        return context.applicationContext.getSystemService(Context.USB_SERVICE) as UsbManager
    }

    private fun findBulkOut(device: UsbDevice): UsbEndpoint? {
        return findInterfaceAndOut(device)?.second
    }

    private fun findInterfaceAndOut(
        device: UsbDevice,
    ): Pair<UsbInterface, UsbEndpoint>? {
        var fallback: Pair<UsbInterface, UsbEndpoint>? = null
        for (i in 0 until device.interfaceCount) {
            val iface = device.getInterface(i)
            for (e in 0 until iface.endpointCount) {
                val ep = iface.getEndpoint(e)
                if (ep.direction != UsbConstants.USB_DIR_OUT) continue
                if (ep.type != UsbConstants.USB_ENDPOINT_XFER_BULK) continue
                val pair = iface to ep
                if (iface.interfaceClass == UsbConstants.USB_CLASS_PRINTER) {
                    return pair
                }
                if (fallback == null) fallback = pair
            }
        }
        return fallback
    }

    private fun writeBulk(
        conn: UsbDeviceConnection,
        ep: UsbEndpoint,
        data: ByteArray,
    ) {
        if (data.size < 256) {
            val copy = data.copyOf()
            val sent = conn.bulkTransfer(ep, copy, copy.size, 15_000)
            if (sent <= 0) {
                throw IllegalStateException("Fallo USB bulk (gaveta/corto)")
            }
            return
        }
        var offset = 0
        val chunk = 16384
        while (offset < data.size) {
            val n = minOf(chunk, data.size - offset)
            val sent = conn.bulkTransfer(ep, data, offset, n, 15_000)
            if (sent <= 0) {
                throw IllegalStateException("Fallo USB bulk (offset $offset)")
            }
            offset += sent
        }
    }
}
