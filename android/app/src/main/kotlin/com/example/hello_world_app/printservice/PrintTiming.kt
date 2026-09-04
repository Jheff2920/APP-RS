package com.example.hello_world_app.printservice

import android.os.SystemClock
import android.util.Log

/**
 * Formato estable para comparar fases con:
 * adb logcat -s BoletaPrintTiming
 */
object PrintTiming {
    private const val TAG = "BoletaPrintTiming"

    fun now(): Long = SystemClock.elapsedRealtime()

    fun phase(
        jobId: String,
        phase: String,
        startedAt: Long,
        fields: Map<String, Any?> = emptyMap(),
    ) {
        val extras = fields.entries.joinToString(separator = " ") { (key, value) ->
            "$key=$value"
        }
        val suffix = if (extras.isEmpty()) "" else " $extras"
        Log.i(
            TAG,
            "job=$jobId phase=$phase duration_ms=${now() - startedAt}$suffix",
        )
    }

    fun event(
        jobId: String,
        phase: String,
        fields: Map<String, Any?> = emptyMap(),
    ) {
        val extras = fields.entries.joinToString(separator = " ") { (key, value) ->
            "$key=$value"
        }
        val suffix = if (extras.isEmpty()) "" else " $extras"
        Log.i(TAG, "job=$jobId phase=$phase$suffix")
    }
}
