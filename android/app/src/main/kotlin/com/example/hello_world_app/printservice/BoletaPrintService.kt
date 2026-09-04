package com.example.hello_world_app.printservice

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
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
import androidx.core.content.ContextCompat
import com.example.hello_world_app.MainActivity
import com.example.hello_world_app.PrintEngineBridge
import com.example.hello_world_app.PrintersNativePrefsPlugin
import org.json.JSONArray
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.ConcurrentHashMap

/**
 * PrintService: imprime sin traer Boleta Print al frente.
 * Muestra un recuadro flotante sobre la app actual (overlay).
 */
class BoletaPrintService : PrintService() {

    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    private val pendingFallbacks = ConcurrentHashMap<String, PendingFallback>()
    private val printResultReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != MainActivity.ACTION_PRINT_RESULT) return
            val token = intent.getStringExtra(MainActivity.EXTRA_TOKEN) ?: return
            val ok = intent.getBooleanExtra(MainActivity.EXTRA_OK, false)
            val message = intent.getStringExtra(MainActivity.EXTRA_MESSAGE)
            finishFallback(token, ok, message)
        }
    }

    override fun onCreate() {
        super.onCreate()
        ContextCompat.registerReceiver(
            this,
            printResultReceiver,
            IntentFilter(MainActivity.ACTION_PRINT_RESULT),
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
        PrintEngineBridge.prewarm(applicationContext)
    }

    override fun onDestroy() {
        pendingFallbacks.keys.toList().forEach { token ->
            finishFallback(token, false, "Servicio de impresion detenido")
        }
        try {
            unregisterReceiver(printResultReceiver)
        } catch (_: Exception) {
        }
        executor.shutdownNow()
        super.onDestroy()
    }

    override fun onCreatePrinterDiscoverySession(): PrinterDiscoverySession {
        return BoletaPrinterDiscoverySession(this)
    }

    override fun onRequestCancelPrintJob(job: PrintJob) {
        if (job.isQueued || job.isStarted) {
            job.cancel()
        }
        pendingFallbacks.entries
            .firstOrNull { it.value.job == job }
            ?.key
            ?.let { finishFallback(it, false, "Impresion cancelada") }
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
        val totalStartedAt = PrintTiming.now()
        var jobId = "unknown"
        var pdfFile: File? = null
        var succeeded = false
        try {
            val identifiers = mainHandler.runSync {
                Pair(job.info.printerId?.localId, job.info.id.toString())
            }
            val printerLocalId = identifiers.first
                ?: throw IllegalStateException("Sin impresora")
            jobId = identifiers.second

            if (printerLocalId == "no_printers") {
                failJob(job, "Vincula una impresora en Boleta Print")
                return
            }

            val row = loadPrinter(printerLocalId)
                ?: throw IllegalStateException("Impresora no encontrada")

            mainHandler.post { overlay.show(row.name) }
            mainHandler.post { overlay.setStatus("Preparando ticket...") }

            val copyStartedAt = PrintTiming.now()
            val copiedPdf = copyPdf(job)
            pdfFile = copiedPdf
            PrintTiming.phase(
                jobId,
                "copy_pdf",
                copyStartedAt,
                mapOf("bytes" to copiedPdf.length()),
            )
            val data = PrintEngineBridge.rasterize(
                applicationContext,
                copiedPdf.absolutePath,
                printerLocalId,
                jobId,
            )
            if (data.isEmpty()) {
                throw IllegalStateException("Ticket vacio")
            }

            mainHandler.post { overlay.setStatus("Enviando a ${row.name}...") }

            when (row.type) {
                "bluetooth" -> EscPosTransport.sendBluetooth(row.address, data, jobId)
                else -> EscPosTransport.sendNetwork(row.address, row.port, data, jobId)
            }

            succeeded = true
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
        } finally {
            try {
                pdfFile?.delete()
            } catch (_: Exception) {
            }
            PrintTiming.phase(
                jobId,
                "system_total",
                totalStartedAt,
                mapOf("ok" to succeeded),
            )
        }
    }

    private fun copyPdf(job: PrintJob): File {
        val doc = mainHandler.runSync { job.document }
        val pfd: ParcelFileDescriptor = mainHandler.runSync { doc.data }
            ?: throw IllegalStateException("Sin datos del documento")

        val outFile = File(cacheDir, "system_print_${System.currentTimeMillis()}.pdf")
        try {
            ParcelFileDescriptor.AutoCloseInputStream(pfd).use { input ->
                FileOutputStream(outFile).use { output ->
                    input.copyTo(output)
                }
            }
            if (outFile.length() < 20L) {
                throw IllegalStateException("Documento vacio")
            }
            return outFile
        } catch (error: Throwable) {
            outFile.delete()
            throw error
        }
    }

    private fun fallbackOpenApp(job: PrintJob) {
        var token: String? = null
        var outFile: File? = null
        try {
            val printerLocalId = job.info.printerId?.localId ?: "unknown"
            val jobToken = job.info.id.toString()
            token = jobToken
            val doc = job.document
            val pfd = doc.data ?: throw IllegalStateException("Sin datos")
            val copiedFile = File(cacheDir, "system_print_${System.currentTimeMillis()}.pdf")
            outFile = copiedFile
            val copyStartedAt = PrintTiming.now()
            ParcelFileDescriptor.AutoCloseInputStream(pfd).use { input ->
                FileOutputStream(copiedFile).use { output -> input.copyTo(output) }
            }
            if (copiedFile.length() < 20L) {
                throw IllegalStateException("Documento vacio")
            }
            PrintTiming.phase(
                jobToken,
                "fallback_copy_pdf",
                copyStartedAt,
                mapOf("bytes" to copiedFile.length()),
            )

            val launch = Intent(this, MainActivity::class.java).apply {
                action = MainActivity.ACTION_SYSTEM_PRINT
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP,
                )
                putExtra(MainActivity.EXTRA_SYSTEM_PRINT_PATH, copiedFile.absolutePath)
                putExtra(MainActivity.EXTRA_SYSTEM_PRINT_PRINTER_ID, printerLocalId)
                putExtra(MainActivity.EXTRA_SYSTEM_PRINT_TOKEN, jobToken)
            }
            lateinit var timeout: Runnable
            timeout = Runnable {
                finishFallback(
                    jobToken,
                    false,
                    "Tiempo agotado esperando la impresion",
                )
            }
            pendingFallbacks[jobToken] = PendingFallback(
                job = job,
                file = copiedFile,
                timeout = timeout,
                startedAt = PrintTiming.now(),
            )
            mainHandler.postDelayed(timeout, FALLBACK_TIMEOUT_MS)
            postPrintNotification(launch)
            Toast.makeText(
                this,
                "Activa «Mostrar sobre otras apps» en Boleta Print para imprimir sin salir",
                Toast.LENGTH_LONG,
            ).show()
            PrintTiming.event(jobToken, "fallback_waiting_for_user")
        } catch (e: Exception) {
            Log.e(TAG, "fallback failed", e)
            val currentToken = token
            if (currentToken != null && pendingFallbacks.containsKey(currentToken)) {
                finishFallback(currentToken, false, e.message ?: "Error")
            } else {
                try {
                    outFile?.delete()
                } catch (_: Exception) {
                }
                if (job.isStarted || job.isQueued) {
                    job.fail(e.message ?: "Error")
                }
            }
        }
    }

    private fun finishFallback(token: String, ok: Boolean, message: String?) {
        val pending = pendingFallbacks.remove(token) ?: return
        mainHandler.removeCallbacks(pending.timeout)
        try {
            if (ok) {
                if (pending.job.isStarted) pending.job.complete()
            } else if (pending.job.isStarted || pending.job.isQueued) {
                pending.job.fail(message ?: "Error al imprimir")
            }
        } finally {
            try {
                pending.file.delete()
            } catch (_: Exception) {
            }
            PrintTiming.phase(
                token,
                "fallback_total",
                pending.startedAt,
                mapOf("ok" to ok),
            )
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

    private data class PendingFallback(
        val job: PrintJob,
        val file: File,
        val timeout: Runnable,
        val startedAt: Long,
    )

    companion object {
        private const val TAG = "BoletaPrintService"
        private const val CHANNEL_ID = "boleta_system_print"
        private const val NOTIF_ID = 4401
        private const val FALLBACK_TIMEOUT_MS = 5 * 60 * 1000L
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
    if (!latch.await(20, TimeUnit.SECONDS)) {
        throw IllegalStateException("Tiempo agotado esperando el hilo principal")
    }
    error?.let { throw it }
    @Suppress("UNCHECKED_CAST")
    return box[0] as T
}
