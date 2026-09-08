package com.example.hello_world_app.printservice

import android.os.Build
import android.util.Log
import java.io.File
import java.io.FileOutputStream

/**
 * En IMIN/Falcon el cajón no es ESC/POS por USB: el plugin oficial pulsa un
 * GPIO del equipo (`cashbox_en` en Falcon 1). Mismo criterio, sin su SDK.
 */
object IminCashBox {

    private const val TAG = "IminCashBox"
    private const val FALCON = "/sys/extcon-usb-gpio/cashbox_en"
    private const val GPIOCTL = "/sys/class/neostra_gpioctl/dev/gpioctl"

    fun open(): Boolean {
        val paths = preferredPaths()
        for (path in paths) {
            if (writeFile(path)) {
                Log.i(TAG, "Gaveta GPIO $path")
                return true
            }
            if (writeViaSh(path)) {
                Log.i(TAG, "Gaveta sh $path")
                return true
            }
        }
        Log.w(TAG, "Gaveta GPIO no disponible (${Build.MODEL})")
        return false
    }

    private fun preferredPaths(): List<String> {
        val model = Build.MODEL.orEmpty()
        val falconFirst = model.contains("Falcon", ignoreCase = true) ||
            model == "D1" ||
            model.contains("D1-Pro", ignoreCase = true) ||
            model.contains("I22T01")
        return if (falconFirst) listOf(FALCON, GPIOCTL) else listOf(GPIOCTL, FALCON)
    }

    private fun writeFile(path: String): Boolean {
        val file = File(path)
        if (!file.exists()) return false
        return try {
            FileOutputStream(file).use { out ->
                out.write('1'.code)
                out.write('\n'.code)
                out.flush()
            }
            true
        } catch (e: Exception) {
            Log.w(TAG, "write $path: ${e.message}")
            false
        }
    }

    private fun writeViaSh(path: String): Boolean {
        if (!File(path).exists()) return false
        return try {
            val proc = Runtime.getRuntime().exec("sh")
            proc.outputStream.use { out ->
                out.write("echo 1 > $path\n".toByteArray())
                out.flush()
            }
            proc.waitFor()
            proc.exitValue() == 0
        } catch (e: Exception) {
            Log.w(TAG, "sh $path: ${e.message}")
            false
        }
    }
}
