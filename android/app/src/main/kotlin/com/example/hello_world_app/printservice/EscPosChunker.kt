package com.example.hello_world_app.printservice

/**
 * Divide trabajos grandes sin cortar el payload de un comando raster GS v 0.
 *
 * preferredChunkSize es un objetivo blando: una sola banda de 512 filas en
 * 58/80 mm puede ser ligeramente mayor y debe enviarse completa.
 */
object EscPosChunker {
    const val SINGLE_WRITE_LIMIT = 49_152
    const val PREFERRED_CHUNK_SIZE = 24_576

    data class Range(val offset: Int, val length: Int)

    fun ranges(
        data: ByteArray,
        singleWriteLimit: Int = SINGLE_WRITE_LIMIT,
        preferredChunkSize: Int = PREFERRED_CHUNK_SIZE,
    ): List<Range> {
        if (data.isEmpty()) return emptyList()
        require(singleWriteLimit > 0)
        require(preferredChunkSize > 0)
        if (data.size <= singleWriteLimit) return listOf(Range(0, data.size))

        val result = mutableListOf<Range>()
        var start = 0
        while (start < data.size) {
            val end = nextEnd(data, start, preferredChunkSize)
                .coerceIn(start + 1, data.size)
            result += Range(start, end - start)
            start = end
        }
        return result
    }

    private fun nextEnd(data: ByteArray, start: Int, preferredSize: Int): Int {
        if (isGsV0At(data, start)) {
            val firstEnd = rasterEnd(data, start) ?: run {
                return (start + preferredSize).coerceAtMost(data.size)
            }

            // Nunca partir una banda, aunque sea mayor que preferredSize.
            var end = firstEnd
            while (end < data.size && end - start < preferredSize && isGsV0At(data, end)) {
                val next = rasterEnd(data, end) ?: break
                if (next - start > preferredSize) break
                end = next
            }
            return end
        }

        val limit = (start + preferredSize).coerceAtMost(data.size)
        var cursor = start + 1
        while (cursor < limit) {
            if (isGsV0At(data, cursor)) return cursor
            cursor++
        }
        return limit
    }

    private fun isGsV0At(data: ByteArray, offset: Int): Boolean {
        return offset + 7 < data.size &&
            data[offset].unsigned() == 0x1d &&
            data[offset + 1].unsigned() == 0x76 &&
            data[offset + 2].unsigned() == 0x30
    }

    private fun rasterEnd(data: ByteArray, offset: Int): Int? {
        if (!isGsV0At(data, offset)) return null
        val widthBytes = data[offset + 4].unsigned() or
            (data[offset + 5].unsigned() shl 8)
        val height = data[offset + 6].unsigned() or
            (data[offset + 7].unsigned() shl 8)
        if (widthBytes <= 0 || height <= 0) return null
        val payload = widthBytes.toLong() * height.toLong()
        val end = offset.toLong() + 8L + payload
        if (end > data.size || end > Int.MAX_VALUE) return null
        return end.toInt()
    }

    private fun Byte.unsigned(): Int = toInt() and 0xff
}
