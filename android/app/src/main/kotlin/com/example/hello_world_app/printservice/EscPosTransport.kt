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

    fun sendBluetooth(mac: String, data: ByteArray) {
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
            socket.connect()
            val out = socket.outputStream
            out.write(data)
            out.flush()
            Thread.sleep(80)
        } finally {
            try {
                socket?.close()
            } catch (_: Exception) {
            }
        }
        Log.i(TAG, "Sent ${data.size} bytes (single write)")
    }

    fun sendNetwork(host: String, port: Int, data: ByteArray) {
        Socket().use { socket ->
            socket.connect(InetSocketAddress(host.trim(), port), 8_000)
            socket.soTimeout = 30_000
            val out = socket.getOutputStream()
            out.write(data)
            out.flush()
            Thread.sleep(50)
        }
        Log.i(TAG, "Sent ${data.size} bytes TCP")
    }
}
