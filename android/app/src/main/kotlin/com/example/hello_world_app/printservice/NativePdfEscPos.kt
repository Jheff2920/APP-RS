package com.example.hello_world_app.printservice

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import java.io.ByteArrayOutputStream
import java.io.File
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Raster térmico al estilo de las apps ESC/POS de referencia:
 * 1) Preview 1:1 y recorte del ticket
 * 2) Geometría fija: 384/576 × alto proporcional (igual en x1/x2/x3)
 * 3) Nitidez: raster del recorte a hi× con Matrix (no escalar la página alta)
 * 4) Umbral promedio → GS v 0 en franjas altas (carga y luego imprime)
 */
object NativePdfEscPos {

    private const val MAX_PAGES = 8
    private const val BAND_HEIGHT = 2048
    private const val NEAR_WHITE_SUM = 720
    /** Aire superior ~4 mm a 203 dpi. */
    private const val TOP_AIR_DOTS = 32
    /** Tope ~1 m a 203 dpi: Google/ancho de Chrome no dispara un bitmap gigante. */
    private const val MAX_TICKET_DOTS = 8000

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
        val tallChrome = true
        val out = ByteArrayOutputStream()
        out.write(byteArrayOf(0x1b, 0x40))
        // Retroceso ~4 mm (ESC j). No usar 0x40: si se pierde ESC, imprime "@".
        out.write(byteArrayOf(0x1b, 0x6a, 0x20))

