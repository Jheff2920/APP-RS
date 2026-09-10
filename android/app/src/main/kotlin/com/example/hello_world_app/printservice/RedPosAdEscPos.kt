package com.example.hello_world_app.printservice

/**
 * Pie de publicidad ESC/POS (rama de prueba RedPOS).
 * Pegado al ticket/QR; el margen inferior y el corte van después.
 */
object RedPosAdEscPos {

    private val lines = arrayOf(
        "App de uso gratuito.",
        "Sin publicidad: equipo RedPOS",
        "o suscripcion.",
    )

    fun appendBeforeCut(
        ticket: ByteArray,
        paper: String,
        cut: String,
        siteUrl: String = "www.redpos.com",
    ): ByteArray {
        val footer = footerBytes(paper, siteUrl)
        val cutBytes = cutBytes(cut)
        var end = ticket.size
        if (cutBytes.isNotEmpty() && endsWith(ticket, cutBytes)) {
            end -= cutBytes.size
        }
        val insertAt = trailingBlankRasterStart(ticket, end)
        val ad = if (insertAt >= end) {
            footer + byteArrayOf(0x1b, 0x64, 0x05)
        } else {
            footer
        }
        return ticket.copyOfRange(0, insertAt) + ad + ticket.copyOfRange(insertAt, ticket.size)
    }

    fun footerBytes(paper: String, siteUrl: String): ByteArray {
        val width = if (paper == "mm80") 48 else 32
        val stars = "*".repeat(width)
        val out = ArrayList<Byte>(160)
        fun add(vararg b: Int) {
            for (v in b) out.add(v.toByte())
        }
        fun line(text: String) {
            val fit = if (text.length <= width) text else text.substring(0, width)
            for (ch in fit) out.add(ch.code.toByte())
            out.add(0x0a)
        }
        add(0x0a, 0x1b, 0x61, 0x01, 0x1b, 0x21, 0x00)
        line(stars)
        for (row in lines) line(row)
        if (siteUrl.isNotBlank()) line(siteUrl.trim())
        line(stars)
        out.add(0x0a)
        add(0x1b, 0x61, 0x00)
        return out.toByteArray()
    }

    private fun endsWith(hay: ByteArray, needle: ByteArray): Boolean {
        if (needle.isEmpty() || hay.size < needle.size) return false
        val off = hay.size - needle.size
        for (i in needle.indices) {
            if (hay[off + i] != needle[i]) return false
        }
        return true
    }

    private fun trailingBlankRasterStart(ticket: ByteArray, end: Int): Int {
        var i = end
        while (true) {
            if (i < 8) return i
            var skipped = false
            val minHeader = (i - 8 - 96 * 80).coerceAtLeast(0)
            for (headerAt in i - 8 downTo minHeader) {
                if (ticket[headerAt] != 0x1d.toByte() ||
                    ticket[headerAt + 1] != 0x76.toByte() ||
                    ticket[headerAt + 2] != 0x30.toByte()
                ) {
                    continue
                }
                val x = (ticket[headerAt + 4].toInt() and 0xff) or
                    ((ticket[headerAt + 5].toInt() and 0xff) shl 8)
                val y = (ticket[headerAt + 6].toInt() and 0xff) or
                    ((ticket[headerAt + 7].toInt() and 0xff) shl 8)
                if (x < 1 || y < 1 || x > 96 || y > 512) continue
                if (headerAt + 8 + x * y != i) continue
                var blank = true
                var k = headerAt + 8
                while (k < i) {
                    if (ticket[k] != 0.toByte()) {
                        blank = false
                        break
                    }
                    k++
                }
                if (!blank) return i
                i = headerAt
                skipped = true
                break
            }
            if (!skipped) return i
        }
    }

    private fun cutBytes(cut: String): ByteArray {
        return when (cut) {
            "fullGsV0" -> byteArrayOf(0x1d, 0x56, 0x30)
            "fullGsVA" -> byteArrayOf(0x1d, 0x56, 0x41, 0x00)
            "fullEscI" -> byteArrayOf(0x1b, 0x69)
            "fullEscD0" -> byteArrayOf(0x1b, 0x64, 0x00)
            "partialGsV1" -> byteArrayOf(0x1d, 0x56, 0x31)
            "partialGsVB" -> byteArrayOf(0x1d, 0x56, 0x42, 0x00)
            "partialEscM" -> byteArrayOf(0x1b, 0x6d)
            "partialEscD1" -> byteArrayOf(0x1b, 0x64, 0x01)
            else -> byteArrayOf()
        }
    }
}
