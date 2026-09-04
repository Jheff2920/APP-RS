package com.example.hello_world_app.printservice

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.printservice.PrintJob
import android.printservice.PrintService
import android.printservice.PrinterDiscoverySession
import android.util.Log
import android.widget.Toast
import androidx.core.app.NotificationCompat
import com.example.hello_world_app.MainActivity
import com.example.hello_world_app.PrintEngineBridge
import com.example.hello_world_app.PrintersNativePrefsPlugin
import org.json.JSONArray
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors

/**
 * PrintService: imprime sin traer Boleta Print al frente.
 * Muestra un recuadro flotante sobre la app actual (overlay).
 */
class BoletaPrintService : PrintService() {

    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()

    override fun onCreatePrinterDiscoverySession(): PrinterDiscoverySession {
        return BoletaPrinterDiscoverySession(this)
    }

    override fun onRequestCancelPrintJob(job: PrintJob) {
        if (job.isQueued || job.isStarted) {
            job.cancel()
        }
    }

    override fun onPrintJobQueued(job: PrintJob) {
        mainHandler.post {
            try {
                if (job.isQueued) job.start()
            } catch (e: Exception) {
                Log.e(TAG, "job.start failed", e)
                return@post
            }

            val overlay = SystemPrintOverlay(this)
            if (!overlay.canShow) {
                fallbackOpenApp(job)
                return@post
            }

            executor.execute {
                runInlinePrint(job, overlay)
            }
        }
    }

    private fun runInlinePrint(job: PrintJob, overlay: SystemPrintOverlay) {
        try {
            val printerLocalId = mainHandler.runSync {
                job.info.printerId?.localId
            } ?: throw IllegalStateException("Sin impresora")

            if (printerLocalId == "no_printers") {
                failJob(job, "Vincula una impresora en Boleta Print")
                return
            }

            val row = loadPrinter(printerLocalId)
                ?: throw IllegalStateException("Impresora no encontrada")

            mainHandler.post { overlay.show(row.name) }
            mainHandler.post { overlay.setStatus("Preparando ticket...") }

            val pdfFile = copyPdf(job)
            val binPath = PrintEngineBridge.rasterize(
                applicationContext,
                pdfFile.absolutePath,
                printerLocalId,
            )
            val data = File(binPath).readBytes()
            if (data.isEmpty()) {
                throw IllegalStateException("Ticket vacio")
            }

            mainHandler.post { overlay.setStatus("Enviando a ${row.name}...") }

            when (row.type) {
                "bluetooth" -> EscPosTransport.sendBluetooth(row.address, data)
                else -> EscPosTransport.sendNetwork(row.address, row.port, data)
            }

            mainHandler.post {
                overlay.setStatus("Listo", spinning = false)
                if (job.isStarted) job.complete()
                overlay.dismiss(900)
            }
            Log.i(TAG, "Inline print OK")
        } catch (e: Exception) {
            Log.e(TAG, "Inline print failed", e)
            mainHandler.post {
                overlay.setStatus(e.message ?: "Error", spinning = false)
                if (job.isStarted || job.isQueued) {
                    job.fail(e.message ?: "Error al imprimir")
                }
                overlay.dismiss(1800)
            }
        }
    }

    private fun copyPdf(job: PrintJob): File {
        val doc = mainHandler.runSync { job.document }
            ?: throw IllegalStateException("Sin documento")
        val pfd: ParcelFileDescriptor = mainHandler.runSync { doc.data }
            ?: throw IllegalStateException("Sin datos del documento")

        val outFile = File(cacheDir, "system_print_${System.currentTimeMillis()}.pdf")
        ParcelFileDescriptor.AutoCloseInputStream(pfd).use { input ->
            FileOutputStream(outFile).use { output ->
                input.copyTo(output)
            }
        }
        if (outFile.length() < 20L) {
            throw IllegalStateException("Documento vacio")
        }
        return outFile
    }

    private fun fallbackOpenApp(job: PrintJob) {
        try {
            val printerLocalId = job.info.printerId?.localId ?: "unknown"
            val doc = job.document ?: throw IllegalStateException("Sin documento")
            val pfd = doc.data ?: throw IllegalStateException("Sin datos")
            val outFile = File(cacheDir, "system_print_${System.currentTimeMillis()}.pdf")
            ParcelFileDescriptor.AutoCloseInputStream(pfd).use { input ->
                FileOutputStream(outFile).use { output -> input.copyTo(output) }
            }

            val launch = Intent(this, MainActivity::class.java).apply {
                action = MainActivity.ACTION_SYSTEM_PRINT
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP,
                )
                putExtra(MainActivity.EXTRA_SYSTEM_PRINT_PATH, outFile.absolutePath)
                putExtra(MainActivity.EXTRA_SYSTEM_PRINT_PRINTER_ID, printerLocalId)
                putExtra(MainActivity.EXTRA_SYSTEM_PRINT_TOKEN, job.info.id.toString())
            }
            postPrintNotification(launch)
            Toast.makeText(
                this,
                "Activa «Mostrar sobre otras apps» en Boleta Print para imprimir sin salir",
                Toast.LENGTH_LONG,
            ).show()
            if (job.isStarted) job.complete()
        } catch (e: Exception) {
            Log.e(TAG, "fallback failed", e)
            if (job.isStarted || job.isQueued) {
                job.fail(e.message ?: "Error")
            }
        }
    }

    private fun failJob(job: PrintJob, message: String) {
        mainHandler.post {
            if (job.isStarted || job.isQueued) job.fail(message)
        }
    }

    private fun loadPrinter(id: String): PrinterRow? {
        val prefs = applicationContext.getSharedPreferences(
            PrintersNativePrefsPlugin.PREFS,
            MODE_PRIVATE,
        )
        val raw = prefs.getString(PrintersNativePrefsPlugin.KEY, null) ?: return null
        return try {
            val arr = JSONArray(raw)
            for (i in 0 until arr.length()) {
                val o = arr.getJSONObject(i)
                if (o.optString("id") != id) continue
                return PrinterRow(
                    id = id,
                    name = o.optString("name", "Impresora"),
                    type = o.optString("type", "bluetooth"),
                    address = o.optString("address", ""),
                    port = o.optInt("port", 9100),
                )
            }
            null
        } catch (_: Exception) {
            null
        }
    }

    private fun postPrintNotification(launch: Intent) {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Impresión del sistema",
                    NotificationManager.IMPORTANCE_HIGH,
                ),
            )
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0)
        val pi = PendingIntent.getActivity(this, 1001, launch, flags)
        val notif = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_share)
            .setContentTitle("Boleta Print")
            .setContentText("Toca para imprimir (falta permiso de superposición)")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pi)
            .build()
        nm.notify(NOTIF_ID, notif)
    }

    private data class PrinterRow(
        val id: String,
        val name: String,
        val type: String,
        val address: String,
        val port: Int,
    )

    companion object {
        private const val TAG = "BoletaPrintService"
        private const val CHANNEL_ID = "boleta_system_print"
        private const val NOTIF_ID = 4401
    }
}

/** Ejecuta un bloque en el hilo principal y espera el resultado. */
private fun <T> Handler.runSync(block: () -> T): T {
    if (Looper.myLooper() == looper) return block()
    val latch = java.util.concurrent.CountDownLatch(1)
    val box = arrayOfNulls<Any?>(1)
    var error: Throwable? = null
    post {
        try {
            box[0] = block()
        } catch (t: Throwable) {
            error = t
        } finally {
            latch.countDown()
        }
    }
    latch.await()
    error?.let { throw it }
    @Suppress("UNCHECKED_CAST")
    return box[0] as T
}
