package com.example.hello_world_app.printservice

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.ByteArrayOutputStream

class EscPosChunkerTest {
    @Test
    fun smallJobUsesSingleWrite() {
        val data = ByteArray(128) { it.toByte() }

        val ranges = EscPosChunker.ranges(data)

        assertEquals(listOf(EscPosChunker.Range(0, data.size)), ranges)
    }

    @Test
    fun largeRasterJobNeverSplitsInsideGsV0Band() {
        val reset = byteArrayOf(0x1b, 0x40)
        val first = gsV0(widthBytes = 72, height = 512, fill = 0x55)
        val second = gsV0(widthBytes = 72, height = 512, fill = 0x33)
        val cut = byteArrayOf(0x1d, 0x56, 0x00)
        val data = reset + first + second + cut

        val ranges = EscPosChunker.ranges(data)

        assertArrayEquals(data, reconstruct(data, ranges))
        val boundaries = ranges.runningFold(0) { offset, range ->
            offset + range.length
        }.drop(1).dropLast(1)
        for (boundary in boundaries) {
            assertTrue(
                "Boundary $boundary must be a GS v 0 header or command tail",
                isGsV0At(data, boundary) || boundary >= reset.size + first.size + second.size,
            )
        }
        assertTrue(ranges.any { it.length > EscPosChunker.PREFERRED_CHUNK_SIZE })
    }

    @Test
    fun malformedRasterHeaderFallsBackWithoutStalling() {
        val data = ByteArray(60_000) { 0x7f }
        data[0] = 0x1d
        data[1] = 0x76
        data[2] = 0x30
        // width/height quedan inválidos en cero.

        val ranges = EscPosChunker.ranges(data)

        assertArrayEquals(data, reconstruct(data, ranges))
        assertTrue(ranges.all { it.length > 0 })
    }

    @Test
    fun plainLargePayloadUsesPreferredSize() {
        val data = ByteArray(70_000) { (it and 0xff).toByte() }

        val ranges = EscPosChunker.ranges(data)

        assertArrayEquals(data, reconstruct(data, ranges))
        assertTrue(ranges.dropLast(1).all {
            it.length <= EscPosChunker.PREFERRED_CHUNK_SIZE
        })
    }

    private fun gsV0(widthBytes: Int, height: Int, fill: Int): ByteArray {
        val header = byteArrayOf(
            0x1d,
            0x76,
            0x30,
            0x00,
            (widthBytes and 0xff).toByte(),
            ((widthBytes shr 8) and 0xff).toByte(),
            (height and 0xff).toByte(),
            ((height shr 8) and 0xff).toByte(),
        )
        return header + ByteArray(widthBytes * height) { fill.toByte() }
    }

    private fun reconstruct(
        data: ByteArray,
        ranges: List<EscPosChunker.Range>,
    ): ByteArray {
        val output = ByteArrayOutputStream()
        for (range in ranges) {
            output.write(data, range.offset, range.length)
        }
        return output.toByteArray()
    }

    private fun isGsV0At(data: ByteArray, offset: Int): Boolean {
        return offset + 2 < data.size &&
            (data[offset].toInt() and 0xff) == 0x1d &&
            (data[offset + 1].toInt() and 0xff) == 0x76 &&
            (data[offset + 2].toInt() and 0xff) == 0x30
    }
}
