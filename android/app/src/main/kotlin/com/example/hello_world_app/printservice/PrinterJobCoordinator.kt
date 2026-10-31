package com.example.hello_world_app.printservice

import java.util.UUID
import java.util.concurrent.Semaphore

/** Whole jobs share the existing singleton transports, across Flutter engines
 * and PrintService. A fair lease covers connect, all bytes, drawer and close.
 * Global serialization is intentional until transports have per-device handles.
 */
object PrinterJobCoordinator {
    private val semaphore = Semaphore(1, true)
    private val monitor = Any()
    private var owner: String? = null

    fun acquire(): String {
        semaphore.acquire()
        return synchronized(monitor) {
            UUID.randomUUID().toString().also { owner = it }
        }
    }

    fun release(token: String) {
        synchronized(monitor) {
            if (owner != token) return
            owner = null
            semaphore.release()
        }
    }

    fun currentLease(): String? = synchronized(monitor) { owner }

    fun ifOwner(token: String?, block: () -> Unit) {
        synchronized(monitor) { if (token != null && owner == token) block() }
    }

    fun abandon(token: String) {
        synchronized(monitor) {
            if (owner != token) return
            try {
                EscPosTransport.closeHeld()
                UsbEscPos.closeHeld()
                EscPosTransport.closeHeldNet()
            } finally {
                owner = null
                semaphore.release()
            }
        }
    }

    fun <T> runJob(block: () -> T): T {
        val token = acquire()
        try { return block() } finally { release(token) }
    }
}
