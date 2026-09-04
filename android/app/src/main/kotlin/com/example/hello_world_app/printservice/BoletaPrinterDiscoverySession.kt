package com.example.hello_world_app.printservice

import android.content.Context
import android.print.PrintAttributes
import android.print.PrinterCapabilitiesInfo
import android.print.PrinterId
import android.print.PrinterInfo
import android.printservice.PrintService
import android.printservice.PrinterDiscoverySession
import android.util.Log
import com.example.hello_world_app.PrintersNativePrefsPlugin
import org.json.JSONArray
import java.util.ArrayList

/**
 * Publica las impresoras vinculadas en el diálogo Imprimir del sistema.
 */
class BoletaPrinterDiscoverySession(
    private val printService: PrintService,
) : PrinterDiscoverySession() {

    override fun onStartPrinterDiscovery(priorityList: MutableList<PrinterId>) {
        publish()
    }

    override fun onStopPrinterDiscovery() {}

    override fun onValidatePrinters(printerIds: MutableList<PrinterId>) {}

    override fun onStartPrinterStateTracking(printerId: PrinterId) {}

    override fun onStopPrinterStateTracking(printerId: PrinterId) {}

    override fun onDestroy() {}

    private fun publish() {
        val printers = loadSavedPrinters(printService.applicationContext)
        Log.i(TAG, "Discovery: ${printers.size} printers")
        val infos = ArrayList<PrinterInfo>()
        val keepIds = HashSet<String>()

        for (p in printers) {
            val id = printService.generatePrinterId(p.id)
            keepIds.add(p.id)
            val status = if (p.address.isBlank()) {
                PrinterInfo.STATUS_UNAVAILABLE
            } else {
                PrinterInfo.STATUS_IDLE
            }
            val label = if (p.isDefault) "${p.name} (predeterminada)" else p.name
            val builder = PrinterInfo.Builder(id, label, status)
                .setDescription(p.description)
                .setCapabilities(capabilitiesFor(id, p.paper))
            infos.add(builder.build())
        }

        if (infos.isEmpty()) {
            val id = printService.generatePrinterId("no_printers")
            infos.add(
                PrinterInfo.Builder(id, "Boleta Print — sin impresoras", PrinterInfo.STATUS_UNAVAILABLE)
                    .setDescription("Abre Boleta Print y vincula una impresora")
                    .build(),
            )
        }

        addPrinters(infos)

        val toRemove = ArrayList<PrinterId>()
        for (tracked in trackedPrinters) {
            val local = tracked.localId
            if (local != "no_printers" && local !in keepIds && printers.isNotEmpty()) {
                toRemove.add(tracked)
            }
            if (local == "no_printers" && printers.isNotEmpty()) {
                toRemove.add(tracked)
            }
        }
        if (toRemove.isNotEmpty()) {
            removePrinters(toRemove)
        }
    }

    private fun capabilitiesFor(printerId: PrinterId, paper: String): PrinterCapabilitiesInfo {
        // Anchos en mils (1/1000 pulgada). Altura "Max" larga → la vista previa
        // escala el PDF al ancho completo (como apps tipo RawBT/Playdin).
        val roll58 = PrintAttributes.MediaSize(
            "BOLETA_ROLL_58",
            "Rollo 58 mm",
            2283,
            12000,
        )
        val roll58Max = PrintAttributes.MediaSize(
            "BOLETA_ROLL_58_MAX",
            "Rollo 58 mm Max",
            2283,
            32000,
        )
        val roll80 = PrintAttributes.MediaSize(
            "BOLETA_ROLL_80",
            "Rollo 80 mm",
            3150,
            12000,
        )
        val roll80Max = PrintAttributes.MediaSize(
            "BOLETA_ROLL_80_MAX",
            "Rollo 80 mm Max",
            3150,
            32000,
        )
        val roll110 = PrintAttributes.MediaSize(
            "BOLETA_ROLL_110",
            "Rollo 110 mm",
            4331,
            16000,
        )

        val prefer80 = paper == "mm80"
        val builder = PrinterCapabilitiesInfo.Builder(printerId)
            .addMediaSize(roll58, !prefer80)
            .addMediaSize(roll58Max, false)
            .addMediaSize(roll80, false)
            .addMediaSize(roll80Max, prefer80)
            .addMediaSize(roll110, false)
            .addResolution(
                PrintAttributes.Resolution("203dpi", "203 dpi", 203, 203),
                true,
            )
            .setMinMargins(PrintAttributes.Margins.NO_MARGINS)
            .setColorModes(
                PrintAttributes.COLOR_MODE_MONOCHROME,
                PrintAttributes.COLOR_MODE_MONOCHROME,
            )
        return builder.build()
    }

    companion object {
        private const val TAG = "BoletaDiscovery"

        data class SavedPrinterRow(
            val id: String,
            val name: String,
            val address: String,
            val paper: String,
            val isDefault: Boolean,
            val description: String,
        )

        fun loadSavedPrinters(context: Context): List<SavedPrinterRow> {
            val raw = readRawJson(context) ?: return emptyList()
            return try {
                parse(raw)
            } catch (e: Exception) {
                Log.e(TAG, "parse printers failed", e)
                emptyList()
            }
        }

        private fun readRawJson(context: Context): String? {
            // 1) Prefs nativas sincronizadas desde Flutter
            val native = context.getSharedPreferences(
                PrintersNativePrefsPlugin.PREFS,
                Context.MODE_PRIVATE,
            ).getString(PrintersNativePrefsPlugin.KEY, null)
            if (!native.isNullOrBlank()) return native

            // 2) Fallback shared_preferences clásico
            val flutterPrefs = context.getSharedPreferences(
                "FlutterSharedPreferences",
                Context.MODE_PRIVATE,
            )
            val withPrefix = flutterPrefs.getString("flutter.saved_printers_v1", null)
            if (!withPrefix.isNullOrBlank()) return withPrefix
            return flutterPrefs.getString("saved_printers_v1", null)
        }

        private fun parse(raw: String): List<SavedPrinterRow> {
            val arr = JSONArray(raw)
            val out = ArrayList<SavedPrinterRow>()
            for (i in 0 until arr.length()) {
                val o = arr.getJSONObject(i)
                val id = o.optString("id", "")
                if (id.isEmpty()) continue
                val name = o.optString("name", "Impresora")
                val type = o.optString("type", "bluetooth")
                val address = o.optString("address", "")
                val port = o.optInt("port", 9100)
                val paper = o.optString("paper", "mm58")
                val isDefault = o.optBoolean("isDefault", false)
                val desc = if (type == "bluetooth") {
                    "BT $address · $paper"
                } else {
                    "$address:$port · $paper"
                }
                out.add(
                    SavedPrinterRow(
                        id = id,
                        name = name,
                        address = address,
                        paper = paper,
                        isDefault = isDefault,
                        description = desc,
                    ),
                )
            }
            return out
        }
    }
}
