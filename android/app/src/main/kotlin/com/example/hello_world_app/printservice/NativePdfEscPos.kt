package com.example.hello_world_app.printservice

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Rect
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import java.io.ByteArrayOutputStream
import java.io.File
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Raster térmico al mismo flujo que las apps ESC/POS de referencia:
 * 1) PdfRenderer a tamaño nativo, fondo blanco
 * 2) Recorte del marco de tinta (ignora gris casi blanco)
 * 3) Segunda pasada: escala al ancho del rollo (203/300 dpi)
 * 4) x2/x3: render extra y bilinear al rollo (sin agrandar el ticket)
 * 5) Umbral = promedio del gris (tope 254), sin dither
 * 6) GS v 0 en franjas de 48
 */
object NativePdfEscPos {

    private const val MAX_PAGES = 8
    private const val BAND_HEIGHT = 48
    private const val MAX_HEIGHT = 16000
    private const val NEAR_WHITE_SUM = 720

    fun build(
        pdf: File,
        mediaSizeId: String?,
        mediaWidthMils: Int?,
        savedPaper: String,
        bottomMm: Double,
        cut: String,
        dpi: Int = 203,
        rasterScale: Int = 1,
    ): ByteArray {
        val width = dotsWidth(mediaSizeId, mediaWidthMils, savedPaper, dpi)
        val hi = rasterScale.coerceIn(1, 3)
        val out = ByteArrayOutputStream()
        out.write(byteArrayOf(0x1b, 0x40))

        ParcelFileDescriptor.open(pdf, ParcelFileDescriptor.MODE_READ_ONLY).use { pfd ->
            PdfRenderer(pfd).use { renderer ->
                val pages = min(renderer.pageCount, MAX_PAGES)
                if (pages < 1) throw IllegalStateException("PDF sin paginas")
                for (i in 0 until pages) {
                    renderer.openPage(i).use { page ->
                        val bmp = renderPage(page, width, hi)
                        try {
                            encodeGsV0(bmp, out, width)
                        } finally {
                            bmp.recycle()
                        }
                    }
                    if (i < pages - 1) {
                        out.write(byteArrayOf(0x1b, 0x64, 0x01))
                    }
                }
            }
        }

        appendFeed(out, width, bottomMm, dpi)
        out.write(cutBytes(cut))
        val data = out.toByteArray()
        if (data.size < 16) throw IllegalStateException("Ticket vacio")
        return data
    }

    private fun dotsWidth(
        mediaSizeId: String?,
        mediaWidthMils: Int?,
        savedPaper: String,
        dpi: Int,
    ): Int {
        val id = mediaSizeId?.uppercase().orEmpty()
        val is80 = when {
            id.contains("80") -> true
            id.contains("58") -> false
            mediaWidthMils != null && mediaWidthMils >= 2700 -> true
            mediaWidthMils != null && mediaWidthMils >= 1800 -> false
            else -> savedPaper == "mm80"
        }
        val raw = if (dpi >= 280) {
            if (is80) 832 else 576
        } else {
            if (is80) 576 else 384
        }
        return raw - (raw % 8)
    }

    private fun renderPage(
        page: PdfRenderer.Page,
        targetWidth: Int,
        hi: Int,
    ): Bitmap {
        val pw = page.width.coerceAtLeast(1)
        val ph = page.height.coerceAtLeast(1)
        val aligned = targetWidth - (targetWidth % 8)

        val preview = Bitmap.createBitmap(pw, ph, Bitmap.Config.ARGB_8888)
        preview.setHasAlpha(false)
        preview.eraseColor(Color.WHITE)
        page.render(preview, null, null, PdfRenderer.Page.RENDER_MODE_FOR_PRINT)
        val frame = findInkFrame(preview) ?: Rect(0, 0, pw, ph)
        preview.recycle()

        val contentW = frame.width().coerceAtLeast(1)
        val scale = aligned.toDouble() * hi / contentW.toDouble()
        val fullW = max(8, (pw * scale).roundToInt().coerceAtMost(8192))
        val fullH = max(8, (ph * scale).roundToInt().coerceAtMost(MAX_HEIGHT))
        val full = Bitmap.createBitmap(fullW, fullH, Bitmap.Config.ARGB_8888)
        full.setHasAlpha(false)
        full.eraseColor(Color.WHITE)
        page.render(full, null, null, PdfRenderer.Page.RENDER_MODE_FOR_PRINT)

        val left = (frame.left * scale).roundToInt().coerceIn(0, fullW - 1)
        val top = (frame.top * scale).roundToInt().coerceIn(0, fullH - 1)
        val cropW = (frame.width() * scale).roundToInt().coerceIn(8, fullW - left)
        val cropH = (frame.height() * scale).roundToInt().coerceIn(8, fullH - top)
        val cropped = Bitmap.createBitmap(full, left, top, cropW, cropH)
        if (cropped !== full) full.recycle()

        thresholdToBw(cropped)
        return if (hi <= 1) {
            padToRoll(fitToRoll(cropped, aligned), aligned)
        } else {
            downsampleBwToRoll(cropped, aligned, hi)
        }
    }

