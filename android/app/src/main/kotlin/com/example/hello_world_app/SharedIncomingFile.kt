package com.example.hello_world_app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.util.Log
import java.io.File
import java.io.FileOutputStream

/**
 * Copia el archivo de Compartir / Abrir a cache.
 * En Android 10+ la ruta de Descargas no es legible (scoped storage);
 * IMPRIMIRSUNAT hace lo mismo: openInputStream → archivo propio.
 */
object SharedIncomingFile {
    private const val TAG = "SharedIncoming"
    private const val DIR = "shared_incoming"

    fun copyFromIntent(activity: Activity): String? {
        val intent = activity.intent ?: return null
        if (!intent.getStringExtra(MainActivity.EXTRA_SYSTEM_PRINT_PATH).isNullOrEmpty()) {
            return null
        }
        val uri = uriFrom(intent) ?: return null
        return copyUri(activity, uri)
    }

    private fun uriFrom(intent: Intent): Uri? {
        val stream = streamUri(intent)
        return when (intent.action) {
            Intent.ACTION_SEND -> stream ?: clipUri(intent)
            Intent.ACTION_SEND_MULTIPLE -> firstMultiple(intent) ?: clipUri(intent)
            Intent.ACTION_VIEW -> intent.data ?: stream
            else -> intent.data ?: stream ?: clipUri(intent)
        }
    }

    private fun streamUri(intent: Intent): Uri? {
        return if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }
    }

    private fun firstMultiple(intent: Intent): Uri? {
        val list = if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
        }
        return list?.firstOrNull()
    }

    private fun clipUri(intent: Intent): Uri? {
        val clip = intent.clipData ?: return null
        if (clip.itemCount < 1) return null
        return clip.getItemAt(0)?.uri
    }

    private fun copyUri(activity: Activity, uri: Uri): String? {
        val dir = File(activity.cacheDir, DIR).apply { mkdirs() }
        val name = displayName(activity, uri) ?: "sunat_${System.currentTimeMillis()}.xml"
        val target = uniqueFile(dir, name)
        return try {
            activity.contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(target).use { output -> input.copyTo(output) }
            } ?: return null
            if (target.length() <= 0L) {
                target.delete()
                return null
            }
            Log.i(TAG, "Copied share to ${target.path} (${target.length()} bytes)")
            target.path
        } catch (e: Exception) {
            Log.w(TAG, "copyUri failed: ${e.message}")
            target.delete()
            null
        }
    }

    private fun displayName(activity: Activity, uri: Uri): String? {
        val fromPath = uri.lastPathSegment
            ?.substringAfterLast('/')
            ?.substringAfterLast(':')
        if (!fromPath.isNullOrBlank() && fromPath.contains('.')) {
            return sanitizeName(fromPath)
        }
        val cursor = try {
            activity.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
        } catch (_: Exception) {
            null
        }
        cursor?.use {
            if (it.moveToFirst()) {
                val idx = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (idx >= 0) {
                    val name = it.getString(idx)
                    if (!name.isNullOrBlank()) return sanitizeName(name)
                }
            }
        }
        return if (fromPath.isNullOrBlank()) null else sanitizeName(fromPath)
    }

    private fun sanitizeName(raw: String): String {
        val base = raw.substringAfterLast('/').ifBlank { "sunat.bin" }
        return base.replace(Regex("[^A-Za-z0-9._-]"), "_")
    }

    private fun uniqueFile(dir: File, name: String): File {
        val dest = File(dir, name)
        if (!dest.exists()) return dest
        val dot = name.lastIndexOf('.')
        val stem = if (dot > 0) name.substring(0, dot) else name
        val ext = if (dot > 0) name.substring(dot) else ""
        var i = 1
        while (true) {
            val candidate = File(dir, "${stem}_$i$ext")
            if (!candidate.exists()) return candidate
            i++
        }
    }
}
