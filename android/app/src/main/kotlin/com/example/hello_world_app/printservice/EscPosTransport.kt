package com.example.hello_world_app.printservice

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothSocket
import android.content.Context
import android.util.Log
import java.io.OutputStream
import java.net.InetSocketAddress
import java.net.Socket
import java.util.UUID

/**
 * Envío ESC/POS nativo (sin Activity), para imprimir desde el PrintService.
 */
object EscPosTransport {

    private const val TAG = "EscPosTransport"
    private val SPP: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    /** La 803B tira los primeros bytes; los ceros no marcan el papel. */
    private const val BT_LEAD_IN = 128
    private val heldLock = Any()
    private var heldSocket: BluetoothSocket? = null
    private var heldNeedsLeadIn = false

    fun drawerBytes(cashDrawer: String, linkType: String = ""): ByteArray {
        val escP = when (cashDrawer) {
            "pin2" -> byteArrayOf(0x1b, 0x70, 0x00, 0x19, 0x78)
            "pin5" -> byteArrayOf(0x1b, 0x70, 0x01, 0x19, 0x78)
            else -> byteArrayOf()
        }
        if (escP.isEmpty()) return escP
        // ESC @ despierta el parser si el corte ya dejó la impresora en reposo
        // (tickets cortos: Normal/Google). En Falcon USB también DLE DC4.
        val wake = byteArrayOf(0x1b, 0x40) + escP
        if (linkType == "usb") {
            return wake + byteArrayOf(0x10, 0x14, 0x00, 0x00, 0x00)
        }
        return wake
    }

    /** Espera a que salga el papel antes de pulsar la gaveta. */
    fun drawerWaitMs(linkType: String, ticketBytes: Int): Long {
        if (linkType == "network") return 300L
        if (linkType == "usb") return 800L
        return (ticketBytes / 3L).coerceIn(2500L, 8000L)
    }

    fun openBluetooth(mac: String): BluetoothSocket {
        val adapter = BluetoothAdapter.getDefaultAdapter()
            ?: throw IllegalStateException("Bluetooth no disponible")
        if (!adapter.isEnabled) {
            throw IllegalStateException("Bluetooth apagado")
        }
        val device = adapter.getRemoteDevice(mac.trim())
        val socket = try {
            device.createRfcommSocketToServiceRecord(SPP)
        } catch (_: Exception) {
            val m = device.javaClass.getMethod(
                "createRfcommSocket",
                Int::class.javaPrimitiveType,
            )
            m.invoke(device, 1) as BluetoothSocket
        }
        adapter.cancelDiscovery()
        socket.connect()
        return socket
    }

    fun openHeld(mac: String) {
        synchronized(heldLock) {
            closeHeldLocked()
            heldSocket = openBluetooth(mac)
            heldNeedsLeadIn = true
        }
        Thread.sleep(280)
    }

    fun writeHeld(data: ByteArray) {
        synchronized(heldLock) {
            val socket = heldSocket
                ?: throw IllegalStateException("No hay conexion Bluetooth activa.")
            val leadIn = heldNeedsLeadIn
            heldNeedsLeadIn = false
            writeBluetoothBytes(socket.outputStream, data, leadIn)
            socket.outputStream.flush()
        }
    }

    fun closeHeld() {
        synchronized(heldLock) {
            if (heldSocket == null) return
            try {
                Thread.sleep(220)
            } catch (_: InterruptedException) {
            }
            closeHeldLocked()
        }
    }

    private fun closeHeldLocked() {
        try {
            heldSocket?.close()
        } catch (_: Exception) {
        }
        heldSocket = null
        heldNeedsLeadIn = false
    }

    fun writeBluetooth(
        socket: BluetoothSocket,
        data: ByteArray,
        jobId: String,
        drawer: ByteArray = byteArrayOf(),
        drawerWaitMs: Long = 0,
    ) {
        try {
            val out = socket.outputStream
            writeTicketThenDrawer(out, data, drawer, drawerWaitMs, jobId, "bluetooth")
        } finally {
            try {
                socket.close()
            } catch (_: Exception) {
            }
        }
        Log.i(TAG, "Sent ${data.size} bytes BT")
    }

    fun sendBluetooth(
        mac: String,
        data: ByteArray,
        jobId: String,
        drawer: ByteArray = byteArrayOf(),
        drawerWaitMs: Long = 0,
    ) {
        val connectStartedAt = PrintTiming.now()
        val socket = openBluetooth(mac)
        PrintTiming.phase(jobId, "bluetooth_connect", connectStartedAt)
        writeBluetooth(socket, data, jobId, drawer, drawerWaitMs)
    }

    fun sendNetwork(
        host: String,
        port: Int,
        data: ByteArray,
        jobId: String,
        drawer: ByteArray = byteArrayOf(),
        drawerWaitMs: Long = 0,
    ) {
        Socket().use { socket ->
            val connectStartedAt = PrintTiming.now()
            socket.connect(InetSocketAddress(host.trim(), port), 8_000)
            PrintTiming.phase(jobId, "network_connect", connectStartedAt)
            socket.soTimeout = 30_000
            writeTicketThenDrawer(
                socket.getOutputStream(),
                data,
                drawer,
                drawerWaitMs,
                jobId,
                "network",
            )
        }
        Log.i(TAG, "Sent ${data.size} bytes TCP")
    }

    fun sendUsb(
        context: Context,
        address: String,
        data: ByteArray,
        jobId: String,
        drawer: ByteArray = byteArrayOf(),
        drawerWaitMs: Long = 0,
    ) {
        UsbEscPos.send(context, address, data, drawer, drawerWaitMs, jobId)
    }

    private fun writeTicketThenDrawer(
        out: OutputStream,
        data: ByteArray,
        drawer: ByteArray,
        drawerWaitMs: Long,
        jobId: String,
        phase: String,
    ) {
        val writeStartedAt = PrintTiming.now()
        if (phase == "bluetooth") {
            Thread.sleep(200)
            // Un solo stream: si se hace flush/trocea, la 803B imprime a tirones.
            writeBluetoothBytes(out, data, leadIn = true)
            PrintTiming.phase(
                jobId,
                "bluetooth_write",
                writeStartedAt,
                mapOf("bytes" to data.size, "chunks" to 1),
            )
        } else {
            out.write(data)
            PrintTiming.phase(
                jobId,
                "${phase}_write",
                writeStartedAt,
                mapOf("bytes" to data.size, "chunks" to 1),
            )
        }
        out.flush()
        if (drawer.isNotEmpty()) {
            try {
                Thread.sleep(drawerWaitMs.coerceAtLeast(80))
                out.write(drawer)
                out.flush()
                Thread.sleep(80)
            } catch (e: Exception) {
                Log.w(TAG, "Gaveta ESC/POS falló; el ticket ya salió", e)
            }
        } else {
            Thread.sleep(220)
        }
    }

    private fun writeBluetoothBytes(
        out: OutputStream,
        data: ByteArray,
        leadIn: Boolean,
    ) {
        if (leadIn) {
            val payload = ByteArray(BT_LEAD_IN + data.size)
            System.arraycopy(data, 0, payload, BT_LEAD_IN, data.size)
            writeFully(out, payload)
        } else {
            writeFully(out, data)
        }
    }

    private fun writeFully(out: OutputStream, data: ByteArray) {
        var offset = 0
        while (offset < data.size) {
            val n = minOf(data.size - offset, 262_144)
            out.write(data, offset, n)
            offset += n
        }
    }
}