    private fun fitToRoll(src: Bitmap, aligned: Int): Bitmap {
        if (src.width == aligned) return src
        val h = max(8, (src.height.toLong() * aligned / src.width).toInt())
        val scaled = Bitmap.createScaledBitmap(src, aligned, h, true)
        if (scaled !== src) src.recycle()
        return scaled
    }

    /** x2/x3: ya está en B/N a alta res; mayoría al ancho real del rollo. */
    private fun downsampleBwToRoll(src: Bitmap, aligned: Int, hi: Int): Bitmap {
        val step = hi.coerceIn(2, 3)
        val outH = max(8, src.height / step)
        val usable = min(src.width / step, aligned)
        val sheet = Bitmap.createBitmap(aligned, outH, Bitmap.Config.ARGB_8888)
        sheet.eraseColor(Color.WHITE)
        val srcPx = IntArray(src.width * src.height)
        src.getPixels(srcPx, 0, src.width, 0, 0, src.width, src.height)
        val dst = IntArray(aligned * outH) { Color.WHITE }
        val need = (step * step + 1) / 2
        for (y in 0 until outH) {
            for (x in 0 until usable) {
                var dark = 0
                for (dy in 0 until step) {
                    val yy = min(y * step + dy, src.height - 1)
                    val row = yy * src.width
                    for (dx in 0 until step) {
                        val xx = min(x * step + dx, src.width - 1)
                        if ((srcPx[row + xx] and 0xff) <= 127) dark++
                    }
                }
                if (dark >= need) {
                    dst[y * aligned + x] = Color.BLACK
                }
            }
        }
        sheet.setPixels(dst, 0, aligned, 0, 0, aligned, outH)
        src.recycle()
        return sheet
    }

    private fun padToRoll(src: Bitmap, aligned: Int): Bitmap {
        if (src.width == aligned) return src
        val sheet = Bitmap.createBitmap(aligned, src.height, Bitmap.Config.ARGB_8888)
        sheet.eraseColor(Color.WHITE)
        val copyW = min(src.width, aligned)
        val pixels = IntArray(copyW * src.height)
        src.getPixels(pixels, 0, copyW, 0, 0, copyW, src.height)
        sheet.setPixels(pixels, 0, copyW, 0, 0, copyW, src.height)
        src.recycle()
        return sheet
    }

    /**
     * Primer/último renglón y columna que no son blanco puro,
     * después de tratar R+G+B > 720 como blanco (ruido de PDF).
     */
    private fun findInkFrame(bmp: Bitmap): Rect? {
        val w = bmp.width
        val h = bmp.height
        val pixels = IntArray(w * h)
        bmp.getPixels(pixels, 0, w, 0, 0, w, h)
        for (i in pixels.indices) {
            val c = pixels[i]
            val r = (c shr 16) and 0xff
            val g = (c shr 8) and 0xff
            val b = c and 0xff
            if (r + g + b > NEAR_WHITE_SUM) {
                pixels[i] = Color.WHITE
            }
        }

        var top = -1
        var bottom = -1
        for (y in 0 until h) {
            val row = y * w
            var ink = false
            for (x in 0 until w) {
                if (pixels[row + x] != Color.WHITE) {
                    ink = true
                    break
                }
            }
            if (ink) {
                if (top < 0) top = y
                bottom = y
            }
        }
        if (top < 0) return null

        var left = -1
        var right = -1
        for (x in 0 until w) {
            var ink = false
            for (y in top..bottom) {
                if (pixels[y * w + x] != Color.WHITE) {
                    ink = true
                    break
                }
            }
            if (ink) {
                if (left < 0) left = x
                right = x
            }
        }
        if (left < 0) return null
        return Rect(left, top, right + 1, bottom + 1)
    }

