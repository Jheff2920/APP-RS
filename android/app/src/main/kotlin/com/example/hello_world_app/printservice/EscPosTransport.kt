package com.example.hello_world_app.printservice

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothSocket
import android.util.Log
import java.net.InetSocketAddress
import java.net.Socket
import java.util.UUID

/**
 * Envío ESC/POS nativo (sin Activity), para imprimir desde el PrintService.
 */
object EscPosTransport {

    private const val TAG = "EscPosTransport"
    private val SPP: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

    fun sendBluetooth(mac: String, data: ByteArray, jobId: String) {
        val adapter = BluetoothAdapter.getDefaultAdapter()
            ?: throw IllegalStateException("Bluetooth no disponible")
        if (!adapter.isEnabled) {
            throw IllegalStateException("Bluetooth apagado")
        }
        val device = adapter.getRemoteDevice(mac.trim())
        var socket: BluetoothSocket? = null
        try {
            socket = try {
                device.createRfcommSocketToServiceRecord(SPP)
            } catch (_: Exception) {
                val m = device.javaClass.getMethod(
                    "createRfcommSocket",
                    Int::class.javaPrimitiveType,
                )
                m.invoke(device, 1) as BluetoothSocket
            }
            adapter.cancelDiscovery()
            val connectStartedAt = PrintTiming.now()
            socket.connect()
            PrintTiming.phase(jobId, "bluetooth_connect", connectStartedAt)
            val out = socket.outputStream
            val ranges = EscPosChunker.ranges(data)
            val writeStartedAt = PrintTiming.now()
            for (range in ranges) {
                out.write(data, range.offset, range.length)
            }
            out.flush()
            Thread.sleep(80)
            PrintTiming.phase(
                jobId,
                "bluetooth_write",
                writeStartedAt,
                mapOf("bytes" to data.size, "chunks" to ranges.size),
            )
        } finally {
            try {
                socket?.close()
            } catch (_: Exception) {
            }
        }
        Log.i(TAG, "Sent ${data.size} bytes")
    }

    fun sendNetwork(host: String, port: Int, data: ByteArray, jobId: String) {
        Socket().use { socket ->
            val connectStartedAt = PrintTiming.now()
            socket.connect(InetSocketAddress(host.trim(), port), 8_000)
            PrintTiming.phase(jobId, "network_connect", connectStartedAt)
            socket.soTimeout = 30_000
            val out = socket.getOutputStream()
            val writeStartedAt = PrintTiming.now()
            out.write(data)
            out.flush()
            Thread.sleep(50)
            PrintTiming.phase(
                jobId,
                "network_write",
                writeStartedAt,
                mapOf("bytes" to data.size, "chunks" to 1),
            )
        }
        Log.i(TAG, "Sent ${data.size} bytes TCP")
    }
}