        ParcelFileDescriptor.open(pdf, ParcelFileDescriptor.MODE_READ_ONLY).use { pfd ->
            PdfRenderer(pfd).use { renderer ->
                val pages = min(renderer.pageCount, MAX_PAGES)
                if (pages < 1) throw IllegalStateException("PDF sin paginas")
                for (i in 0 until pages) {
                    renderer.openPage(i).use { page ->
                        val bmp = renderPage(page, width, hi, tallChrome)
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
            mediaWidthMils != null && mediaWidthMils >= 3100 -> true
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
        tallChrome: Boolean,
    ): Bitmap {
        val pw = page.width.coerceAtLeast(1)
        val ph = page.height.coerceAtLeast(1)
        val outW = targetWidth - (targetWidth % 8)

        val preview = Bitmap.createBitmap(pw, ph, Bitmap.Config.ARGB_8888)
        preview.setHasAlpha(false)
        preview.eraseColor(Color.WHITE)
        page.render(preview, null, null, PdfRenderer.Page.RENDER_MODE_FOR_PRINT)
        val frame = if (tallChrome) {
            findChromeTicketFrame(preview) ?: findInkFrame(preview)
        } else {
            findInkFrame(preview)
        } ?: Rect(0, 0, pw, ph)
        preview.recycle()

        val contentW = frame.width().coerceAtLeast(1)
        val contentH = frame.height().coerceAtLeast(1)
        val outH = max(
            8,
            min(MAX_TICKET_DOTS, (contentH.toLong() * outW / contentW).toInt()),
        )
        val step = hi.coerceIn(1, 3)
        val hiW = outW * step
        val hiH = outH * step

        val dest = Bitmap.createBitmap(hiW, hiH, Bitmap.Config.ARGB_8888)
        dest.setHasAlpha(false)
        dest.eraseColor(Color.WHITE)
        val matrix = Matrix()
        matrix.setRectToRect(
            RectF(
                frame.left.toFloat(),
                frame.top.toFloat(),
                frame.right.toFloat(),
                frame.bottom.toFloat(),
            ),
            RectF(0f, 0f, hiW.toFloat(), hiH.toFloat()),
            Matrix.ScaleToFit.FILL,
        )
        page.render(dest, null, matrix, PdfRenderer.Page.RENDER_MODE_FOR_PRINT)
        thresholdToBw(dest)
        val sheet = if (step <= 1) {
            padToRoll(dest, outW)
        } else {
            downsampleExact(dest, outW, step)
        }
        return trimLeadingWhite(sheet, TOP_AIR_DOTS)
    }

    /** x2/x3: bitmap exactamente aligned*hi; mayoría → ancho del rollo. */
    private fun downsampleExact(src: Bitmap, aligned: Int, step: Int): Bitmap {
        val outH = max(8, src.height / step)
        val sheet = Bitmap.createBitmap(aligned, outH, Bitmap.Config.ARGB_8888)
        sheet.eraseColor(Color.WHITE)
        val srcPx = IntArray(src.width * src.height)
        src.getPixels(srcPx, 0, src.width, 0, 0, src.width, src.height)
        val dst = IntArray(aligned * outH) { Color.WHITE }
        val need = (step * step + 1) / 2
        val srcW = src.width
        val srcH = src.height
        for (y in 0 until outH) {
            for (x in 0 until aligned) {
                var dark = 0
                for (dy in 0 until step) {
                    val yy = min(y * step + dy, srcH - 1)
                    val row = yy * srcW
                    for (dx in 0 until step) {
                        val xx = min(x * step + dx, srcW - 1)
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

    /** Quita blanco de arriba y deja [keepDots] de aire (~4 mm). */
    private fun trimLeadingWhite(src: Bitmap, keepDots: Int): Bitmap {
        val w = src.width
        val h = src.height
        if (h <= keepDots) return src
        val pixels = IntArray(w * h)
        src.getPixels(pixels, 0, w, 0, 0, w, h)
        var firstInk = -1
        for (y in 0 until h) {
            val row = y * w
            var ink = false
            for (x in 0 until w) {
                if ((pixels[row + x] and 0xff) <= 127) {
                    ink = true
                    break
                }
            }
            if (ink) {
                firstInk = y
                break
            }
        }
        if (firstInk < 0) return src
        val start = max(0, firstInk - keepDots)
        if (start == 0) return src
        val outH = h - start
        val sheet = Bitmap.createBitmap(w, outH, Bitmap.Config.ARGB_8888)
        sheet.setPixels(pixels, start * w, w, 0, 0, w, outH)
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

    /**
     * Google/Max (58 y 80): página altísima de Chrome. El ticket queda arriba
     * y el encabezado/pie del navegador ensanchan el marco. Se toma el bloque
     * de tinta más denso (el ticket), se deja ~4 mm de aire arriba para no
     * cortar el logo y se escala al rollo.
     */
    private fun findChromeTicketFrame(bmp: Bitmap): Rect? {
        val w = bmp.width
        val h = bmp.height
        val pixels = IntArray(w * h)
        bmp.getPixels(pixels, 0, w, 0, 0, w, h)
        for (i in pixels.indices) {
            val c = pixels[i]
            val r = (c shr 16) and 0xff
            val g = (c shr 8) and 0xff
            val b = c and 0xff
            // Más sensible que 720: el logo LIMAFAC en páginas altas sale pálido.
            if (r + g + b > 780) {
                pixels[i] = Color.WHITE
            }
        }

        val minInk = max(4, w / 36)
        val inkRow = IntArray(h)
        for (y in 0 until h) {
            val row = y * w
            var n = 0
            for (x in 0 until w) {
                if (pixels[row + x] != Color.WHITE) n++
            }
            inkRow[y] = n
        }

        val maxGap = min(64, max(20, h / 100))
        var bestTop = -1
        var bestBottom = -1
        var bestLen = -1
        var runTop = -1
        var gap = 0
        for (y in 0 until h) {
            if (inkRow[y] >= minInk) {
                if (runTop < 0) runTop = y
                gap = 0
            } else if (runTop >= 0) {
                gap++
                if (gap > maxGap) {
                    val bottom = y - gap - 1
                    val len = bottom - runTop
                    if (len > bestLen) {
                        bestLen = len
                        bestTop = runTop
                        bestBottom = bottom
                    }
                    runTop = -1
                    gap = 0
                }
            }
        }
        if (runTop >= 0) {
            val bottom = h - 1
            val len = bottom - runTop
            if (len > bestLen) {
                bestTop = runTop
                bestBottom = bottom
            }
        }
        if (bestTop < 0 || bestBottom < bestTop) return null

        val blockH = bestBottom - bestTop + 1
        val colInk = IntArray(w)
        val fullBleed = w * 82 / 100
        var usedRows = 0
        for (y in bestTop..bestBottom) {
            if (inkRow[y] > fullBleed) continue
            usedRows++
            val row = y * w
            for (x in 0 until w) {
                if (pixels[row + x] != Color.WHITE) colInk[x]++
            }
        }
        if (usedRows < 4) {
            colInk.fill(0)
            for (y in bestTop..bestBottom) {
                val row = y * w
                for (x in 0 until w) {
                    if (pixels[row + x] != Color.WHITE) colInk[x]++
                }
            }
        }

        var peak = 1
        for (c in colInk) if (c > peak) peak = c
        val colThresh = max(2, peak / 10)
        var left = -1
        var right = -1
        for (x in 0 until w) {
            if (colInk[x] < colThresh) continue
            if (left < 0) left = x
            right = x
        }
        if (left < 0 || right <= left) return null

        val padX = max(4, (right - left + 1) / 40)
        // ~4 mm si el preview está en puntos PDF (no crece con páginas altas).
        val padTop = 10
        val padBottom = max(4, blockH / 36)
        return Rect(
            max(0, left - padX),
            max(0, bestTop - padTop),
            min(w, right + 1 + padX),
            min(h, bestBottom + 1 + padBottom),
        )
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