    /** Gris 0.25R+0.5G+0.25B; tinta si gris ≤ promedio (máx. 254). */
    private fun thresholdToBw(bmp: Bitmap) {
        val w = bmp.width
        val h = bmp.height
        val n = w * h
        if (n < 1) return
        val pixels = IntArray(n)
        bmp.getPixels(pixels, 0, w, 0, 0, w, h)
        val gray = IntArray(n)
        var sum = 0L
        for (i in 0 until n) {
            val c = pixels[i]
            val r = (c shr 16) and 0xff
            val g = (c shr 8) and 0xff
            val b = c and 0xff
            var v = (r shr 2) + (g shr 1) + (b shr 2)
            if (v > 249) v = 255
            gray[i] = v
            sum += v
        }
        var mean = (sum / n).toInt()
        if (mean > 254) mean = 254
        for (i in 0 until n) {
            pixels[i] = if (gray[i] > mean) Color.WHITE else Color.BLACK
        }
        bmp.setPixels(pixels, 0, w, 0, 0, w, h)
    }

    private fun encodeGsV0(
        bmp: Bitmap,
        out: ByteArrayOutputStream,
        outputWidth: Int,
    ) {
        val width = outputWidth - (outputWidth % 8)
        if (width < 8 || bmp.height < 1) return
        val srcW = min(bmp.width, width)
        val pixels = IntArray(srcW * bmp.height)
        bmp.getPixels(pixels, 0, srcW, 0, 0, srcW, bmp.height)
        val bytesPerRow = width shr 3

        var y = 0
        while (y < bmp.height) {
            val rows = min(BAND_HEIGHT, bmp.height - y)
            val payload = ByteArray(rows * bytesPerRow)
            for (row in 0 until rows) {
                val srcY = y + row
                val rowOff = row * bytesPerRow
                val pixOff = srcY * srcW
                for (x in 0 until srcW) {
                    if ((pixels[pixOff + x] and 0xff) > 127) continue
                    payload[rowOff + (x shr 3)] =
                        (payload[rowOff + (x shr 3)].toInt() or (0x80 shr (x and 7))).toByte()
                }
            }
            out.write(
                byteArrayOf(
                    0x1d,
                    0x76,
                    0x30,
                    0x00,
                    (bytesPerRow and 0xff).toByte(),
                    ((bytesPerRow shr 8) and 0xff).toByte(),
                    (rows and 0xff).toByte(),
                    ((rows shr 8) and 0xff).toByte(),
                ),
            )
            out.write(payload)
            y += rows
        }
    }

    private fun appendFeed(
        out: ByteArrayOutputStream,
        width: Int,
        bottomMm: Double,
        dpi: Int,
    ) {
        if (bottomMm <= 0) return
        val aligned = width - (width % 8)
        if (aligned < 8) return
        val dotsPerMm = dpi.coerceAtLeast(180) / 25.4
        var remaining = (bottomMm * dotsPerMm).roundToInt().coerceIn(1, 1200)
        val bytesPerRow = aligned shr 3
        while (remaining > 0) {
            val h = min(96, remaining)
            remaining -= h
            out.write(
                byteArrayOf(
                    0x1d,
                    0x76,
                    0x30,
                    0x00,
                    (bytesPerRow and 0xff).toByte(),
                    ((bytesPerRow shr 8) and 0xff).toByte(),
                    (h and 0xff).toByte(),
                    ((h shr 8) and 0xff).toByte(),
                ),
            )
            out.write(ByteArray(h * bytesPerRow))
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
